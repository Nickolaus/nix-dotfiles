{ pkgs
, lib
, flake
, ...
}: {

  imports = [
    flake.inputs.sops-nix.homeManagerModule
    ./features
  ];

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Shared environment variables
  home.sessionVariables = {
    EDITOR = "nvim";
  };

  # Note: home.username, home.homeDirectory, and home.stateVersion
  # are defined in host-specific configs (zoidberg.nix, farnsworth.nix)
  # Each host sets its own stateVersion based on its first installation date.
}
