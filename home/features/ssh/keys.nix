{ config, lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  # Single source of truth for SSH key material and its use.
  #
  # `identities` describe key material: one entry per real keypair, one sops
  # secret, one file on disk. Everything else references an identity by name
  # rather than repeating its path or public half, so a rotation touches this
  # file and the sops entry and nothing else:
  #
  #   scopes.<name>       which identities authenticate to which hosts
  #   signing.keys.<name> which identity signs commits, and for what window
  #   gitIncludes.<name>  which scope, signing key, and author email a repo
  #                       tree uses, via the includeIf rules in the git module
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

          publicKey = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = ''
              Public half, in authorized_keys format. Required only for an
              identity a signing key references; git needs the public half to
              name the signer and to build allowed_signers.
            '';
          };
        };
      });
    };

    scopes = mkOption {
      description = "How identities authenticate, keyed by scope name.";
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
          Signing key for repositories no `gitIncludes` entry covers. Singular
          because git signs with exactly one identity; overlap during a
          rotation is expressed by leaving the retired key in `keys` with a
          validity window.
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
            identity = mkOption {
              type = types.str;
              description = ''
                Identity holding this signing key. The public half is read from
                that identity rather than repeated here, so the two cannot
                disagree.
              '';
            };

            principal = mkOption {
              type = types.str;
              description = "Identity the signature is attributed to.";
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
      description = ''
        Per-tree git configuration, keyed by include name. Each entry renders
        `.config/git/<name>.inc` for the `includeIf` rules in the git module to
        point at.
      '';
      default = { };
      type = types.attrsOf (types.submodule {
        options = {
          scope = mkOption {
            type = types.str;
            description = "Scope whose identities this tree authenticates with.";
          };

          signingKey = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = ''
              Signing key for this tree. Null falls back to
              `sshKeys.signing.active`.
            '';
          };

          email = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = ''
              Author email for this tree. Null leaves the global git identity
              in place.
            '';
          };
        };
      });
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

    signingPublicKey = mkOption {
      type = types.functionTo types.str;
      internal = true;
      readOnly = true;
      description = "Signing key name -> public half of its identity.";
    };

    signingKeyPath = mkOption {
      type = types.functionTo types.str;
      internal = true;
      readOnly = true;
      description = ''
        Signing key name -> private key path. git signs through
        `ssh-keygen -Y sign`, which resolves a literal public key only via the
        agent; pointing at the path instead keeps signing working in a shell
        with no agent, and across reboots.
      '';
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

      signingNames = lib.attrNames cfg.signing.keys;
      signingUnknownIdentity =
        lib.filter (n: !(cfg.identities ? ${cfg.signing.keys.${n}.identity})) signingNames;
      signingWithoutPublicKey = lib.filter
        (n:
          let id = cfg.signing.keys.${n}.identity;
          in cfg.identities ? ${id} && cfg.identities.${id}.publicKey == null)
        signingNames;

      unknownIncludeScopes = lib.filterAttrs
        (_n: inc: !(cfg.scopes ? ${inc.scope}))
        cfg.gitIncludes;
      unknownIncludeSigning = lib.filterAttrs
        (_n: inc: inc.signingKey != null && !(cfg.signing.keys ? ${inc.signingKey}))
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
        assertion = signingUnknownIdentity == [ ];
        message = "sshKeys.signing.keys: unknown identity referenced by "
          + lib.concatStringsSep ", " signingUnknownIdentity;
      }
      {
        assertion = signingWithoutPublicKey == [ ];
        message = "sshKeys.signing.keys: identity has no publicKey, so git cannot name the signer: "
          + lib.concatStringsSep ", " signingWithoutPublicKey;
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
        assertion = unknownIncludeScopes == { };
        message = "sshKeys.gitIncludes: unknown scope referenced by "
          + lib.concatStringsSep ", " (lib.attrNames unknownIncludeScopes);
      }
      {
        assertion = unknownIncludeSigning == { };
        message = "sshKeys.gitIncludes: unknown signing key referenced by "
          + lib.concatStringsSep ", " (lib.attrNames unknownIncludeSigning);
      }
    ];

  config.sshKeys = {
    # Falls back rather than throwing so an unknown name surfaces as the
    # assertion above instead of a bare "attribute missing" trace.
    identityPath = name:
      "~/.ssh/${(config.sshKeys.identities.${name} or { file = "undeclared-identity-${name}"; }).file}";

    scopePaths =
      scope: map config.sshKeys.identityPath config.sshKeys.scopes.${scope}.identities;

    signingKeyPath = name:
      config.sshKeys.identityPath config.sshKeys.signing.keys.${name}.identity;

    signingPublicKey = name:
      let
        key = config.sshKeys.signing.keys.${name};
        identity = config.sshKeys.identities.${key.identity} or { publicKey = null; };
      in
      if identity.publicKey == null
      then "undeclared-public-key-${name}"
      else identity.publicKey;

    defaultIdentity = "work";

    identities = {
      # Retired 2026-09-21. Kept alongside the replacements until every remote
      # has moved over; dropped once nothing offers them any more.
      work-legacy = {
        file = "id_ed25519";
        sopsKey = "ssh_key";
        publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHBw37pfQ1qRRONPampA3kv/2AhcmZxgzdMPcXuRI9Ue";
      };

      personal-legacy = {
        file = "id_ed25519_personal";
        sopsKey = "ssh_key_personal";
      };

      work = {
        file = "id_work";
        sopsKey = "ssh_key_work";
      };

      personal = {
        file = "id_personal";
        sopsKey = "ssh_key_personal_new";
      };

      homelab = {
        file = "id_homelab";
        sopsKey = "ssh_key_homelab";
      };

      work-signing = {
        file = "id_work_signing";
        sopsKey = "ssh_key_work_signing";
        publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDYjW+MEJSTHyCPCxVA5RIXUNb9FWRwELuN7HbVDHo4G";
      };

      personal-signing = {
        file = "id_personal_signing";
        sopsKey = "ssh_key_personal_signing";
        publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKHP4qOtsiMOkcqLqKz1Y7n8J0qrzSdmqbLYCyR4Oc4F";
      };
    };

    scopes = {
      # New key first; the legacy key stays listed as a fallback until it is
      # withdrawn from every remote, then both it and its identity go.
      work = {
        identities = [ "work" "work-legacy" ];
        hosts = {
          "github.com" = { HostName = "github.com"; User = "git"; };
          "gitlab.com" = { HostName = "gitlab.com"; User = "git"; };
        };
      };

      personal = {
        identities = [ "personal" "personal-legacy" ];
        hosts = {
          "github.com-personal" = { HostName = "github.com"; User = "git"; };
          "gitlab.com-personal" = { HostName = "gitlab.com"; User = "git"; };
        };
      };
    };

    signing = {
      active = "work";

      keys = {
        # Retired 2026-09-21. The window keeps every commit it signed before
        # that date verifiable; dropping the entry would make the whole signed
        # history read as unverified.
        work-legacy = {
          identity = "work-legacy";
          principal = "c.hessel@shopware.com";
          validBefore = "20260921";
        };

        work = {
          identity = "work-signing";
          principal = "c.hessel@shopware.com";
          validAfter = "20260921";
        };

        personal = {
          identity = "personal-signing";
          principal = "nickolausone+github@posteo.de";
        };
      };
    };

    gitIncludes = {
      work.scope = "work";
      personal.scope = "personal";
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
