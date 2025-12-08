{ config, pkgs, lib, ... }:

# Hardware support module
# Toggleable GPU drivers, Bluetooth, and other hardware features

let
  cfg = config.hardware;
in
{
  options.hardware = {
    nvidia.enable = lib.mkEnableOption "NVIDIA GPU support";
    amdgpu.enable = lib.mkEnableOption "AMD GPU support";
  };

  config = lib.mkMerge [
    # Base hardware configuration (always enabled)
    {
      # Hardware acceleration (NixOS 24.11+ uses hardware.graphics)
      hardware.graphics = {
        enable = true;
        # driSupport and driSupport32Bit are deprecated and removed
        
        extraPackages = with pkgs; [
          # VA-API and VDPAU (NixOS 24.11+ renamed packages)
          libva-vdpau-driver
          libvdpau-va-gl
        ];
        
        # 32-bit support (only on x86_64)
        enable32Bit = lib.mkIf (pkgs.stdenv.hostPlatform.system == "x86_64-linux") true;
      };

      # Enable firmware updates
      services.fwupd.enable = true;
      
      # Enable TRIM for SSDs
      services.fstrim = {
        enable = true;
        interval = "weekly";
      };
    }

    # NVIDIA GPU configuration (toggleable)
    (lib.mkIf cfg.nvidia.enable {
      services.xserver.videoDrivers = [ "nvidia" ];
      
      hardware.nvidia = {
        # Modesetting is required for Wayland
        modesetting.enable = true;
        
        # Power management (important for laptops)
        powerManagement.enable = true;
        powerManagement.finegrained = false;
        
        # Use the open source kernel module (not "open-gpu-kernel-modules")
        # Set to true if using RTX 20 series or newer
        open = false;
        
        # Enable the Nvidia settings menu
        nvidiaSettings = true;
        
        # Select the appropriate driver version
        # Options: stable, beta, production, latest
        package = config.boot.kernelPackages.nvidiaPackages.stable;
        
        # Optional: PRIME for hybrid graphics (uncomment if needed)
        # prime = {
        #   offload.enable = true;
        #   # Bus IDs - find using: lspci | grep -E "VGA|3D"
        #   intelBusId = "PCI:0:2:0";
        #   nvidiaBusId = "PCI:1:0:0";
        # };
      };
      
      # Additional NVIDIA packages
      environment.systemPackages = with pkgs; [
        nvtop          # GPU monitoring
        nvidia-vaapi-driver  # VA-API support
      ];
      
      # Environment variables for NVIDIA
      environment.sessionVariables = {
        LIBVA_DRIVER_NAME = "nvidia";
        GBM_BACKEND = "nvidia-drm";
        __GLX_VENDOR_LIBRARY_NAME = "nvidia";
        WLR_NO_HARDWARE_CURSORS = "1"; # Fix for cursor issues
      };
    })

    # AMD GPU configuration (toggleable)
    (lib.mkIf cfg.amdgpu.enable {
      services.xserver.videoDrivers = [ "amdgpu" ];
      
      # AMD-specific graphics packages
      hardware.graphics.extraPackages = with pkgs; [
        rocm-opencl-icd
        rocm-opencl-runtime
        amdvlk
      ];
      
      # 32-bit support for AMD (only on x86_64)
      hardware.graphics.extraPackages32 = lib.mkIf (pkgs.stdenv.hostPlatform.system == "x86_64-linux") (with pkgs; [
        driversi686Linux.amdvlk
      ]);
      
      # Additional AMD packages
      environment.systemPackages = with pkgs; [
        radeontop      # GPU monitoring
        rocm-smi       # AMD GPU tool
      ];
      
      # Environment variables for AMD
      environment.sessionVariables = {
        AMD_VULKAN_ICD = "RADV";
      };
    })
  ];
}

