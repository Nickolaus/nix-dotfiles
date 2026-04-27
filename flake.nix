{
  description = "Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    nix-darwin.url = "github:LnL7/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix.url = "github:Mic92/sops-nix";

    mac-app-util.url = "github:hraban/mac-app-util";

    # Disko for declarative disk management
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Impermanence for tmpfs root
    impermanence = {
      url = "github:nix-community/impermanence";
    };
  };

  outputs =
    { self
    , nixpkgs
    , nix-darwin
    , home-manager
    , sops-nix
    , disko
    , impermanence
    , ...
    }:
    let
      extraArgs = {
        inherit sops-nix disko impermanence;
        flake = self;
        remapKeys = false;
      };
      mkDarwinSystem =
        { system
        , hostModule
        , remapKeys ? false
        }:
        nix-darwin.lib.darwinSystem {
          inherit system;
          specialArgs = extraArgs // {
            inherit remapKeys;
          };
          modules = [
            hostModule
            home-manager.darwinModules.default
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = extraArgs // {
                inherit remapKeys;
              };
            }
          ];
        };
      mkFarnsworthSystem = system:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = extraArgs;
          modules = [
            ./hosts/farnsworth
            disko.nixosModules.disko
            impermanence.nixosModules.impermanence
            home-manager.nixosModules.default
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = extraArgs;
              home-manager.users."C.Hessel" = {
                imports = [ ./home/farnsworth.nix ];
              };
            }
          ];
        };
      mkInstaller = system:
        (nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [ ./images/installer.nix ];
        }).config.system.build.isoImage;
    in
    {
      # macOS configurations
      darwinConfigurations = {
        zoidberg = mkDarwinSystem {
          system = "aarch64-darwin";
          hostModule = ./hosts/zoidberg;
          remapKeys = true;
        };
      };

      # NixOS configurations (Linux support)
      nixosConfigurations = {
        # Farnsworth - Multi-arch development laptop
        # Supports both ARM (primary) and x86_64 (secondary)
        # Build with: nixos-rebuild switch --flake .#farnsworth
        farnsworth = mkFarnsworthSystem "aarch64-linux";

        # Farnsworth x86_64 variant (explicit)
        # Build with: nixos-rebuild switch --flake .#farnsworth-x86
        farnsworth-x86 = mkFarnsworthSystem "x86_64-linux";
      };
      # Custom installer ISOs with SSH pre-enabled
      # Build with: nix build .#packages.aarch64-linux.farnsworth-installer
      # Or: nix build .#packages.x86_64-linux.farnsworth-installer
      packages = {
        # ARM (aarch64) installer - for Apple Silicon and ARM laptops
        aarch64-linux.farnsworth-installer = mkInstaller "aarch64-linux";

        # x86_64 installer - for Intel/AMD systems
        x86_64-linux.farnsworth-installer = mkInstaller "x86_64-linux";
      };
    };
}
