{ config
, pkgs
, lib
, flake
, remapKeys
, ...
}:

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
          '<dict><key>HIDKeyboardModifierMappingSrc</key><integer>30064771299</integer><key>HIDKeyboardModifierMappingDst</key><integer>30064771298</integer></dict>' \
          '<dict><key>HIDKeyboardModifierMappingSrc</key><integer>30064771298</integer><key>HIDKeyboardModifierMappingDst</key><integer>30064771296</integer></dict>' \
          '<dict><key>HIDKeyboardModifierMappingSrc</key><integer>30064771296</integer><key>HIDKeyboardModifierMappingDst</key><integer>30064771299</integer></dict>' \
          '<dict><key>HIDKeyboardModifierMappingSrc</key><integer>30064771303</integer><key>HIDKeyboardModifierMappingDst</key><integer>30064771302</integer></dict>' \
          '<dict><key>HIDKeyboardModifierMappingSrc</key><integer>30064771302</integer><key>HIDKeyboardModifierMappingDst</key><integer>30064771300</integer></dict>' \
          '<dict><key>HIDKeyboardModifierMappingSrc</key><integer>30064771300</integer><key>HIDKeyboardModifierMappingDst</key><integer>30064771303</integer></dict>'

        # External Logitech MX Keys (046D:B35B → 1133:45915):
        # Ctrl -> Command, Command -> Control (Alt unchanged)
        run /usr/bin/defaults -currentHost write -g com.apple.keyboard.modifiermapping.1133-45915-0 -array \
          '<dict><key>HIDKeyboardModifierMappingSrc</key><integer>30064771296</integer><key>HIDKeyboardModifierMappingDst</key><integer>30064771299</integer></dict>' \
          '<dict><key>HIDKeyboardModifierMappingSrc</key><integer>30064771299</integer><key>HIDKeyboardModifierMappingDst</key><integer>30064771296</integer></dict>' \
          '<dict><key>HIDKeyboardModifierMappingSrc</key><integer>30064771300</integer><key>HIDKeyboardModifierMappingDst</key><integer>30064771303</integer></dict>' \
          '<dict><key>HIDKeyboardModifierMappingSrc</key><integer>30064771303</integer><key>HIDKeyboardModifierMappingDst</key><integer>30064771300</integer></dict>'

        # Clean up stale Cherry keyboard mappings
        run /usr/bin/defaults -currentHost delete -g com.apple.keyboard.modifiermapping.1130-223-0 || true
        run /usr/bin/defaults -currentHost delete -g com.apple.keyboard.modifiermapping.1130-269-0 || true

        # Remove any stale built-in override key.
        run /usr/bin/defaults -currentHost delete -g com.apple.keyboard.modifiermapping.1452-858-0 || true

        run /usr/bin/killall cfprefsd || true
      ''}
    '';
  };
}