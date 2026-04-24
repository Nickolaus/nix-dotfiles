{ config, pkgs, lib, ... }:

{
  imports = [
    # Hardware generated during installation by nixos-generate-config
    ./disko.nix
    ./users.nix
    ../shared/ai-agents.nix
    ../shared/ai-agents-derived.nix
    ../shared/claude-code.nix
    ../shared/determinate.nix
    ../shared/codex.nix
    ../shared/fonts.nix
    ../../modules/nixos/hyprland
    ../../modules/nixos/impermanence
    ../../modules/nixos/btrfs-maintenance
    ../../modules/nixos/hardware
    ../../modules/nixos/flatpak
  ];

  # System state version
  system.stateVersion = "24.11";

  # Hostname
  networking.hostName = "farnsworth";

  # Boot configuration - UEFI with Secure Boot
  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 10; # Keep last 10 generations
      };
      efi.canTouchEfiVariables = true;
    };

    # Kernel - latest for best hardware support
    kernelPackages = pkgs.linuxPackages_latest;

    # Performance optimizations for development laptop
    kernel.sysctl = {
      "vm.swappiness" = 10; # Prefer RAM over swap
      "fs.inotify.max_user_watches" = 524288; # For development tools
    };

    # Initrd modules for encryption and performance
    initrd = {
      availableKernelModules = [ 
        "xhci_pci" "nvme" "usb_storage" "sd_mod" "rtsx_pci_sdmmc"
        "ahci" "usbhid" "uas"
      ];
      systemd.enable = true; # Modern systemd-based initrd
    };

    # Laptop-specific: enable thermald for thermal management (x86_64 only)
    kernelModules = [ "kvm-intel" "kvm-amd" ]; # Support both Intel and AMD
  };

  # Enable zram for compressed swap in RAM
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  # LUKS encryption with multi-method unlock
  # Actual device configuration in disko.nix
  boot.initrd.luks.devices."cryptroot" = {
    # Allow TPM2 auto-unlock
    crypttabExtraOpts = [ "tpm2-device=auto" ];
    # FIDO2/YubiKey support (toggleable)
    # yubikey.enable = false; # Set to true when YubiKey is configured
  };

  # Time zone
  time.timeZone = "Europe/Berlin";

  # Localization - German system, English CLI
  i18n = {
    defaultLocale = "de_DE.UTF-8";
    extraLocaleSettings = {
      # Keep CLI messages in English for better documentation
      LC_MESSAGES = "en_US.UTF-8";
      LC_TIME = "de_DE.UTF-8";
      LC_NUMERIC = "de_DE.UTF-8";
      LC_MONETARY = "de_DE.UTF-8";
      LC_PAPER = "de_DE.UTF-8";
      LC_MEASUREMENT = "de_DE.UTF-8";
    };
  };

  # Console keyboard layout
  console = {
    font = "Lat2-Terminus16";
    keyMap = "de";
  };

  # Networking
  networking = {
    networkmanager = {
      enable = true;
      wifi.powersave = true; # Battery optimization
    };
    
    # Firewall configuration with toggleable groups
    firewall = {
      enable = true; # Toggle: set to false to disable
      
      # Core services
      allowedTCPPorts = [
        22    # SSH
        80    # HTTP
        443   # HTTPS
      ];
      
      # Development ports (toggleable via config)
      allowedTCPPortRanges = [
        { from = 3000; to = 3001; }  # Node.js dev
        { from = 4000; to = 4001; }  # Alt dev
        { from = 5000; to = 5001; }  # Flask/misc
        { from = 8000; to = 8080; }  # Various dev servers
        { from = 9000; to = 9001; }  # Alt services
      ];
      
      # Database ports (comment out if not needed)
      # allowedTCPPorts = [ 3306 5432 6379 27017 ];
      
      # UDP ports for mDNS and development
      allowedUDPPorts = [ 5353 ];
    };
  };

  # User configuration in ./users.nix

  # SSH server configuration
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false; # Key-based only
      PermitRootLogin = "no";
      X11Forwarding = false;
    };
    # Listen on standard port (change if needed)
    ports = [ 22 ];
  };

  # Sound - PipeWire (modern audio/video pipeline)
  security.rtkit.enable = true; # RealtimeKit for audio
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true; # Optional: JACK support
  };

  # Bluetooth support
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Enable = "Source,Sink,Media,Socket";
        Experimental = true; # Enable experimental features
      };
    };
  };
  services.blueman.enable = true; # Bluetooth GUI manager

  # Printing support (CUPS)
  services.printing.enable = true;
  services.gvfs.enable = true; # MTP/GIO integration so Android phones appear in file managers
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true; # For network printer discovery
  };

  # Docker configuration
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  # Dev containers support
  virtualisation.containers.enable = true;

  # Allow unfree packages (NVIDIA drivers, Slack, etc.)
  nixpkgs.config.allowUnfree = true;

  # Nix configuration
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      trusted-users = [ "root" "C.Hessel" ];
      auto-optimise-store = true;
      
      # Binary cache configuration
      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
        "https://hyprland.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      ];
    };
    
    # Garbage collection
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  # System packages (minimal - most packages in Home Manager)
  environment.systemPackages = with pkgs; [
    vim
    git
    wget
    curl
    htop
    cryptsetup # For LUKS management
    tpm2-tools  # For TPM2 operations
  ];

  # Laptop power management
  # Intel thermal management (x86_64 only - not available on ARM)
  services.thermald.enable = pkgs.stdenv.isx86_64;
  services.auto-cpufreq = {
    enable = true;
    settings = {
      battery = {
        governor = "powersave";
        turbo = "never";
      };
      charger = {
        governor = "performance";
        turbo = "auto";
      };
    };
  };

  # Enable upower for battery management
  services.upower.enable = true;

  # Laptop lid and power button actions (NixOS 24.11+ settings format)
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "lock";
    HandlePowerKey = "suspend";
    IdleAction = "suspend";
    IdleActionSec = "15min";
  };

  # Enable location services for automatic timezone
  services.geoclue2.enable = true;

  # System update notifications (manual execution)
  systemd.timers."nixos-update-check" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "15min";
      OnUnitActiveSec = "1d";
      Unit = "nixos-update-check.service";
    };
  };

  systemd.services."nixos-update-check" = {
    script = ''
      ${pkgs.nix}/bin/nix-channel --update
      ${pkgs.libnotify}/bin/notify-send "System Update" "Updates available. Run: sudo nixos-rebuild switch"
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "C.Hessel";
    };
  };

  # Documentation
  documentation = {
    enable = true;
    man.enable = true;
    dev.enable = false; # Development docs (large)
  };
}
