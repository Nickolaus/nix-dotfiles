{ pkgs, ... }: {
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
}
