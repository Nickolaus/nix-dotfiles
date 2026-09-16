{ pkgs
, home-manager
, flake
, lib
, config
, ...
}: {
  imports = [
    ../shared/ai-agents-default.nix
    ../shared/determinate.nix
    ../shared/fonts.nix
    ../../modules/darwin/aerospace
    ../../modules/darwin/brew
    ../../modules/darwin/system
  ];

  system.stateVersion = 5;
  system.primaryUser = "C.Hessel";

  ids.gids.nixbld = 350;

  # nix-darwin only writes the Directory Services record for users listed in
  # knownUsers; without it the account's UserShell is whatever it was at account
  # creation and never tracks this file.
  users.knownUsers = [ "C.Hessel" ];
  users.users."C.Hessel" = {
    uid = 501;
    home = "/Users/C.Hessel";
    # Pass the package, not an interpolated "${pkgs.fish}/bin/fish" string:
    # nix-darwin maps a shell package to /run/current-system/sw/bin/fish, which
    # stays valid across rebuilds, while a raw store path dies at the next GC
    # and drops logins back to /bin/sh.
    shell = pkgs.fish;
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
  environment.shells = [ pkgs.fish ];

  documentation.enable = false;
  documentation.man.enable = false;

  time.timeZone = "Europe/Berlin";

  nix.enable = false;
}
