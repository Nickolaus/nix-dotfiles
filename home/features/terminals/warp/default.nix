{ pkgs, ... }:

let
  warpDataDir =
    if pkgs.stdenv.isDarwin then ".warp"
    else ".local/share/warp-terminal";
in
{
  home.file = {
    "${warpDataDir}/themes/nix-dotfiles-kanagawa.yaml".source = ./themes/nix-dotfiles-kanagawa.yaml;
    "${warpDataDir}/tab_configs/dotfiles.toml".source = ./tab_configs/dotfiles.toml;
    "${warpDataDir}/workflows/dotfiles-check.yaml".source = ./workflows/dotfiles-check.yaml;
    "${warpDataDir}/workflows/darwin-switch.yaml".source = ./workflows/darwin-switch.yaml;
    "${warpDataDir}/workflows/update-system.yaml".source = ./workflows/update-system.yaml;
    "${warpDataDir}/workflows/linux-switch.yaml".source = ./workflows/linux-switch.yaml;
  };
}
