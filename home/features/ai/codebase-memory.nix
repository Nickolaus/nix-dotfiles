{ flake, pkgs, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;
  codebaseMemoryMcpPackage = flake.inputs.codebase-memory-mcp.packages.${system}.default;
in
{
  home.packages = [
    codebaseMemoryMcpPackage

    (pkgs.writeShellScriptBin "codebase-memory-status" ''
      set -euo pipefail

      echo "codebase-memory-mcp source: ${flake.inputs.codebase-memory-mcp}"
      echo "codebase-memory-mcp package: ${codebaseMemoryMcpPackage}"
      echo

      package_path="${codebaseMemoryMcpPackage}/bin/codebase-memory-mcp"
      if [ -x "$package_path" ]; then
        echo "  ok      $package_path"
      else
        echo "  missing $package_path"
      fi

      if command -v codebase-memory-mcp >/dev/null 2>&1; then
        echo "  profile $(command -v codebase-memory-mcp)"
      else
        echo "  profile missing: codebase-memory-mcp"
      fi

      echo
      echo "Cache dir: ''${CBM_CACHE_DIR:-$HOME/.cache/codebase-memory-mcp}"
      echo "List indexed projects: codebase-memory-mcp cli list_projects"
    '')
  ];
}
