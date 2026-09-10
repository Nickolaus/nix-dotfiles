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
      url = "github:JuliusBrussee/caveman/v2.6.0";
      flake = false;
    };

    mattpocock-skills = {
      url = "github:mattpocock/skills/v1.2.3";
      flake = false;
    };

    gstack = {
      url = "github:garrytan/gstack/main";
      flake = false;
    };

    # No upstream tags/releases as of pinning; pinned by commit instead.
    i-have-adhd = {
      url = "github:ayghri/i-have-adhd/2ed064090711586e0c97a2fbbf15465fe8f1808b";
      flake = false;
    };

    serena.url = "github:oraios/serena/v1.7.0";

    codebase-memory-mcp.url = "github:DeusData/codebase-memory-mcp/v0.10.8";

    # Disko for declarative disk management
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Impermanence for tmpfs root
    impermanence = {
      url = "github:nix-community/impermanence";
    };

    # NixOS-WSL for the bender host (NixOS running under WSL2)
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
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
    , nixos-wsl
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
        # `desktop` gates the Wayland stack from inside `imports`, so it must be
        # supplied as a specialArg by every caller. A module-level default would
        # send the module system through `config._module.args` while `imports`
        # is still being computed, which is infinite recursion.
        desktop = true;
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
      # Standalone Home Manager (non-NixOS Linux, e.g. a plain distro under WSL2).
      # Reuses home/bender.nix with the desktop stack (hyprland/waybar)
      # disabled since there's no Wayland session to run it against.
      mkWslHome = system:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          extraSpecialArgs = extraArgs // { desktop = false; };
          modules = [ ./home/bender.nix ];
        };
      # bender - NixOS-WSL. No disko/impermanence: WSL2 owns the disk image,
      # and there's no bootloader to configure inside the VM.
      mkWslSystem = system:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = extraArgs // { desktop = false; };
          modules = [
            ./hosts/bender
            nixos-wsl.nixosModules.default
            home-manager.nixosModules.default
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = extraArgs // { desktop = false; };
              home-manager.users."C.Hessel" = {
                imports = [ ./home/bender.nix ];
              };
            }
          ];
        };
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

        # bender - NixOS-WSL (WSL2 on Windows)
        # Build with: nixos-rebuild switch --flake .#bender
        bender = mkWslSystem "x86_64-linux";

        # bender ARM64 variant (Windows on ARM)
        # Build with: nixos-rebuild switch --flake .#bender-aarch64
        bender-aarch64 = mkWslSystem "aarch64-linux";
      };

      # Standalone Home Manager configurations (non-NixOS Linux, e.g. a plain
      # distro under WSL2, as a fallback to the bender NixOS-WSL host above)
      # Build with: nix run home-manager -- switch --flake .#C.Hessel
      homeConfigurations = {
        "C.Hessel" = mkWslHome "x86_64-linux";
        "C.Hessel-aarch64" = mkWslHome "aarch64-linux";
      };

      # Custom installer ISOs with SSH pre-enabled
      # Build with: nix build .#packages.aarch64-linux.farnsworth-installer
      # Or: nix build .#packages.x86_64-linux.farnsworth-installer
      packages = forAllSystems
        (system:
          (lib.optionalAttrs (system == "aarch64-linux") {
            # ARM (aarch64) installer - for Apple Silicon and ARM laptops
            farnsworth-installer = mkInstaller "aarch64-linux";
          })
          // (lib.optionalAttrs (system == "x86_64-linux") {
            # x86_64 installer - for Intel/AMD systems
            farnsworth-installer = mkInstaller "x86_64-linux";
          }));
    };
}
