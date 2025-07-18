{ pkgs
, remapKeys
, ...
}: {
  system.defaults.dock = {
    autohide = true;
    autohide-delay = 0.0;

    autohide-time-modifier = 0.2;
    expose-animation-duration = 0.2;
    tilesize = 48;
    launchanim = false;
    static-only = false;
    showhidden = true;
    show-recents = false;
    show-process-indicators = true;
    orientation = "bottom";
    mru-spaces = false;
  };

  # Menu bar configuration moved to SketchyBar module

  security.pam.services.sudo_local.touchIdAuth = true;

  system.keyboard = {
    enableKeyMapping = true;
    swapLeftCommandAndLeftAlt = remapKeys;

    # Windows keyboard layout alignment:
    # On Windows keyboards: [Ctrl] [Win] [Alt] [Space] [Alt] [Win] [Menu] [Ctrl]
    # On Mac we want:      [Ctrl] [Cmd] [Opt] [Space] [Opt] [Cmd] [Menu] [Ctrl]
    # 
    # This mapping swaps Option ↔ Command so that:
    # - Physical Windows key acts as Mac Command (⌘) for system shortcuts
    # - Physical Alt key acts as Mac Option (⌥) for special characters
    # - Result: Alt+Tab = Option+Tab (app switching), Win+C = Command+C (copy)
    userKeyMapping = [
      {
        HIDKeyboardModifierMappingSrc = 30064771300; # Left Option (Alt key on Windows keyboard)
        HIDKeyboardModifierMappingDst = 30064771302; # Left Command (becomes ⌘)
      }
    ];
  };

  system.defaults = {
    NSGlobalDomain.AppleShowAllExtensions = true;
    NSGlobalDomain.NSWindowShouldDragOnGesture = true;
    WindowManager.EnableStandardClickToShowDesktop = false;
    finder.AppleShowAllExtensions = true;
    finder._FXShowPosixPathInTitle = true;
    finder.FXEnableExtensionChangeWarning = false;
  };

  system.defaults.CustomUserPreferences = {
    "com.apple.finder" = {
      ShowExternalHardDrivesOnDesktop = true;
      ShowHardDrivesOnDesktop = true;
      ShowMountedServersOnDesktop = true;
      ShowRemovableMediaOnDesktop = true;
      _FXSortFoldersFirst = true;
      # When performing a search, search the current folder by default
      FXDefaultSearchScope = "SCcf";
    };
    "com.apple.desktopservices" = {
      # Avoid creating .DS_Store files on network or USB volumes
      DSDontWriteNetworkStores = true;
      DSDontWriteUSBStores = true;
    };
    "com.apple.spaces" = {
      # Disable displays from spanning across multiple desktops/spaces
      # 
      # This prevents windows from spanning across monitors when using Mission Control
      # or desktop spaces, which is essential for proper AeroSpace window management.
      # AeroSpace assigns specific workspaces to specific monitors (see ../aerospace/default.nix)
      # and spans-displays interferes with this by allowing windows to stretch across displays.
      #
      # Equivalent to: defaults write com.apple.spaces spans-displays -bool false && killall SystemUIServer
      # ⚠️ IMPORTANT: Requires logout to take effect after first installation
      spans-displays = false;
    };
    "com.apple.AdLib" = {
      allowApplePersonalizedAdvertising = false;
    };
    "com.apple.SoftwareUpdate" = {
      AutomaticCheckEnabled = true;
      ScheduleFrequency = 1;
      AutomaticDownload = 1;
      CriticalUpdateInstall = 0;
    };
    "com.apple.ImageCapture".disableHotPlug = true;
    "com.apple.commerce".AutoUpdate = true;
  };
}
