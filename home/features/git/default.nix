{ config, lib, pkgs, ... }:
let
  homeDir = config.home.homeDirectory;
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

    signing.key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHBw37pfQ1qRRONPampA3kv/2AhcmZxgzdMPcXuRI9Ue";
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

  home.file = {
    ".ssh/allowed_signers".text = "c.hessel@shopware.com namespaces=\"git\" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHBw37pfQ1qRRONPampA3kv/2AhcmZxgzdMPcXuRI9Ue";

    ".config/git/work.inc".text = ''
      [core]
        sshCommand = ssh -i ~/.ssh/id_ed25519 -o IdentitiesOnly=yes
    '';

    ".config/git/personal.inc".text = ''
      [core]
        sshCommand = ssh -i ~/.ssh/id_ed25519_personal -o IdentitiesOnly=yes
    '';

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
