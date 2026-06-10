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
in
{
  home.file = codexSkillDirs;

  home.packages = [
    (pkgs.writeShellScriptBin "caveman-status" ''
      set -euo pipefail

      echo "Caveman source: ${cavemanSrc}"
      echo "Codex user skills:"
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
      echo "Codex usage: start a new session, run /skills, and select caveman."
      echo "Plain prompts also work: 'use caveman mode', 'talk like caveman', or 'stop caveman'."
      echo "Note: /caveman is a Caveman upstream slash-command convention, but current Codex CLI only exposes installed skills through /skills."
      echo "Claude setup is explicit: caveman-claude-install-minimal or caveman-claude-install-full."
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
