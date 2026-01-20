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

    # Force paragraph navigation on Meta+Up/Down (Ctrl remapped to Cmd).
    blocked_shortcuts = {
        "meta UP",
        "meta DOWN",
        "shift meta UP",
        "shift meta DOWN",
        "meta alt LEFT",
        "meta alt RIGHT",
        "shift meta alt LEFT",
        "shift meta alt RIGHT",
        "meta 7",
        "shift meta 7",
    }
    for action_id in list(action_shortcuts):
        shortcuts = action_shortcuts[action_id]
        for shortcut in blocked_shortcuts:
            shortcuts.discard(shortcut)
        if not shortcuts:
            del action_shortcuts[action_id]

    forced_shortcuts = {
        "EditorBackwardParagraph": {"meta UP"},
        "EditorForwardParagraph": {"meta DOWN"},
        "EditorBackwardParagraphWithSelection": {"shift meta UP"},
        "EditorForwardParagraphWithSelection": {"shift meta DOWN"},
        "EditorLineStart": {"meta alt LEFT"},
        "EditorLineEnd": {"meta alt RIGHT"},
        "EditorLineStartWithSelection": {"shift meta alt LEFT"},
        "EditorLineEndWithSelection": {"shift meta alt RIGHT"},
        # Force line/block comment shortcuts for DE QWERTZ layouts.
        "CommentByLineComment": {"meta 7"},
        "CommentByBlockComment": {"shift meta 7"},
    }
    for action_id, shortcuts in forced_shortcuts.items():
        action_shortcuts[action_id].update(shortcuts)

    with open(output_path, "w", encoding="utf-8") as out:
        out.write('<keymap version="1" name="WindowsLikeCtrl" parent="Default for XWin">\n')
        for action_id in sorted(action_shortcuts):
            out.write(f'  <action id="{action_id}">\n')
            for shortcut in sorted(action_shortcuts[action_id]):
                out.write(f'    <keyboard-shortcut first-keystroke="{shortcut}" />\n')
            out.write("  </action>\n")
        out.write("</keymap>\n")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
