{ config, lib, pkgs, ... }:

let
  inherit (lib) mkEnableOption mkIf mkOption types;

  cfg = config.cursorAgent;

  # Cursor's CLI agent has no nixpkgs derivation and no Homebrew formula --
  # it only ships via this curl installer, which self-manages versioned
  # installs under ~/.local/share/cursor-agent and symlinks the current one
  # to ~/.local/bin/agent. Nix/darwin-rebuild never touches that path, so it
  # goes stale silently unless something re-runs the installer. The binary's
  # own `agent update` subcommand fails with "[unauthenticated] Error" even
  # when logged in (confirmed on 2026.07.20-8cc9c0b) -- the installer script
  # is the only path that reliably works.
  markerFile = "${config.home.homeDirectory}/.local/share/cursor-agent/.nix-last-update-check";

  # Home Manager's activation script PATH is a hardcoded minimal set
  # (coreutils/jq/etc, see rtk.nix's perUserSystemProfileBin comment) that
  # excludes curl and tar -- confirmed directly ("curl: command not found").
  # Fixing our own invocation with nixpkgs paths isn't enough: the installer
  # script downloaded from cursor.com shells out to bare `curl`/`tar` itself,
  # so its child processes need those on PATH too. Prepend /usr/bin, where
  # macOS always has both, rather than trying to thread nixpkgs derivations
  # through a script we don't control.
  installScript = ''
    PATH="/usr/bin:/bin:$PATH" ${pkgs.curl}/bin/curl -fsS https://cursor.com/install \
      | PATH="/usr/bin:/bin:$PATH" ${pkgs.bash}/bin/bash >/dev/null 2>&1 \
      && mkdir -p "$(dirname ${markerFile})" \
      && touch ${markerFile} \
      || echo "Warning: cursor-agent update check failed (offline or cursor.com unreachable)" >&2
  '';
in
{
  options.cursorAgent = {
    enable = mkEnableOption "Cursor CLI agent (ACP) auto-update on activation" // {
      default = true;
    };

    updateIntervalDays = mkOption {
      type = types.int;
      default = 7;
      description = ''
        Minimum days between automatic reinstalls during Home Manager
        activation. The installer re-downloads the full package
        (node runtime + bundle, well over 100MB) every run, so this throttles
        it instead of paying that cost on every darwin-rebuild switch.
        Run `cursor-agent-update` for an immediate on-demand update.
      '';
    };
  };

  config = mkIf cfg.enable {
    home.activation.ensureCursorAgentUpdated = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      # Pin to nixpkgs' coreutils explicitly: this activation PATH resolves
      # GNU stat ahead of /usr/bin/stat, and GNU's `-f` flag means something
      # unrelated to BSD's (filesystem info, not a format string) -- a
      # BSD/GNU fallback pair silently produced garbage instead of erroring.
      stale=1
      if [ -f ${markerFile} ]; then
        now=$(date +%s)
        last=$(${pkgs.coreutils}/bin/stat -c %Y ${markerFile} 2>/dev/null || echo 0)
        age_days=$(( (now - last) / 86400 ))
        if [ "$age_days" -lt ${toString cfg.updateIntervalDays} ]; then
          stale=0
        fi
      fi

      if [ "$stale" = "1" ]; then
        ${installScript}
      fi
    '';

    home.packages = [
      (pkgs.writeShellScriptBin "cursor-agent-update" ''
        set -euo pipefail
        echo "Updating Cursor CLI agent (cursor.com/install)..."
        ${installScript}
        echo "agent -> $(readlink ${config.home.homeDirectory}/.local/bin/agent 2>/dev/null || echo 'not found')"
      '')
    ];
  };
}
