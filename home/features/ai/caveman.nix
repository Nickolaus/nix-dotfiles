{ flake, pkgs, ... }:
let
  cavemanSrc = flake.inputs.caveman;
  cavemanSkills = [
    "caveman"
    "caveman-commit"
    "caveman-review"
    "caveman-compress"
    "caveman-help"
    "caveman-stats"
    "cavecrew"
  ];
  codexSkillDirs = builtins.listToAttrs (map
    (skill: {
      name = ".agents/skills/${skill}";
      value = {
        source = cavemanSrc + "/skills/${skill}";
      };
    })
    cavemanSkills);
  node = "${pkgs.nodejs}/bin/node";
  installer = "${cavemanSrc}/bin/install.js";

  # Single point of truth: the pinned `caveman` flake input's own SKILL.md is
  # embedded verbatim (not hand-paraphrased), so bumping the flake input is
  # the only thing ever needed to keep this in sync -- no separate prose to
  # drift out of date. The only thing we add on top is a short preamble,
  # since skill-based activation still needs *something* to trigger it
  # without the user typing a trigger phrase; the file's own content (it
  # already documents "Default: full" / "ACTIVE EVERY RESPONSE") does the
  # rest. Codex/Vibe read this from their global AGENTS.md; Claude Code reads
  # the equivalent from CLAUDE.md. None of these mutate app-owned
  # settings/MCP state, so -- unlike the Claude plugin/hook install below --
  # they're safe to enable unconditionally.
  cavemanSkillFile = cavemanSrc + "/skills/caveman/SKILL.md";
  cavemanDefaultInstructions = ''
    This skill activates by default at the start of every session -- no trigger
    phrase needed. What follows is the pinned caveman skill definition itself,
    verbatim from ${cavemanSkillFile}, which governs style, intensity, and when
    to drop it for the rest of the session.

    ${builtins.readFile cavemanSkillFile}
  '';
in
{
  home.file = codexSkillDirs // {
    ".codex/AGENTS.md".text = cavemanDefaultInstructions;
    ".vibe/AGENTS.md".text = cavemanDefaultInstructions;
    ".claude/CLAUDE.md".text = cavemanDefaultInstructions;
  };

  home.packages = [
    (pkgs.writeShellScriptBin "caveman-status" ''
      set -euo pipefail

      echo "Caveman source: ${cavemanSrc}"
      echo "Codex user skills (also read by Vibe -- both follow the Agent Skills spec at ~/.agents/skills/):"
      for skill in ${builtins.concatStringsSep " " cavemanSkills}; do
        skill_path="$HOME/.agents/skills/$skill/SKILL.md"
        if [ -f "$skill_path" ]; then
          echo "  ok      $skill_path"
        else
          echo "  missing $skill_path"
        fi
      done
      echo
      legacy_path="$HOME/.codex/skills/caveman/SKILL.md"
      if [ -e "$legacy_path" ]; then
        echo "Legacy path still exists: $legacy_path"
        echo "Current Codex user skills are loaded from ~/.agents/skills."
        echo
      fi
      echo
      echo "Full-intensity caveman style is ON BY DEFAULT for Codex, Vibe, and Claude Code --"
      echo "each reads it from its own global instructions file (content is the pinned"
      echo "SKILL.md embedded verbatim, single source of truth, not a hand-copied paraphrase):"
      for f in "$HOME/.codex/AGENTS.md" "$HOME/.vibe/AGENTS.md" "$HOME/.claude/CLAUDE.md"; do
        if [ -f "$f" ]; then
          echo "  ok      $f"
        else
          echo "  missing $f"
        fi
      done
      echo "Source: ${cavemanSkillFile}"
      echo "Say 'stop caveman' or 'normal mode' to turn it off for the rest of a session; it"
      echo "resumes next session (it's a default, not a one-time toggle). Switch intensity with"
      echo "'/caveman lite|full|ultra' (Codex/Vibe skill invocation) or by asking in plain language."
      echo
      echo "Claude's caveman *skill/plugin* install (beyond the default CLAUDE.md style above) is"
      echo "still explicit, since it mutates Claude-managed plugin/hook state:"
      echo "caveman-claude-install-minimal or caveman-claude-install-full."
    '')

    (pkgs.writeShellScriptBin "caveman-upstream-dry-run" ''
      set -euo pipefail

      exec ${node} ${installer} --dry-run --minimal --no-mcp-shrink "$@"
    '')

    (pkgs.writeShellScriptBin "caveman-claude-install-minimal" ''
      set -euo pipefail

      if ! command -v claude >/dev/null 2>&1; then
        echo "claude command not found. Apply the profile that installs claude-code first." >&2
        exit 1
      fi

      exec ${node} ${installer} --only claude --minimal --no-mcp-shrink --non-interactive "$@"
    '')

    (pkgs.writeShellScriptBin "caveman-claude-install-full" ''
      set -euo pipefail

      if ! command -v claude >/dev/null 2>&1; then
        echo "claude command not found. Apply the profile that installs claude-code first." >&2
        exit 1
      fi

      exec ${node} ${installer} --only claude --with-hooks --no-mcp-shrink --non-interactive "$@"
    '')
  ];
}
