{ config, lib, pkgs, ... }:
let
  inherit (lib) escapeShellArg mkOption types;

  aiAgentsLib = import ../../../hosts/shared/ai-agents-lib.nix { inherit lib pkgs; };

  cfg = config.rtk;

  claudeSettingsFile = "${config.home.homeDirectory}/.claude/settings.json";
  cursorHooksFile = "${config.home.homeDirectory}/.cursor/hooks.json";
  rtkConfigDir =
    if pkgs.stdenv.hostPlatform.isDarwin then
      "${config.home.homeDirectory}/Library/Application Support/rtk"
    else
      "${config.xdg.configHome}/rtk";
  rtkConfigFile = "${rtkConfigDir}/config.toml";
  rtkHistoryDbFile = "${cfg.sharedStateDir}/history.db";
  rtkTeeDir = "${cfg.sharedStateDir}/tee";

  # Home Manager's activation script hardcodes a minimal PATH (coreutils/jq/etc. plus
  # whatever directory the default Nix profile's `nix-env` resolves to) for its entire
  # run -- confirmed directly that this never includes nix-darwin's per-user system
  # profile directory, which is where `claude` actually lives on this machine. Without
  # this, `command -v claude` fails silently in every activation script regardless of
  # DAG ordering, not just this one -- same fix already established for launchd-facing
  # scripts elsewhere (ollama.nix/headroom.nix's `launchdPath`).
  perUserSystemProfileBin = "/etc/profiles/per-user/${config.home.username}/bin";

  # Contributed to the same global-instructions files caveman.nix/codebase-memory.nix
  # already write to (home.file merges these via Home Manager's types.lines
  # string-concat -- no shared registry needed, each module just owns its own
  # section). Hand-written, not byte-copied from rtk's own generated RTK.md/AGENTS.md
  # templates, so this repo's content doesn't drift out of sync with rtk's internal
  # template format across version bumps.
  rtkInstructionsFor = agent:
    let
      agentParagraph = {
        claude = ''
          Once the hook is installed (on by default -- see `rtk-status`), every Bash
          command Claude Code runs is transparently rewritten through `rtk` first --
          no behavior change needed from you.
        '';
        codex = ''
          Codex rewrites simple Bash calls through a managed `PreToolUse` hook here
          (on by default -- see `rtk-status`), but hook coverage is incomplete:
          non-Bash tools, `WebSearch`, and some richer shell paths still bypass it.
          Use explicit `rtk <cmd>` when you need RTK filtering and the hook does not fire.
        '';
        vibe = ''
          Vibe has no native rtk integration at all (not in rtk's own supported-agent
          list). Prefix commands yourself, e.g. `rtk cargo test` instead of `cargo test`,
          to get the same output compression.
        '';
      }.${agent};
    in
    ''

      ## rtk (dev-tool output compression, stateless CLI, not an MCP server)

      `rtk` wraps common dev-tool subcommands (git, cargo, npm, pytest, docker, kubectl,
      and ~60 others) and filters/compresses their output before it reaches you,
      typically cutting 60-90% of the tokens those commands would otherwise cost. It
      opens no ports and runs no background process -- every invocation is a one-shot
      CLI call that exits immediately.

      ${agentParagraph}
      Savings summary: `rtk gain`.
    '';

  # Captured verbatim from a real `rtk init --global --opencode --dry-run` run against
  # rtk 0.43.0 (re-capture if the pinned rtk version changes materially). Safe to embed
  # as a static file unlike the Claude/Cursor hook JSON: this plugin's own header states
  # it's a thin delegating shim -- "all rewrite logic lives in `rtk rewrite`" -- so its
  # content doesn't go stale as rtk's own rewrite rules evolve between versions. No
  # existing writer of this path in this repo, so a plain home.file is enough; no
  # mkJsonMergeActivation needed since this isn't a shared-key merge, it's a whole file.
  opencodePluginContent = ''
    import type { Plugin } from "@opencode-ai/plugin"

    // RTK OpenCode plugin — rewrites commands to use rtk for token savings.
    // Requires: rtk >= 0.23.0 in PATH.
    //
    // This is a thin delegating plugin: all rewrite logic lives in `rtk rewrite`,
    // which is the single source of truth (src/discover/registry.rs).
    // To add or change rewrite rules, edit the Rust registry — not this file.

    export const RtkOpenCodePlugin: Plugin = async ({ $ }) => {
      try {
        await $`which rtk`.quiet()
      } catch {
        console.warn("[rtk] rtk binary not found in PATH — plugin disabled")
        return {}
      }

      return {
        "tool.execute.before": async (input, output) => {
          const tool = String(input?.tool ?? "").toLowerCase()
          if (tool !== "bash" && tool !== "shell") return
          const args = output?.args
          if (!args || typeof args !== "object") return

          const command = (args as Record<string, unknown>).command
          if (typeof command !== "string" || !command) return

          try {
            const result = await $`rtk rewrite ''${command}`.quiet().nothrow()
            const rewritten = String(result.stdout).trim()
            if (rewritten && rewritten !== command) {
              ;(args as Record<string, unknown>).command = rewritten
            }
          } catch {
            // rtk rewrite failed — pass through unchanged
          }
        },
      }
    }
  '';
in
{
  options.rtk = {
    sharedStateDir = mkOption {
      type = types.str;
      default =
        if pkgs.stdenv.hostPlatform.isDarwin then
          "/private/tmp/${config.home.username}/rtk"
        else
          "${config.xdg.stateHome}/rtk";
      description = ''
        Shared RTK runtime state directory used by every agent via
        `tracking.database_path` and `tee.directory` in RTK's own config.
        Darwin defaults to `/private/tmp/$USER/rtk` because Codex's sandbox
        cannot write RTK's upstream default `~/Library/Application Support/rtk`
        data directory, while Claude/Cursor/Vibe can still use the same tmp
        path without special handling.
      '';
    };

    claudeHook.enable = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Install rtk's PreToolUse hook into Claude Code (transparent command
        compression, via `rtk init --global --auto-patch --hook-only`).
        Self-cleaning: this activation script always runs, and disabling this
        removes exactly rtk's own `hooks.PreToolUse` entry from
        ~/.claude/settings.json, leaving every other entry (Orca's, caveman's,
        anything else) untouched. `--hook-only` is required, not optional: a
        plain `rtk init --auto-patch` also tries to append to ~/.claude/CLAUDE.md
        and ~/.claude/RTK.md, both of which are Nix-managed read-only symlinks
        here (caveman.nix/codebase-memory.nix) -- confirmed that fails hard with
        "Permission denied" and aborts before even reaching the settings.json
        patch. `--hook-only` skips CLAUDE.md/RTK.md entirely.
      '';
    };

    cursorHook.enable = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Install rtk's preToolUse hook into Cursor (~/.cursor/hooks.json), via
        `rtk init --global --agent cursor --auto-patch --hook-only`. Self-cleaning
        like claudeHook.enable above. Note: rtk's own `--agent cursor` is additive
        to its default Claude target, not exclusive -- confirmed even with `claude`
        entirely absent from PATH that this still unconditionally ensures Claude's
        hook is present too, regardless of claudeHook.enable's own value. This is
        upstream rtk behavior, not something this module can separate.
      '';
    };
  };

  config = {
    home.packages = [
      pkgs.rtk

      (pkgs.writeShellScriptBin "rtk-status" ''
        set -euo pipefail

        rtk_bin="${pkgs.rtk}/bin/rtk"
        echo "rtk package: ${pkgs.rtk}"
        if [ -x "$rtk_bin" ]; then
          echo "  ok      $rtk_bin"
          "$rtk_bin" --version 2>/dev/null | sed 's/^/  version /'
        else
          echo "  missing $rtk_bin"
        fi
        echo
        echo "RTK config: ${rtkConfigFile}"
        echo "RTK state:  ${cfg.sharedStateDir}"
        echo "RTK DB:     ${rtkHistoryDbFile}"
        echo "RTK tee:    ${rtkTeeDir}"
        echo

        settings=${lib.escapeShellArg claudeSettingsFile}
        if [ -f "$settings" ] && ${pkgs.jq}/bin/jq -e \
            '.hooks.PreToolUse[]?.hooks[]? | select(.command == "rtk hook claude")' \
            "$settings" >/dev/null 2>&1; then
          echo "Claude Code hook: installed (rtk hook claude, in $settings)"
        else
          echo "Claude Code hook: not installed (rtk.claudeHook.enable is currently false, or Claude Code isn't installed yet)"
        fi
        echo

        cursor_hooks=${lib.escapeShellArg cursorHooksFile}
        if [ -f "$cursor_hooks" ] && ${pkgs.jq}/bin/jq -e \
            '.hooks.preToolUse[]? | select(.command == "rtk hook cursor")' \
            "$cursor_hooks" >/dev/null 2>&1; then
          echo "Cursor hook: installed (rtk hook cursor, in $cursor_hooks)"
        else
          echo "Cursor hook: not installed (rtk.cursorHook.enable is currently false, or Cursor isn't installed yet)"
        fi
        echo

        opencode_plugin="$HOME/.config/opencode/plugins/rtk.ts"
        if [ -f "$opencode_plugin" ]; then
          echo "OpenCode plugin: ok      $opencode_plugin (Nix-managed, always present)"
        else
          echo "OpenCode plugin: missing $opencode_plugin"
        fi
        echo

        codex_requirements="/etc/codex/requirements.toml"
        if [ -f "$codex_requirements" ] && ${pkgs.gnugrep}/bin/grep -q 'rtk-pretool.py' "$codex_requirements"; then
          echo "Codex hook: installed   (managed PreToolUse rewrite via $codex_requirements)"
        else
          echo "Codex hook: missing     (no managed PreToolUse rewrite found)"
        fi
        echo "Codex hook scope: simple Bash calls only; non-Bash tools, WebSearch, and some"
        echo "richer shell paths still need explicit 'rtk <cmd>'."
        echo
        echo "Vibe: no native rtk integration -- use explicit 'rtk <cmd>' there."
        echo

        echo "rtk is a stateless CLI -- no port, no daemon, no launchd agent; nothing to"
        echo "pause/resume the way Headroom's proxies have."
        echo

        if [ -x "$rtk_bin" ]; then
          echo "Savings summary (rtk gain):"
          gain_err="$(mktemp)"
          if "$rtk_bin" gain >"$gain_err.out" 2>"$gain_err"; then
            sed 's/^/  /' "$gain_err.out"
          else
            echo "  rtk gain failed:"
            sed 's/^/    /' "$gain_err"
          fi
          rm -f "$gain_err" "$gain_err.out"
        fi
      '')
    ];

    home.file = {
      ".codex/AGENTS.md".text = rtkInstructionsFor "codex";
      ".vibe/AGENTS.md".text = rtkInstructionsFor "vibe";
      ".claude/CLAUDE.md".text = rtkInstructionsFor "claude";
      ".config/opencode/plugins/rtk.ts".text = opencodePluginContent;
    };

    # Self-cleaning, default-on (opt-out) activation for the Claude hook -- mirrors the
    # hosts/shared/claude-code.nix pattern from earlier this session: the script always
    # runs on every switch and converges to whatever claudeHook.enable currently says,
    # in either direction, rather than being a one-shot manual install with no undo path.
    home.activation.rtkConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      config_file=${escapeShellArg rtkConfigFile}
      state_dir=${escapeShellArg cfg.sharedStateDir}
      tee_dir=${escapeShellArg rtkTeeDir}
      db_file=${escapeShellArg rtkHistoryDbFile}

      mkdir -p "$(dirname "$config_file")" "$state_dir" "$tee_dir"

      if [ ! -f "$config_file" ]; then
        printf '%s\n' "" > "$config_file"
      fi

      if ${aiAgentsLib.tomlkitPython}/bin/python3 - "$config_file" "$db_file" "$tee_dir" <<'PY'
import pathlib
import sys
import tomlkit

config_path = pathlib.Path(sys.argv[1])
db_file = sys.argv[2]
tee_dir = sys.argv[3]

try:
    content = config_path.read_text() if config_path.exists() else ""
    doc = tomlkit.parse(content) if content.strip() else tomlkit.document()
except Exception as exc:
    print(f"warning: {config_path} is not valid TOML; skipping RTK config merge ({exc})", file=sys.stderr)
    raise SystemExit(1)

tracking = doc.get("tracking")
if not isinstance(tracking, tomlkit.items.Table):
    tracking = tomlkit.table()
doc["tracking"] = tracking
tracking["database_path"] = db_file

tee = doc.get("tee")
if not isinstance(tee, tomlkit.items.Table):
    tee = tomlkit.table()
doc["tee"] = tee
tee["directory"] = tee_dir

config_path.write_text(tomlkit.dumps(doc))
PY
      then
        :
      else
        true
      fi
    '';

    home.activation.rtkClaudeHook = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      PATH="${perUserSystemProfileBin}:$PATH"
      if command -v claude >/dev/null 2>&1; then
        ${if cfg.claudeHook.enable then ''
          ${pkgs.rtk}/bin/rtk init --global --auto-patch --hook-only || true
        '' else
          aiAgentsLib.mkJsonArrayEntryRemoval {
            configPath = claudeSettingsFile;
            arrayPath = ".hooks.PreToolUse";
            predicate = ''.hooks[0].command != "rtk hook claude"'';
            invalidJsonWarning = "warning: ${claudeSettingsFile} is not valid JSON; skipping rtk Claude hook removal";
          }
        }
      fi
    '';

    # Same self-cleaning pattern for Cursor. No presence guard here (unlike the Claude
    # branch's `command -v claude` check): Cursor is a GUI app with no reliable CLI
    # binary this repo already checks for elsewhere -- `.cursor/mcp.json`
    # (agent-configs.nix) is likewise written unconditionally whenever its target is
    # enabled, regardless of whether Cursor.app is actually installed on this machine.
    # Enabling this also ensures Claude's hook is present (see cursorHook.enable's
    # description -- confirmed upstream rtk behavior, not something this module invented
    # or can prevent), so the enable branch here intentionally does not skip when
    # claudeHook.enable is false; the two options are independently toggleable but not
    # independently *effective* due to that coupling.
    home.activation.rtkCursorHook = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${if cfg.cursorHook.enable then ''
        ${pkgs.rtk}/bin/rtk init --global --agent cursor --auto-patch --hook-only || true
      '' else
        aiAgentsLib.mkJsonArrayEntryRemoval {
          configPath = cursorHooksFile;
          arrayPath = ".hooks.preToolUse";
          predicate = ''.command != "rtk hook cursor"'';
          invalidJsonWarning = "warning: ${cursorHooksFile} is not valid JSON; skipping rtk Cursor hook removal";
        }
      }
    '';
  };
}
