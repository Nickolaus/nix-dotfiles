{ config, lib, pkgs, ... }:
let
  homeDir = config.home.homeDirectory;
  keys = config.sshKeys;

  signingKey = keys.signing.keys.${keys.signing.active};

  # allowed_signers entry per signing key. The validity stamps scope a key to
  # the window it signed in, so a retired key still verifies its own commits.
  signerLine = _name: key:
    "${key.principal} namespaces=\"git\""
    + lib.optionalString (key.validAfter != null) " valid-after=\"${key.validAfter}\""
    + lib.optionalString (key.validBefore != null) " valid-before=\"${key.validBefore}\""
    + " ${key.publicKey}";

  # One -i per identity the scope offers, in the same order ssh_config lists
  # them, so a repo pinned to a scope follows that scope through a rotation.
  gitIncludes = lib.mapAttrs'
    (name: scope: lib.nameValuePair ".config/git/${name}.inc" {
      text = ''
        [core]
          sshCommand = ssh ${lib.concatMapStringsSep " " (path: "-i ${path}") (keys.scopePaths scope)} -o IdentitiesOnly=yes
      '';
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

    signing.key = signingKey.publicKey;
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
