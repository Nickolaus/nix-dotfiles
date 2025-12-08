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

    devenv.url = "github:cachix/devenv/v1.6.1";

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
      extraArgs = {
        inherit sops-nix disko impermanence;
        flake = self;
      };
    in
    {
      # macOS configurations
      darwinConfigurations = {
        zoidberg = nix-darwin.lib.darwinSystem {
          specialArgs = extraArgs // {
            remapKeys = false;
          };
          system = "aarch64-darwin";
          modules = [
            ./hosts/zoidberg
            home-manager.darwinModules.default
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = extraArgs;
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

      # Standalone home-manager configurations
      homeConfigurations = {
        "C.Hessel" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.aarch64-darwin;
          extraSpecialArgs = extraArgs;
          modules = [
            ./home
          ];
        };
      };
    };
}
