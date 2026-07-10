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

    # AI agent source inputs. Flake input declarations must stay static here;
    # flake/ai-agent-sources.nix groups their typed use sites.
    caveman = {
      url = "github:JuliusBrussee/caveman/v1.8.2";
      flake = false;
    };

    mattpocock-skills = {
      url = "github:mattpocock/skills/v1.1.0";
      flake = false;
    };

    gstack = {
      url = "github:garrytan/gstack/main";
      flake = false;
    };

    serena.url = "github:oraios/serena/v1.5.3";

    # Reuse Serena's pinned pyproject toolchain for repo-owned Python app envs.
    pyproject-nix.follows = "serena/pyproject-nix";
    uv2nix.follows = "serena/uv2nix";
    pyproject-build-systems.follows = "serena/pyproject-build-systems";

    codebase-memory-mcp.url = "github:DeusData/codebase-memory-mcp/v0.8.1";

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
    , pyproject-nix
    , uv2nix
    , pyproject-build-systems
    , ...
    }:
    let
      inherit (nixpkgs) lib;
      flakeSystems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      forAllSystems = lib.genAttrs flakeSystems;
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
      packages = forAllSystems
        (system:
          let
            pkgs = import nixpkgs {
              inherit system;
              config.allowUnfreePredicate = pkg:
                lib.getName pkg == "arize-phoenix";
            };
          in
          {
            arize-phoenix = pkgs.callPackage ./packages/arize-phoenix {
              inherit pyproject-nix uv2nix pyproject-build-systems;
            };
          } // lib.optionalAttrs (system == "aarch64-linux") {
            # ARM (aarch64) installer - for Apple Silicon and ARM laptops
            farnsworth-installer = mkInstaller "aarch64-linux";
          } // lib.optionalAttrs (system == "x86_64-linux") {
            # x86_64 installer - for Intel/AMD systems
            farnsworth-installer = mkInstaller "x86_64-linux";
          });
    };
}
