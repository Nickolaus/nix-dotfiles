{ config, pkgs, lib, ... }:

# Flatpak declarative management
# Similar to modules/darwin/brew/ for consistent architecture

{
  # Enable Flatpak
  services.flatpak.enable = true;

  # Add Flathub repository
  systemd.services.flatpak-repo = {
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.flatpak ];
    script = ''
      flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    '';
  };

  # Declarative Flatpak package management
  # Add Flatpak apps here (similar to Homebrew casks on macOS)
  systemd.services.flatpak-managed-install = {
    wantedBy = [ "multi-user.target" ];
    after = [ "flatpak-repo.service" ];
    path = [ pkgs.flatpak ];
    script = let
      # List of Flatpak apps to install
      # Add apps here in the format: "app.id"
      flatpakApps = [
        # Example applications (uncomment to enable):
        # "com.spotify.Client"
        # "com.discordapp.Discord"
        # "org.telegram.desktop"
        # "com.slack.Slack"
        # "us.zoom.Zoom"
        # "org.signal.Signal"
        # "com.visualstudio.code"
        # "org.gimp.GIMP"
        # "org.inkscape.Inkscape"
        # "org.blender.Blender"
        # "com.obsproject.Studio"
        # "org.videolan.VLC"
        
        # Add more apps as needed
      ];
      
      installCmd = app: ''
        if ! flatpak info ${app} &>/dev/null; then
          echo "Installing ${app}..."
          flatpak install -y flathub ${app}
        else
          echo "${app} already installed"
        fi
      '';
    in ''
      ${lib.concatMapStringsSep "\n" installCmd flatpakApps}
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
  };

  # XDG Desktop Portal for Flatpak
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # Fonts for Flatpak apps
  fonts.fontDir.enable = true;

  # Helper script for managing Flatpak apps (similar to brew commands)
  environment.systemPackages = with pkgs; [
    flatpak
    
    # Create helper script
    (writeShellScriptBin "flatpak-list" ''
      # List all installed Flatpak apps
      echo "=== Installed Flatpak Applications ==="
      ${flatpak}/bin/flatpak list --app
    '')
    
    (writeShellScriptBin "flatpak-update-all" ''
      # Update all Flatpak apps
      echo "Updating all Flatpak applications..."
      ${flatpak}/bin/flatpak update -y
    '')
    
    (writeShellScriptBin "flatpak-search" ''
      # Search for Flatpak apps
      if [ -z "$1" ]; then
        echo "Usage: flatpak-search <app-name>"
        exit 1
      fi
      ${flatpak}/bin/flatpak search "$1"
    '')
  ];

  # Note: To add a new Flatpak app declaratively:
  # 1. Add the app ID to the flatpakApps list above
  # 2. Run: sudo nixos-rebuild switch
  # 3. The app will be automatically installed
  
  # To find app IDs: flatpak search <app-name>
  # Or browse: https://flathub.org
}

