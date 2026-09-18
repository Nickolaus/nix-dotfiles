{ config, lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  # Single source of truth for SSH key material and its use.
  #
  # `identities` describe key material: one entry per real keypair, one sops
  # secret, one file on disk. `scopes` describe use: which identities answer
  # for which hosts. The split lets several scopes share one keypair today and
  # separate onto their own later without touching anything but this file.
  options.sshKeys = {
    identities = mkOption {
      description = "Key material, keyed by identity name.";
      default = { };
      type = types.attrsOf (types.submodule {
        options = {
          file = mkOption {
            type = types.str;
            description = ''
              Basename under ~/.ssh. Both the ssh_config path and the sops
              output path derive from it, so they cannot drift apart.
            '';
          };

          sopsKey = mkOption {
            type = types.str;
            description = "Top-level key in secrets.yaml holding the private half.";
          };
        };
      });
    };

    scopes = mkOption {
      description = "How identities are used, keyed by scope name.";
      default = { };
      type = types.attrsOf (types.submodule {
        options = {
          identities = mkOption {
            type = types.listOf types.str;
            description = ''
              Identities this scope offers, in the order ssh should try them.
              Listing more than one is how a key rotation stays reversible: the
              old and the new identity both answer until the remote side has
              moved over. Keep the lists short -- every offered key counts
              against the server's MaxAuthTries.
            '';
          };

          hosts = mkOption {
            type = types.attrsOf (types.attrsOf types.anything);
            default = { };
            description = ''
              ssh_config match blocks this scope answers for. Each value is
              merged over IdentityFile/IdentitiesOnly, so a block only spells
              out what differs.
            '';
          };
        };
      });
    };

    signing = {
      active = mkOption {
        type = types.str;
        description = ''
          Signing key used for new commits. Singular because git signs with
          exactly one identity; overlap during a rotation is expressed by
          leaving the retired key in `keys` with a validity window.
        '';
      };

      keys = mkOption {
        description = ''
          Signing keys, keyed by name. Every entry lands in allowed_signers;
          `validAfter`/`validBefore` bound a key to the window it was in use,
          which keeps commits signed by a retired key verifiable.
        '';
        default = { };
        type = types.attrsOf (types.submodule {
          options = {
            principal = mkOption {
              type = types.str;
              description = "Identity the signature is attributed to.";
            };

            publicKey = mkOption {
              type = types.str;
              description = "Public half, in authorized_keys format.";
            };

            validAfter = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Optional allowed_signers valid-after stamp (YYYYMMDD).";
            };

            validBefore = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Optional allowed_signers valid-before stamp (YYYYMMDD).";
            };
          };
        });
      };
    };

    gitIncludes = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = ''
        Map of git include name to scope name. Each entry renders
        `.config/git/<name>.inc` pinning that scope's identities, for the
        `includeIf` rules in the git module to point at.
      '';
    };

    defaultIdentity = mkOption {
      type = types.str;
      description = ''
        Identity offered by the catch-all `Host *` block, for hosts no scope
        claims. Named rather than inlined into `defaults` so a rename cannot
        leave the fallback pointing at an identity that no longer exists.
      '';
    };

    defaults = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "Settings for the catch-all `Host *` block.";
    };

    # Derived below so every consumer resolves paths the same way.
    identityPath = mkOption {
      type = types.functionTo types.str;
      internal = true;
      readOnly = true;
      description = "Identity name -> ssh_config path.";
    };

    scopePaths = mkOption {
      type = types.functionTo (types.listOf types.str);
      internal = true;
      readOnly = true;
      description = "Scope name -> ssh_config paths, in offer order.";
    };
  };

  # These invariants all fail silently otherwise: a duplicate sopsKey drops an
  # identity from sops, a duplicate file points two secrets at one path, and a
  # host claimed twice resolves by attribute order rather than intent.
  config.assertions =
    let
      cfg = config.sshKeys;
      identityNames = lib.attrNames cfg.identities;

      duplicates = field:
        let values = map (n: cfg.identities.${n}.${field}) identityNames;
        in lib.unique (lib.filter (v: lib.count (x: x == v) values > 1) values);

      hostOwners = lib.zipAttrs (lib.mapAttrsToList
        (scope: s: lib.mapAttrs (_h: _v: scope) s.hosts)
        cfg.scopes);
      contestedHosts = lib.filterAttrs (_h: owners: lib.length owners > 1) hostOwners;

      unknownIn = scope: lib.subtractLists identityNames cfg.scopes.${scope}.identities;
      scopesWithUnknown = lib.filter (s: unknownIn s != [ ]) (lib.attrNames cfg.scopes);
      emptyScopes = lib.filter (s: cfg.scopes.${s}.identities == [ ]) (lib.attrNames cfg.scopes);

      unknownIncludes = lib.filterAttrs
        (_n: scope: !(cfg.scopes ? ${scope}))
        cfg.gitIncludes;
    in
    [
      {
        assertion = duplicates "sopsKey" == [ ];
        message = "sshKeys.identities: sopsKey reused by more than one identity: "
          + lib.concatStringsSep ", " (duplicates "sopsKey");
      }
      {
        assertion = duplicates "file" == [ ];
        message = "sshKeys.identities: file reused by more than one identity, so two sops secrets would write the same path: "
          + lib.concatStringsSep ", " (duplicates "file");
      }
      {
        assertion = scopesWithUnknown == [ ];
        message = "sshKeys.scopes: unknown identity referenced by "
          + lib.concatStringsSep ", " (map
            (s: "${s} (${lib.concatStringsSep " " (unknownIn s)})")
            scopesWithUnknown);
      }
      {
        assertion = emptyScopes == [ ];
        message = "sshKeys.scopes: empty identities list, so these hosts would silently fall through to Host *: "
          + lib.concatStringsSep ", " emptyScopes;
      }
      {
        assertion = contestedHosts == { };
        message = "sshKeys.scopes: host claimed by more than one scope, resolved by attribute order rather than intent: "
          + lib.concatStringsSep ", " (lib.mapAttrsToList
            (h: owners: "${h} (${lib.concatStringsSep " " owners})")
            contestedHosts);
      }
      {
        assertion = cfg.identities ? ${cfg.defaultIdentity};
        message = "sshKeys.defaultIdentity refers to an undeclared identity, so Host * would point at a key that does not exist: ${cfg.defaultIdentity}";
      }
      {
        assertion = cfg.signing.keys ? ${cfg.signing.active};
        message = "sshKeys.signing.active refers to an undeclared signing key: ${cfg.signing.active}";
      }
      {
        assertion = unknownIncludes == { };
        message = "sshKeys.gitIncludes: unknown scope referenced by "
          + lib.concatStringsSep ", " (lib.attrNames unknownIncludes);
      }
    ];

  config.sshKeys = {
    # Falls back rather than throwing so an unknown name surfaces as the
    # assertion below instead of a bare "attribute missing" trace.
    identityPath = name:
      "~/.ssh/${(config.sshKeys.identities.${name} or { file = "undeclared-identity-${name}"; }).file}";

    scopePaths =
      scope: map config.sshKeys.identityPath config.sshKeys.scopes.${scope}.identities;

    defaultIdentity = "work";

    identities = {
      work = {
        file = "id_ed25519";
        sopsKey = "ssh_key";
      };

      personal = {
        file = "id_ed25519_personal";
        sopsKey = "ssh_key_personal";
      };
    };

    scopes = {
      work-forge = {
        identities = [ "work" ];
        hosts = {
          "github.com" = { HostName = "github.com"; User = "git"; };
          "gitlab.com" = { HostName = "gitlab.com"; User = "git"; };
        };
      };

      personal-forge = {
        identities = [ "personal" ];
        hosts = {
          "github.com-personal" = { HostName = "github.com"; User = "git"; };
          "gitlab.com-personal" = { HostName = "gitlab.com"; User = "git"; };
        };
      };
    };

    signing = {
      active = "work";
      keys.work = {
        principal = "c.hessel@shopware.com";
        publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHBw37pfQ1qRRONPampA3kv/2AhcmZxgzdMPcXuRI9Ue";
      };
    };

    gitIncludes = {
      work = "work-forge";
      personal = "personal-forge";
    };

    defaults = {
      SetEnv = { TERM = "xterm-256color"; };
      TCPKeepAlive = true;
      ServerAliveInterval = 60;
      ServerAliveCountMax = 1200;
      IdentitiesOnly = true;
      IdentityFile = config.sshKeys.identityPath config.sshKeys.defaultIdentity;
      AddKeysToAgent = "yes";
      ForwardAgent = false;
      Compression = true;
    };
  };
}
