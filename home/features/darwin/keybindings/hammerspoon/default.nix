{ config
, lib
, pkgs
, ...
}:
let
  hammerspoonConfigSource = builtins.path {
    path = ./config;
    name = "hammerspoon-config";
  };
  hammerspoonConfigSourceString = builtins.unsafeDiscardStringContext "${hammerspoonConfigSource}";
  hammerspoonMarkerDir = "${config.home.homeDirectory}/.cache/nix-dotfiles";
  hammerspoonMarker = "${hammerspoonMarkerDir}/hammerspoon-config-source";
in
lib.mkIf pkgs.stdenv.isDarwin {

  home.file.".hammerspoon" = {
    source = hammerspoonConfigSource;
    recursive = true;
  };

  home.activation = {
    reloadHammerspoon = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      current_source=${lib.escapeShellArg hammerspoonConfigSourceString}
      previous_source="$(${pkgs.coreutils}/bin/cat ${lib.escapeShellArg hammerspoonMarker} 2>/dev/null || true)"
      reload_succeeded=0

      hammerspoon_ipc_available() {
        [ -x /opt/homebrew/bin/hs ] && run ${pkgs.coreutils}/bin/timeout 5 /opt/homebrew/bin/hs -c "return 'ok'"
      }

      restart_hammerspoon() {
        echo "Hammerspoon IPC unavailable; restarting Hammerspoon" >&2
        run /usr/bin/killall Hammerspoon 2>/dev/null || true
        run /usr/bin/open -gja Hammerspoon || true
        run ${pkgs.coreutils}/bin/sleep 1

        if hammerspoon_ipc_available; then
          reload_succeeded=1
        else
          echo "warning: Hammerspoon did not expose IPC after restart" >&2
        fi
      }

      if [ "$previous_source" != "$current_source" ]; then
        echo "Hammerspoon config changed; reloading" >&2
        run ${pkgs.coreutils}/bin/mkdir -p ${lib.escapeShellArg hammerspoonMarkerDir}

        if [ -x /opt/homebrew/bin/hs ] && run ${pkgs.coreutils}/bin/timeout 5 /opt/homebrew/bin/hs -c "hs.reload()"; then
          reload_succeeded=1
        else
          restart_hammerspoon
        fi

        if [ -z "''${DRY_RUN_CMD:-}" ] && [ "$reload_succeeded" = 1 ]; then
          ${pkgs.coreutils}/bin/printf '%s\n' "$current_source" > ${lib.escapeShellArg hammerspoonMarker}
        fi
      elif ! hammerspoon_ipc_available; then
        restart_hammerspoon
      fi
    '';
  };

}
