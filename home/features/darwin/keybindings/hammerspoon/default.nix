{
  lib,
  pkgs,
  ...
}:
lib.mkIf pkgs.stdenv.isDarwin {

  home.file.".hammerspoon" = {
    source = ./config;
    recursive = true;
  };

  home.activation = {
    reloadHammerspoon = lib.hm.dag.entryAfter ["writeBoundary"] ''
        run timeout 5 /opt/homebrew/bin/hs -c "hs.reload()" || true
    '';
  };

}
