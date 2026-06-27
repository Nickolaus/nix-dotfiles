{ flake, pkgs, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;
  serenaPackage = flake.inputs.serena.packages.${system}.default;
in
{
  home.packages = [
    serenaPackage

    (pkgs.writeShellScriptBin "serena-status" ''
      set -euo pipefail

      echo "Serena source: ${flake.inputs.serena}"
      echo "Serena package: ${serenaPackage}"
      echo

      for tool in serena serena-hooks; do
        package_path="${serenaPackage}/bin/$tool"
        if [ -x "$package_path" ]; then
          echo "  ok      $package_path"
        else
          echo "  missing $package_path"
        fi

        if command -v "$tool" >/dev/null 2>&1; then
          echo "  profile $(command -v "$tool")"
        else
          echo "  profile missing: $tool"
        fi
      done

      echo
      echo "MCP contexts rendered by aiAgents:"
      echo "  Codex:       serena start-mcp-server --project-from-cwd --context=codex --open-web-dashboard False"
      echo "  Claude Code: serena start-mcp-server --context=claude-code --project-from-cwd --open-web-dashboard False"
      echo "  Cursor:      serena start-mcp-server --context=ide --project-from-cwd --open-web-dashboard False"
      echo
      echo "The dashboard stays enabled for diagnostics, but managed MCP launches do not open a browser tab."
      echo "First-time LSP setup: serena-init-lsp"
      echo "JetBrains backend setup: serena-init-jetbrains"
      echo "Claude launch with Serena prompt override: serena-claude"
    '')

    (pkgs.writeShellScriptBin "serena-init-lsp" ''
      set -euo pipefail

      exec ${serenaPackage}/bin/serena init "$@"
    '')

    (pkgs.writeShellScriptBin "serena-init-jetbrains" ''
      set -euo pipefail

      exec ${serenaPackage}/bin/serena init -b JetBrains "$@"
    '')

    (pkgs.writeShellScriptBin "serena-claude" ''
      set -euo pipefail

      if ! command -v claude >/dev/null 2>&1; then
        echo "claude command not found. Apply the profile that installs claude-code first." >&2
        exit 1
      fi

      prompt="$(${serenaPackage}/bin/serena prompts print-cc-system-prompt-override)"
      exec claude --system-prompt="$prompt" "$@"
    '')
  ];
}
