{ ... }: {
  home.file."Library/Application Support/Cursor/User/keybindings.json".text = ''
    // Minimal overrides for Windows-like navigation on a Cmd-remapped Ctrl.
    [
      // Double Shift for Command Palette (Search Everywhere equivalent).
      {
        "key": "shift shift",
        "command": "workbench.action.showCommands"
      },
      // Word jump/select on physical Ctrl+Left/Right (logical Cmd+Left/Right).
      {
        "key": "cmd+left",
        "command": "cursorWordLeft",
        "when": "editorTextFocus"
      },
      {
        "key": "cmd+right",
        "command": "cursorWordRight",
        "when": "editorTextFocus"
      },
      {
        "key": "cmd+shift+left",
        "command": "cursorWordLeftSelect",
        "when": "editorTextFocus"
      },
      {
        "key": "cmd+shift+right",
        "command": "cursorWordRightSelect",
        "when": "editorTextFocus"
      },
      // Paragraph jump/select on physical Ctrl+Up/Down (logical Cmd+Up/Down).
      {
        "key": "cmd+up",
        "command": "cursorMove",
        "args": { "to": "up", "by": "paragraph", "value": 1 },
        "when": "editorTextFocus"
      },
      {
        "key": "cmd+down",
        "command": "cursorMove",
        "args": { "to": "down", "by": "paragraph", "value": 1 },
        "when": "editorTextFocus"
      },
      {
        "key": "cmd+shift+up",
        "command": "cursorMove",
        "args": { "to": "up", "by": "paragraph", "value": 1, "select": true },
        "when": "editorTextFocus"
      },
      {
        "key": "cmd+shift+down",
        "command": "cursorMove",
        "args": { "to": "down", "by": "paragraph", "value": 1, "select": true },
        "when": "editorTextFocus"
      },
      // Delete word on physical Ctrl+Backspace/Delete (logical Cmd+Backspace/Delete).
      {
        "key": "cmd+backspace",
        "command": "deleteWordLeft",
        "when": "editorTextFocus"
      },
      {
        "key": "cmd+delete",
        "command": "deleteWordRight",
        "when": "editorTextFocus"
      }
    ]
  '';
}
