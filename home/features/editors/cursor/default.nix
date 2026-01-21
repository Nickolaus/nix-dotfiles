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
      // Line start/end on physical Ctrl+Alt+Left/Right (logical Cmd+Alt+Left/Right).
      {
        "key": "cmd+alt+left",
        "command": "-workbench.action.navigateBack",
        "when": "editorTextFocus"
      },
      {
        "key": "cmd+alt+right",
        "command": "-workbench.action.navigateForward",
        "when": "editorTextFocus"
      },
      {
        "key": "cmd+alt+left",
        "command": "cursorHome",
        "when": "editorTextFocus"
      },
      {
        "key": "cmd+alt+right",
        "command": "cursorEnd",
        "when": "editorTextFocus"
      },
      {
        "key": "cmd+alt+shift+left",
        "command": "cursorHomeSelect",
        "when": "editorTextFocus"
      },
      {
        "key": "cmd+alt+shift+right",
        "command": "cursorEndSelect",
        "when": "editorTextFocus"
      },
      // Document start/end on physical Ctrl+Alt+Up/Down (logical Cmd+Alt+Up/Down).
      {
        "key": "cmd+alt+up",
        "command": "cursorTop",
        "when": "editorTextFocus"
      },
      {
        "key": "cmd+alt+down",
        "command": "cursorBottom",
        "when": "editorTextFocus"
      },
      {
        "key": "cmd+alt+shift+up",
        "command": "cursorTopSelect",
        "when": "editorTextFocus"
      },
      {
        "key": "cmd+alt+shift+down",
        "command": "cursorBottomSelect",
        "when": "editorTextFocus"
      },
      // Expand/shrink selection on physical Ctrl+W / Ctrl+Shift+W.
      {
        "key": "cmd+w",
        "command": "-workbench.action.closeActiveEditor",
        "when": "editorTextFocus"
      },
      {
        "key": "cmd+w",
        "command": "editor.action.smartSelect.expand",
        "when": "editorTextFocus"
      },
      {
        "key": "cmd+shift+w",
        "command": "editor.action.smartSelect.shrink",
        "when": "editorTextFocus"
      },
      // Line/block comment on DE QWERTZ Ctrl+7 / Ctrl+Shift+7.
      {
        "key": "cmd+7",
        "command": "editor.action.commentLine",
        "when": "editorTextFocus && !editorReadonly"
      },
      {
        "key": "cmd+shift+7",
        "command": "editor.action.blockComment",
        "when": "editorTextFocus && !editorReadonly"
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
