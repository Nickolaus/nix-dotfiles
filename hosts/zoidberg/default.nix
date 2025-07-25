{ pkgs
, home-manager
, flake
, lib
, config
, ...
}: {
  imports = [
    ../shared/determinate.nix
    ../shared/fonts.nix
    ../../modules/darwin/aerospace
    ../../modules/darwin/brew
    ../../modules/darwin/system
  ];

  system.stateVersion = 5;
  system.primaryUser = "C.Hessel";

  ids.gids.nixbld = 350;

  users.users."C.Hessel" = {
    home = "/Users/C.Hessel";
    shell = "${pkgs.fish}/bin/fish";
  };

  home-manager.backupFileExtension = "backup";
  home-manager.users."C.Hessel" = {
    imports = [
      ../../home/zoidberg.nix
    ];
  };

  environment.systemPackages = with pkgs; [
    # System-level packages only (CLI tools, system utilities)
    # GUI applications should be in home/features/darwin/packages.nix
  ];

  nixpkgs.config.allowUnfree = true;

  programs.fish.enable = true;
  environment.shells = [ "${pkgs.fish}/bin/fish" ];

  documentation.enable = false;
  documentation.man.enable = false;

  time.timeZone = "Europe/Berlin";

  nix.enable = false;
}
