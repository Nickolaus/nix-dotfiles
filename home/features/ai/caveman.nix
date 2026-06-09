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
  codexSkillFiles = builtins.listToAttrs (map
    (skill: {
      name = ".codex/skills/${skill}";
      value = {
        source = cavemanSrc + "/skills/${skill}";
        recursive = true;
      };
    })
    cavemanSkills);
  node = "${pkgs.nodejs}/bin/node";
  installer = "${cavemanSrc}/bin/install.js";
in
{
  home.file = codexSkillFiles;

  home.packages = [
    (pkgs.writeShellScriptBin "caveman-status" ''
      set -euo pipefail

      echo "Caveman source: ${cavemanSrc}"
      echo "Codex skills:"
      for skill in ${builtins.concatStringsSep " " cavemanSkills}; do
        skill_path="$HOME/.codex/skills/$skill/SKILL.md"
        if [ -f "$skill_path" ]; then
          echo "  ok      $skill_path"
        else
          echo "  missing $skill_path"
        fi
      done
      echo
      echo "Codex usage: start a session and run /caveman, /caveman lite, or /caveman ultra."
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
