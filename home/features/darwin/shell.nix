{ config, pkgs, lib, ... }:
lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (
  let
    colimaBin = "/opt/homebrew/bin/colima";
    colimaLog = "${config.home.homeDirectory}/Library/Logs/colima";
  in
  {
    # Give shell- and GUI-launched agents one deterministic local Docker target.
    # Users can override per command with DOCKER_CONTEXT=remote.
    home.sessionVariables.DOCKER_CONTEXT = "colima";

    home.activation.ensureColimaLogDirectory = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${pkgs.coreutils}/bin/mkdir -p ${colimaLog}
    '';

    programs.fish = {
      shellAbbrs = {
        "cstatus" = "colima status";
        "cstart" = "colima start";
        "cstop" = "colima stop";
      };

      # macOS-specific shell initialization for Homebrew integration
      # This addresses the nix-darwin path ordering issue: https://github.com/LnL7/nix-darwin/issues/122
      shellInit = ''
        # Homebrew environment configuration (macOS only)
        set -gx HOMEBREW_PREFIX "/opt/homebrew";
        set -gx HOMEBREW_CELLAR "/opt/homebrew/Cellar";
        set -gx HOMEBREW_REPOSITORY "/opt/homebrew";
        ! set -q PATH; and set PATH \'\'; set -gx PATH "/opt/homebrew/bin" "/opt/homebrew/sbin" $PATH;
        ! set -q MANPATH; and set MANPATH \'\'; set -gx MANPATH "/opt/homebrew/share/man" $MANPATH;
        ! set -q INFOPATH; and set INFOPATH \'\'; set -gx INFOPATH "/opt/homebrew/share/info" $INFOPATH;

        # Homebrew package-specific paths
        fish_add_path /opt/homebrew/opt/mysql-client/bin
      '';
    };

    launchd.agents.colima = {
      enable = true;
      config = {
        ProgramArguments = [
          colimaBin
          "start"
          "--foreground"
          "--vm-type"
          "vz"
          "--mount-type"
          "virtiofs"
        ];
        RunAtLoad = true;
        # Restart crashes, but respect a clean `colima stop`.
        KeepAlive = { SuccessfulExit = false; };
        ThrottleInterval = 5;
        ProcessType = "Background";
        StandardOutPath = "${colimaLog}/colima.log";
        StandardErrorPath = "${colimaLog}/colima.error.log";
        EnvironmentVariables = {
          HOME = config.home.homeDirectory;
          PATH = "/etc/profiles/per-user/${config.home.username}/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/bin:/bin:/usr/sbin:/sbin";
          DOCKER_CONTEXT = "colima";
        };
      };
    };
  }
)
