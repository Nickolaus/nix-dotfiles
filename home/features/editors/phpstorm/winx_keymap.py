import csv
import sys
from collections import defaultdict


def normalize_key(key):
    return key.strip()


def map_modifier(token):
    if token == "ctrl":
        return "meta"
    if token == "meta":
        return "ctrl"
    return token


def mods_from_header(header):
    if header == "":
        return []
    tokens = header.split()
    return [map_modifier(t) for t in tokens]


def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: winx_keymap.py <output_path> <csv_path>", file=sys.stderr)
        return 1

    output_path = sys.argv[1]
    csv_path = sys.argv[2]

    with open(csv_path, newline="") as f:
        reader = csv.DictReader(f)
        headers = reader.fieldnames or []
        rows = list(reader)

    # Step 1: Read CSV and build initial action_shortcuts mapping
    action_shortcuts = defaultdict(set)
    for row in rows:
        key = normalize_key(row.get("key", ""))
        if not key:
            continue
        for header in headers:
            if header == "key":
                continue
            value = (row.get(header) or "").strip()
            if not value:
                continue
            mods = mods_from_header(header)
            first = " ".join(mods + [key]) if mods else key
            for action_id in value.split("|"):
                action_id = action_id.strip()
                if action_id:
                    action_shortcuts[action_id].add(first)

    # Step 2: Bidirectionally swap Alt+0-9 ↔ Cmd+Alt+0-9
    # This frees Alt+0-9 for typing special characters on international keyboards.
    # Tool windows move from Alt+number to Cmd+Alt+number, while their previous
    # Cmd+Alt+number shortcuts move to Alt+number (preserving all functionality).
    shortcut_swaps = [
        ("alt 0", "meta alt 0"),
        ("alt 1", "meta alt 1"),
        ("alt 2", "meta alt 2"),
        ("alt 3", "meta alt 3"),
        ("alt 4", "meta alt 4"),
        ("alt 5", "meta alt 5"),  # Frees Alt+5 for [ on DE keyboard
        ("alt 6", "meta alt 6"),  # Frees Alt+6 for ] on DE keyboard
        ("alt 7", "meta alt 7"),  # Frees Alt+7 for | on DE keyboard
        ("alt 8", "meta alt 8"),  # Frees Alt+8 for { on DE keyboard
        ("alt 9", "meta alt 9"),  # Frees Alt+9 for } on DE keyboard
    ]
    
    for shortcut_a, shortcut_b in shortcut_swaps:
        actions_with_a = {aid for aid, shortcuts in action_shortcuts.items() if shortcut_a in shortcuts}
        actions_with_b = {aid for aid, shortcuts in action_shortcuts.items() if shortcut_b in shortcuts}
        
        for action_id in actions_with_a:
            action_shortcuts[action_id].discard(shortcut_a)
            action_shortcuts[action_id].add(shortcut_b)
        
        for action_id in actions_with_b:
            action_shortcuts[action_id].discard(shortcut_b)
            action_shortcuts[action_id].add(shortcut_a)

    # Step 3: Force specific shortcuts (override CSV definitions)
    # These are essential shortcuts that must work correctly regardless of CSV content.
    forced_shortcuts = {
        # Paragraph navigation (Cmd+Up/Down for moving by paragraph)
        "EditorBackwardParagraph": {"meta UP"},
        "EditorForwardParagraph": {"meta DOWN"},
        "EditorBackwardParagraphWithSelection": {"shift meta UP"},
        "EditorForwardParagraphWithSelection": {"shift meta DOWN"},
        # Line start/end navigation (Cmd+Alt+Left/Right)
        "EditorLineStart": {"meta alt LEFT"},
        "EditorLineEnd": {"meta alt RIGHT"},
        "EditorLineStartWithSelection": {"shift meta alt LEFT"},
        "EditorLineEndWithSelection": {"shift meta alt RIGHT"},
        # Comment shortcuts for QWERTZ keyboards (Cmd+7 for line comment)
        # This overrides the default bookmark 7 shortcuts from CSV
        "CommentByLineComment": {"meta 7"},
        "CommentByBlockComment": {"shift meta 7"},
        # Relocate bookmark 7 shortcuts to avoid conflict with comments
        "GotoBookmark7": {"shift meta alt 7"},  # Cmd+Alt+Shift+7
        "ToggleBookmark7": {"ctrl shift meta alt 7"},  # Ctrl+Cmd+Alt+Shift+7
    }
    
    # Apply forced shortcuts (replacing any existing shortcuts for these actions)
    for action_id, new_shortcuts in forced_shortcuts.items():
        action_shortcuts[action_id] = new_shortcuts.copy()
    
    # Step 4: Clean up empty action entries
    for action_id in list(action_shortcuts):
        if not action_shortcuts[action_id]:
            del action_shortcuts[action_id]

    with open(output_path, "w", encoding="utf-8") as out:
        out.write('<keymap version="1" name="WindowsLikeCtrl" parent="Default for XWin">\n')
        action_mouse_shortcuts = {
            # Ensure Cmd/Ctrl+Click navigation works after modifier remap.
            "GotoDeclaration": {"meta button1"},
            "GotoDeclarationOrUsage": {"meta button1"},
            "GotoTypeDeclaration": {"meta button1"},
            "GotoImplementation": {"meta button2"},
            "ShowUsages": {"shift meta button2"},
        }
        all_action_ids = sorted(set(action_shortcuts) | set(action_mouse_shortcuts))
        for action_id in all_action_ids:
            out.write(f'  <action id="{action_id}">\n')
            for shortcut in sorted(action_shortcuts.get(action_id, set())):
                out.write(f'    <keyboard-shortcut first-keystroke="{shortcut}" />\n')
            for shortcut in sorted(action_mouse_shortcuts.get(action_id, set())):
                out.write(f'    <mouse-shortcut keystroke="{shortcut}" />\n')
            out.write("  </action>\n")
        out.write("</keymap>\n")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
