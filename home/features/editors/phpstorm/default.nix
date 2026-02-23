{ pkgs, lib, ... }:
let
  keymapXml = ''
    <keymap version="1" name="WindowsLikeCtrl" parent="Default for XWin" />
  '';
  keymapOptionsXml = ''
    <application>
      <component name="KeymapManager">
        <active_keymap name="WindowsLikeCtrl" />
      </component>
    </application>
  '';
  keymapFile = pkgs.writeText "WindowsLikeCtrl.xml" keymapXml;
  keymapOptionsFile = pkgs.writeText "keymap.xml" keymapOptionsXml;
in
lib.mkIf pkgs.stdenv.isDarwin {
  # Apply to all installed PhpStorm versions without pinning a directory.
  home.activation.phpstormKeymap = lib.hm.dag.entryAfter ["writeBoundary"] ''
    for dir in "$HOME/Library/Application Support/JetBrains"/PhpStorm*/; do
      test -d "$dir" || continue
      # Skip read-only or legacy folders.
      if ! /bin/test -w "$dir"; then
        continue
      fi
      run /bin/mkdir -p "$dir/keymaps" "$dir/options"
      if ! /bin/test -w "$dir/keymaps"; then
        continue
      fi
      # Ensure we can overwrite the generated keymap file.
      if [ -f "$dir/keymaps/WindowsLikeCtrl.xml" ]; then
        run /bin/chmod u+w "$dir/keymaps/WindowsLikeCtrl.xml" || true
      fi
      # Generate a Windows-like keymap by translating XWin Ctrl->Cmd.
      csv_path="${./winx_keymap.csv}"
      xwin_jar="$dir/plugins/XWinKeymap/lib/XWinKeymap.jar"
      if [ -f "$csv_path" ]; then
        run /usr/bin/python3 ${./winx_keymap.py} "$dir/keymaps/WindowsLikeCtrl.xml" "$csv_path"
      elif [ -f "$xwin_jar" ]; then
        run /bin/sh -c "/usr/bin/unzip -p \"$xwin_jar\" \"Default for XWin.xml\" | /usr/bin/python3 - <<'PY' > \"$dir/keymaps/WindowsLikeCtrl.xml\"\nimport re, sys\ntext = sys.stdin.read()\ntext = re.sub(r'name=\"[^\"]+\"', 'name=\"WindowsLikeCtrl\"', text, count=1)\n\ndef convert_keystroke(match):\n    keys = match.group(1).split()\n    keys = ['meta' if k == 'ctrl' else ('ctrl' if k == 'meta' else k) for k in keys]\n    return f'{match.group(0)[:match.group(0).find(\"=\")]}=\"{\" \".join(keys)}\"'\n\ntext = re.sub(r'first-keystroke=\"([^\"]+)\"', convert_keystroke, text)\ntext = re.sub(r'second-keystroke=\"([^\"]+)\"', convert_keystroke, text)\nprint(text)\nPY"
      else
        run /bin/cp -f ${keymapFile} "$dir/keymaps/WindowsLikeCtrl.xml"
      fi
      # Force WindowsLikeCtrl as the active keymap (mac and global options).
      run /bin/mkdir -p "$dir/options/mac"
      run /bin/cp -f ${keymapOptionsFile} "$dir/options/keymap.xml"
      run /bin/cp -f ${keymapOptionsFile} "$dir/options/mac/keymap.xml"

      # Force word navigation to treat camelCase as one word (no camel-humps).
      editor_xml="$dir/options/editor.xml"
      if [ -f "$editor_xml" ]; then
        if /usr/bin/grep -q 'name="IS_CAMEL_WORDS"' "$editor_xml"; then
          run /usr/bin/perl -0pi -e 's/name="IS_CAMEL_WORDS" value="true"/name="IS_CAMEL_WORDS" value="false"/g' "$editor_xml"
        elif /usr/bin/grep -q '<component name="EditorSettings">' "$editor_xml"; then
          run /usr/bin/perl -0pi -e 's|(<component name="EditorSettings">)|$1\n    <option name="IS_CAMEL_WORDS" value="false" />|' "$editor_xml"
        else
          run /usr/bin/perl -0pi -e 's|</application>|  <component name="EditorSettings">\n    <option name="IS_CAMEL_WORDS" value="false" />\n  </component>\n</application>|' "$editor_xml"
        fi
      else
        run /bin/sh -c "/bin/cat > \"$editor_xml\" << 'EOF'
<application>
  <component name=\"EditorSettings\">
    <option name=\"IS_CAMEL_WORDS\" value=\"false\" />
  </component>
</application>
EOF"
      fi
      # Enable JetBrains internal mode for keymap debugging tools.
      custom_props="$dir/idea.properties"
      if [ -f "$custom_props" ]; then
        if ! /usr/bin/grep -q '^idea\.is\.internal=true$' "$custom_props"; then
          run /bin/sh -c "/usr/bin/printf '\nidea.is.internal=true\n' >> \"$custom_props\""
        fi
      else
        run /bin/sh -c "/usr/bin/printf 'idea.is.internal=true\n' > \"$custom_props\""
      fi
    done
  '';
}
