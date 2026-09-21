{ config, lib, pkgs, ... }:
let
  homeDir = config.home.homeDirectory;
  keys = config.sshKeys;

  # allowed_signers entry per signing key. The validity stamps scope a key to
  # the window it signed in, so a retired key still verifies its own commits;
  # git passes the commit's own timestamp as the verification time.
  #
  # allowed_signers(5) takes the options as one comma-separated field. Spacing
  # them apart makes ssh-keygen read the first option as the key type, and the
  # line then matches no principal at all.
  signerLine = name: key:
    let
      quoted = opt: value: "${opt}=\"${value}\"";
      options = [ (quoted "namespaces" "git") ]
        ++ lib.optional (key.validAfter != null) (quoted "valid-after" key.validAfter)
        ++ lib.optional (key.validBefore != null) (quoted "valid-before" key.validBefore);
    in
    "${key.principal} ${lib.concatStringsSep "," options} ${keys.signingPublicKey name}";

  # One -i per identity the scope offers, in the same order ssh_config lists
  # them, so a repo pinned to a scope follows that scope through a rotation.
  # A tree may also pin its own signing key and author email; both are optional
  # and fall through to the global git identity when unset.
  gitIncludes = lib.mapAttrs'
    (name: inc:
      let
        userLines =
          lib.optional (inc.email != null) "  email = ${inc.email}"
          ++ lib.optional (inc.signingKey != null)
            "  signingkey = ${keys.signingKeyPath inc.signingKey}";
      in
      lib.nameValuePair ".config/git/${name}.inc" {
        text = lib.concatStringsSep "\n" (
          [
            "[core]"
            "  sshCommand = ssh ${lib.concatMapStringsSep " " (path: "-i ${path}") (keys.scopePaths inc.scope)} -o IdentitiesOnly=yes"
          ]
          ++ lib.optionals (userLines != [ ]) ([ "" "[user]" ] ++ userLines)
        ) + "\n";
      })
    keys.gitIncludes;
in
{
  imports = [
    ./opencommit.nix
  ];

  home.packages = with pkgs; [
    delta
  ];

  programs.git = {
    enable = true;
    package = pkgs.git;
    lfs = {
      enable = true;
    };

    signing.key = keys.signingKeyPath keys.signing.active;
    signing.format = "ssh";
    signing.signByDefault = true;

    settings = {
      user = {
        name = "Christian Hessel";
        email = "c.hessel@shopware.com";
      };

      push = {
        autoSetupRemote = true;
        default = "simple";
      };

      init.defaultBranch = "main";
      pull.rebase = true;
      rebase.autoStash = true;
      fetch.prune = true;
      fetch.writeCommitGraph = true;
      feature.manyFiles = true;
      index.version = 4;
      core.fsmonitor = true;
      core.untrackedCache = true;
      init.templateDir = "~/.config/git/templates";

      # Without this git can sign but never verify: `git log --show-signature`
      # reports "No signature" on a perfectly good signature because it has no
      # principal list to check it against.
      gpg.ssh.allowedSignersFile = "${homeDir}/.ssh/allowed_signers";

      includeIf."gitdir:${homeDir}/Programming/work/".path = "~/.config/git/work.inc";
      includeIf."gitdir:${homeDir}/Programming/personal/".path = "~/.config/git/personal.inc";
      includeIf."gitdir:${homeDir}/.config/nix-dotfiles/".path = "~/.config/git/personal.inc";
    };
  };

  programs.lazygit = {
    enable = true;
    settings = {
      promptToReturnFromSubprocess = false;
      git = {
        overrideGpg = true;
        paging = {
          colorArg = "always";
          pager = "delta --dark --paging=never";
        };
      };
    };
  };

  home.file = gitIncludes // {
    ".ssh/allowed_signers".text =
      lib.concatStringsSep "\n" (lib.mapAttrsToList signerLine keys.signing.keys);

    ".config/git/templates/hooks/post-checkout" = {
      executable = true;
      text = ''
        #!/bin/sh
        # Bootstrap commit-graph on first checkout if not yet present
        if [ ! -f "$(git rev-parse --git-dir)/objects/info/commit-graph" ]; then
          git commit-graph write --reachable &
        fi
      '';
    };
  };

  home.activation.createProgrammingDirectories = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${pkgs.coreutils}/bin/mkdir -p ${lib.escapeShellArg "${homeDir}/Programming/work"}
    run ${pkgs.coreutils}/bin/mkdir -p ${lib.escapeShellArg "${homeDir}/Programming/personal"}
  '';
}
