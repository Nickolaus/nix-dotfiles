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

    devenv.url = "github:cachix/devenv";

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
    , devenv
    , sops-nix
    , disko
    , impermanence
    , ...
    }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      # TODO: remove once nixpkgs updates devenv past 2.0.3
      # Workaround for cachix/devenv#2576: bdwgc thread registration crash on aarch64-darwin
      devenvOverlay = final: prev: {
        devenv = devenv.packages.${final.system}.default;
      };
      extraArgs = {
        inherit sops-nix disko impermanence;
        flake = self;
        remapKeys = false;
      };
    in
    {
      # macOS configurations
      darwinConfigurations = {
        zoidberg = nix-darwin.lib.darwinSystem {
          specialArgs = extraArgs // {
            remapKeys = true;
          };
          system = "aarch64-darwin";
          modules = [
            ./hosts/zoidberg
            home-manager.darwinModules.default
            {
              nixpkgs.overlays = [ devenvOverlay ];
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = extraArgs // { remapKeys = true; };
            }
          ];
        };
      };

      # NixOS configurations (Linux support)
      nixosConfigurations = {
        # Farnsworth - Multi-arch development laptop
        # Supports both ARM (primary) and x86_64 (secondary)
        # Build with: nixos-rebuild switch --flake .#farnsworth
        farnsworth = nixpkgs.lib.nixosSystem {
          # Default to ARM, but configuration works on both architectures
          system = "aarch64-linux";  # Change to "x86_64-linux" for x86_64 deployment
          specialArgs = extraArgs;
          modules = [
            ./hosts/farnsworth
            disko.nixosModules.disko
            impermanence.nixosModules.impermanence
            home-manager.nixosModules.default
            {
              nixpkgs.overlays = [ devenvOverlay ];
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = extraArgs;
              home-manager.users."C.Hessel" = {
                imports = [ ./home/farnsworth.nix ];
              };
            }
          ];
        };

        # Farnsworth x86_64 variant (explicit)
        # Build with: nixos-rebuild switch --flake .#farnsworth-x86
        farnsworth-x86 = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = extraArgs;
          modules = [
            ./hosts/farnsworth
            disko.nixosModules.disko
            impermanence.nixosModules.impermanence
            home-manager.nixosModules.default
            {
              nixpkgs.overlays = [ devenvOverlay ];
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = extraArgs;
              home-manager.users."C.Hessel" = {
                imports = [ ./home/farnsworth.nix ];
              };
            }
          ];
        };
      };
      # Custom installer ISOs with SSH pre-enabled
      # Build with: nix build .#packages.aarch64-linux.farnsworth-installer
      # Or: nix build .#packages.x86_64-linux.farnsworth-installer
      packages = {
        # ARM (aarch64) installer - for Apple Silicon and ARM laptops
        aarch64-linux.farnsworth-installer = (nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          modules = [ ./images/installer.nix ];
        }).config.system.build.isoImage;
        
        # x86_64 installer - for Intel/AMD systems
        x86_64-linux.farnsworth-installer = (nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [ ./images/installer.nix ];
        }).config.system.build.isoImage;
      };
    };
}
