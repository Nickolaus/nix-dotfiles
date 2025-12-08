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
      # Hardware acceleration
      hardware.opengl = {
        enable = true;
        driSupport = true;
        driSupport32Bit = true; # For 32-bit applications
        
        extraPackages = with pkgs; [
          # VA-API and VDPAU
          vaapiVdpau
          libvdpau-va-gl
        ];
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
      
      # AMD-specific OpenGL packages
      hardware.opengl.extraPackages = with pkgs; [
        rocm-opencl-icd
        rocm-opencl-runtime
        amdvlk
      ];
      
      # 32-bit support for AMD
      hardware.opengl.extraPackages32 = with pkgs; [
        driversi686Linux.amdvlk
      ];
      
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

