{ config, lib, osConfig ? { }, pkgs, ... }:

let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.ghidra;

  ghidraSupported = lib.meta.availableOn pkgs.stdenv.hostPlatform pkgs.ghidra;

  aiCfg = if osConfig ? aiAgents then osConfig.aiAgents else null;

  # The stdio launcher declared in hosts/shared/ai-agents.nix: it exports
  # GHIDRA_INSTALL_DIR and JAVA_HOME and pins the Ghidra project directory to
  # an absolute path. ghidra-doctor reuses it instead of re-deriving the same
  # environment, so the probe exercises the launch path the agents actually
  # get. Null on a host that renders no pyghidra-mcp entry.
  mcpCommand =
    if aiCfg != null && aiCfg.mcpServers ? pyghidra-mcp then
      aiCfg.mcpServers.pyghidra-mcp.command
    else
      null;

  ghidraInstallDir = "${cfg.package}/lib/ghidra";

  # analyzeHeadless and pyghidra-mcp each take an exclusive lock on a Ghidra
  # project directory, so they get separate roots. Sharing one would make
  # whichever starts second fail to open the project.
  projectRoot = "$HOME/.local/share/ghidra-headless";

  ghidraInstructions = ''

    ## Ghidra (binary reverse engineering)

    Ghidra is explicit-use tooling for compiled binaries. Reach for it only
    when the artifact is a binary and no source is available.

    Default command surface:
    - `ghidra-status` reports the install, the JVM, and the MCP wiring.
    - `ghidra-analyze <binary>` runs headless analysis into a scoped project
      and prints the log tail, not the full analyzer output.
    - `ghidra-doctor` starts PyGhidra once to verify it can drive the
      read-only Nix install.
    - `ghidra` opens the GUI.

    Boundary rules:
    - Keep codebase-memory, Graphify, and Serena for anything with source:
      repo structure, callers, symbols, and impact questions.
    - Use Ghidra only for decompiling, disassembling, and cross-referencing
      compiled binaries.
    - `pyghidra-mcp` is not natively registered. Reach it through
      `mcp-profile-reverse-engineering`; do not add it to the default profile.
    - Never pipe raw `analyzeHeadless` output into a session. Use
      `ghidra-analyze`, then read the log file it names.
    - Ghidra project databases live under `~/.local/share`. Analysis never
      writes inside a repository working tree, and `rename_*`/`set_*` MCP
      tools mutate the project database, never the analyzed binary.
    - Headless Ghidra runs analyzers and scripts as the local user with no
      sandbox. Decide on isolation before analyzing an untrusted sample;
      Ghidra provides none.
  '';
in
{
  options.ghidra = {
    enable = mkEnableOption "Ghidra reverse engineering tooling" // {
      default = ghidraSupported;
      defaultText = lib.literalExpression "pkgs.ghidra is available on the host platform";
    };

    package = mkOption {
      type = types.package;
      default = pkgs.ghidra;
      defaultText = lib.literalExpression "pkgs.ghidra";
      description = ''
        The Ghidra install both the CLI wrappers and the pyghidra-mcp server
        resolve. Use `pkgs.ghidra.withExtensions` here when a Ghidra Java
        extension is needed; pyghidra-mcp itself needs none.
      '';
    };
  };

  config = mkIf (cfg.enable && ghidraSupported) {
    home.file.".codex/AGENTS.md".text = ghidraInstructions;
    home.file.".vibe/AGENTS.md".text = ghidraInstructions;
    home.file.".claude/CLAUDE.md".text = ghidraInstructions;

    home.packages = [
      cfg.package

      (pkgs.writeShellScriptBin "ghidra-status" ''
        set -euo pipefail

        echo "Ghidra package: ${cfg.package}"
        echo "GHIDRA_INSTALL_DIR: ${ghidraInstallDir}"
        echo "JVM for PyGhidra: ${pkgs.openjdk25} (openjdk ${pkgs.openjdk25.version})"
        echo

        for tool in ghidra ghidra-analyzeHeadless; do
          if [ -x "${cfg.package}/bin/$tool" ]; then
            echo "  ok      ${cfg.package}/bin/$tool"
          else
            echo "  missing ${cfg.package}/bin/$tool"
          fi
        done

        if [ -d "${ghidraInstallDir}" ]; then
          echo "  ok      install dir present"
        else
          echo "  missing install dir ${ghidraInstallDir}"
        fi

        echo
        echo "Headless project root: ${projectRoot}/projects"
        if [ -d "${projectRoot}/projects" ]; then
          count="$(${pkgs.findutils}/bin/find "${projectRoot}/projects" -maxdepth 1 -name '*.gpr' 2>/dev/null | ${pkgs.coreutils}/bin/wc -l | ${pkgs.coreutils}/bin/tr -d ' ')"
          echo "  ok      $count project(s)"
        else
          echo "  empty   created on first ghidra-analyze run"
        fi

        echo
        echo "MCP:"
        ${
          if mcpCommand == null then ''
            echo "  missing no pyghidra-mcp entry rendered for this host"
          '' else ''
            echo "  ok      ${mcpCommand}"
            echo "  transport stdio, not natively registered (targets = [ ])"
            echo "  reachable via: mcp-profile-reverse-engineering"
            echo '  project root: $XDG_DATA_HOME/pyghidra-mcp/projects (separate lock from the CLI root)'
          ''
        }

        echo
        echo "Boundary: source-level questions belong to codebase-memory, Graphify, or Serena."
        echo "Use Ghidra only for compiled binaries with no source."
        echo
        echo "Verify PyGhidra against the read-only Nix install: ghidra-doctor"
      '')

      (pkgs.writeShellScriptBin "ghidra-analyze" ''
        set -euo pipefail

        if [ "$#" -lt 1 ]; then
          echo "usage: ghidra-analyze <binary> [extra analyzeHeadless args...]" >&2
          exit 2
        fi

        binary="$1"
        shift

        if [ ! -f "$binary" ]; then
          echo "ghidra-analyze: no such file: $binary" >&2
          exit 1
        fi

        project_dir="${projectRoot}/projects"
        log_dir="${projectRoot}/logs"
        ${pkgs.coreutils}/bin/mkdir -p "$project_dir" "$log_dir"

        name="$(${pkgs.coreutils}/bin/basename "$binary" | ${pkgs.coreutils}/bin/tr -c 'A-Za-z0-9_.-' '-')"

        # An existing project is never silently replaced: analyzeHeadless
        # -overwrite discards a previous analysis, including any renames and
        # comments an earlier session wrote. The caller has to ask for it.
        if [ -e "$project_dir/$name.gpr" ]; then
          case " $* " in
            *" -overwrite "*) ;;
            *)
              echo "ghidra-analyze: project '$name' already exists at $project_dir/$name.gpr" >&2
              echo "Re-run with -overwrite to discard that analysis, or delete the project first." >&2
              exit 1
              ;;
          esac
        fi

        log="$log_dir/$name-$(${pkgs.coreutils}/bin/date +%Y%m%dT%H%M%S).log"

        set +e
        "${cfg.package}/bin/ghidra-analyzeHeadless" \
          "$project_dir" "$name" \
          -import "$binary" \
          "$@" >"$log" 2>&1
        status=$?
        set -e

        echo "project: $project_dir/$name.gpr"
        echo "log:     $log"
        echo

        if [ "$status" -ne 0 ]; then
          echo "analyzeHeadless failed (exit $status). Last 20 log lines:" >&2
          ${pkgs.coreutils}/bin/tail -n 20 "$log" >&2
          exit "$status"
        fi

        ${pkgs.gnugrep}/bin/grep -E 'ERROR|WARN|Packed Database|Analysis succeeded' "$log" \
          | ${pkgs.coreutils}/bin/tail -n 15 \
          || ${pkgs.coreutils}/bin/tail -n 5 "$log"
      '')

      (pkgs.writeShellScriptBin "ghidra-doctor" ''
        set -euo pipefail

        ${
          if mcpCommand == null then ''
            echo "No pyghidra-mcp entry is rendered for this host; nothing to probe." >&2
            exit 1
          '' else ''
            echo "Starting PyGhidra through ${mcpCommand} ..."
            echo "First run resolves the uvx environment and boots a JVM; allow a few minutes."
            echo

            # --list-project-binaries makes the server do its full PyGhidra
            # startup against the read-only /nix/store install and then exit,
            # which is exactly the step that fails if Ghidra wants to create
            # lock files next to its own install directory.
            if ${pkgs.coreutils}/bin/timeout 600 ${mcpCommand} --list-project-binaries </dev/null; then
              echo
              echo "ok      PyGhidra started against the Nix install and exited cleanly."
            else
              status=$?
              echo
              echo "failed  PyGhidra could not start (exit $status)." >&2
              echo "If the error names a lock file or a read-only path under /nix/store," >&2
              echo "set ghidra.package to a writable Ghidra install." >&2
              exit "$status"
            fi
          ''
        }
      '')
    ];
  };
}
