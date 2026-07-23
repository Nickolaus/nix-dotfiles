{ config
, pkgs
, lib
, flake
, remapKeys
, ...
}:

let
  hid = {
    capsLock = "30064771129";
    leftControl = "30064771296";
    leftOption = "30064771298";
    leftCommand = "30064771299";
    rightControl = "30064771300";
    rightOption = "30064771302";
    rightCommand = "30064771303";
  };

  modifierPair = src: dst:
    "'<dict><key>HIDKeyboardModifierMappingSrc</key><integer>${src}</integer><key>HIDKeyboardModifierMappingDst</key><integer>${dst}</integer></dict>'";

  modifierArgs = pairs:
    lib.concatStringsSep " \\\n          " (map ({ src, dst }: modifierPair src dst) pairs);

  pair = src: dst: { inherit src dst; };

  builtInCycleMapping = [
    (pair hid.leftCommand hid.leftOption)
    (pair hid.leftOption hid.leftControl)
    (pair hid.leftControl hid.leftCommand)
    (pair hid.rightCommand hid.rightOption)
    (pair hid.rightOption hid.rightControl)
    (pair hid.rightControl hid.rightCommand)
  ];

  externalPcKeyboardMapping = [
    (pair hid.leftControl hid.leftCommand)
    (pair hid.leftCommand hid.leftControl)
    (pair hid.rightControl hid.rightCommand)
    (pair hid.rightCommand hid.rightControl)
  ];

  mxKeysMapping = [
    (pair hid.capsLock hid.capsLock)
  ] ++ externalPcKeyboardMapping;
in
{
  imports = [
    ./hammerspoon
  ];

  home.activation = lib.mkIf pkgs.stdenv.isDarwin {
    copyKeyBindings = lib.hm.dag.entryAfter ["writeBoundary"] ''
        run  cp -f ${./DefaultKeyBinding.dict} ~/Library/KeyBindings/DefaultKeyBinding.dict
    '';
    keyboardModifierMapping = lib.hm.dag.entryAfter ["writeBoundary"] ''
      ${lib.optionalString remapKeys ''
        # All keyboards default (0:0):
        # 3-cycle for built-in layout: Command -> Option, Option -> Control, Control -> Command
        run /usr/bin/defaults -currentHost write -g com.apple.keyboard.modifiermapping.0-0-0 -array \
          ${modifierArgs builtInCycleMapping}

        # Home-office CHERRY keyboard (046A:00DF -> 1130:223):
        # Ctrl -> Command, Command -> Control (Alt unchanged)
        run /usr/bin/defaults -currentHost write -g com.apple.keyboard.modifiermapping.1130-223-0 -array \
          ${modifierArgs externalPcKeyboardMapping}

        # Office Logitech MX Keys (046D:B35B -> 1133:45915):
        # Caps Lock stays Caps Lock. Ctrl -> Command, Command -> Control (Alt/Option unchanged).
        run /usr/bin/defaults -currentHost write -g com.apple.keyboard.modifiermapping.1133-45915-0 -array \
          ${modifierArgs mxKeysMapping}

        # Remove any stale built-in override key.
        run /usr/bin/defaults -currentHost delete -g com.apple.keyboard.modifiermapping.1452-858-0 || true

        run /usr/bin/killall cfprefsd || true
      ''}
    '';
  };
}
