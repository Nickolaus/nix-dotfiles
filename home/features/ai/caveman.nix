{ config, flake, lib, osConfig ? { }, pkgs, ... }:
let
  cfg = config.caveman;
  aiSources = import ../../../flake/ai-agent-sources.nix { inherit flake; };
  cavemanSrc = aiSources.skills.caveman;
  aiAgentsLib = import ../../../hosts/shared/ai-agents-lib.nix { inherit lib pkgs; };
  aiCfg = if osConfig ? aiAgents then osConfig.aiAgents else null;
  catalogEnabled = aiCfg != null && aiCfg.enable && aiCfg.catalog.enable;
  enabledTargets =
    if catalogEnabled then
      builtins.filter (target: aiCfg.targets.${target}.enable) [ "codex" "claude" "cursor" "vibe" ]
    else
      [ ];
  cavemanCatalogSkills =
    if catalogEnabled then
      lib.filterAttrs (_: skill: skill.owner == "caveman" && skill.managed) aiCfg.catalog.skills
    else
      { };
  cavemanSkillStatus = lib.concatMapStringsSep "\n"
    (skill:
      lib.concatMapStringsSep "\n"
        (path: ''
          skill_path="$HOME/${path}/SKILL.md"
          if [ -f "$skill_path" ]; then
            echo "  ok      $skill_path"
          else
            echo "  missing $skill_path"
          fi
        '')
        (aiAgentsLib.renderedSkillPathsFor enabledTargets skill cavemanCatalogSkills.${skill}))
    (builtins.attrNames cavemanCatalogSkills);
  # Home Manager's activation script hardcodes a minimal PATH for its entire run that
  # never includes nix-darwin's per-user system profile directory, where `claude`
  # actually lives -- confirmed directly (a real `darwin-rebuild switch` run showed this
  # step produce zero output, meaning `command -v claude` failed silently here every
  # time). Same fix already established for launchd-facing scripts elsewhere
  # (ollama.nix/headroom.nix's `launchdPath`).
  perUserSystemProfileBin = "/etc/profiles/per-user/${config.home.username}/bin";
  nodePackage = pkgs.nodejs_24;
  node = "${nodePackage}/bin/node";
  claudeHookNode = "${perUserSystemProfileBin}/node";
  installer = "${cavemanSrc}/bin/install.js";
  repairClaudeHookNode = pkgs.writeShellScript "caveman-repair-claude-hook-node" ''
    set -euo pipefail

    settings="''${1:-$HOME/.claude/settings.json}"
    hook_node="''${2:-${claudeHookNode}}"

    if [ ! -f "$settings" ]; then
      exit 0
    fi

    exec ${node} - "$settings" "$hook_node" <<'JS'
    const fs = require("fs");
    const path = require("path");

    const settingsPath = process.argv[2];
    const hookNode = process.argv[3];
    const managed = new Set(["caveman-activate.js", "caveman-mode-tracker.js"]);

    function tokenize(command) {
      const out = [];
      let token = "";
      let quote = null;
      for (let i = 0; i < command.length; i++) {
        const c = command[i];
        if (quote) {
          if (c === quote) quote = null;
          else token += c;
          continue;
        }
        if (c === "\"" || c === "'") {
          quote = c;
          continue;
        }
        if (/\s/.test(c)) {
          if (token) {
            out.push(token);
            token = "";
          }
          continue;
        }
        token += c;
      }
      if (token) out.push(token);
      return out;
    }

    function shellQuote(value) {
      return "\"" + String(value).replace(/\\/g, "\\\\").replace(/"/g, "\\\"") + "\"";
    }

    let settings;
    try {
      settings = JSON.parse(fs.readFileSync(settingsPath, "utf8"));
    } catch (error) {
      console.error("Warning: " + settingsPath + " is not valid JSON; skipping caveman hook node repair: " + error.message);
      process.exit(0);
    }

    let changed = false;
    const hooks = settings && settings.hooks;
    if (hooks && typeof hooks === "object") {
      for (const event of Object.keys(hooks)) {
        if (!Array.isArray(hooks[event])) continue;
        for (const entry of hooks[event]) {
          if (!entry || !Array.isArray(entry.hooks)) continue;
          for (const hook of entry.hooks) {
            if (!hook || typeof hook.command !== "string") continue;
            const script = tokenize(hook.command).find((part) => managed.has(path.basename(part)));
            if (!script) continue;
            const next = shellQuote(hookNode) + " " + shellQuote(script);
            if (hook.command !== next) {
              hook.command = next;
              changed = true;
            }
          }
        }
      }
    }

    if (!changed) process.exit(0);

    const dir = path.dirname(settingsPath);
    const tmp = path.join(dir, "." + path.basename(settingsPath) + "." + process.pid + ".tmp");
    const mode = fs.statSync(settingsPath).mode & 0o777;
    fs.writeFileSync(tmp, JSON.stringify(settings, null, 2) + "\n", { mode });
    fs.renameSync(tmp, settingsPath);
    JS
  '';

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
  options.caveman.claudeHooks.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Install caveman's Claude Code plugin + SessionStart/UserPromptSubmit hooks +
      statusline badge (via the upstream installer's `--with-hooks` mode).
      Self-cleaning: this activation script always runs, and disabling this runs
      the installer's own `--uninstall`, which removes exactly its own settings.json
      entries and hook files (confirmed it preserves unrelated hooks -- e.g. an IDE's
      own installer, or rtk's -- untouched). Independent of the always-on CLAUDE.md
      skill text above, which this option does not affect.
    '';
  };

  config.home.file = {
    ".codex/AGENTS.md".text = cavemanDefaultInstructions;
    ".vibe/AGENTS.md".text = cavemanDefaultInstructions;
    ".claude/CLAUDE.md".text = cavemanDefaultInstructions;
  };

  config.home.activation.cavemanClaudeHooks = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    PATH="${perUserSystemProfileBin}:$PATH"
    if command -v claude >/dev/null 2>&1; then
      ${if cfg.claudeHooks.enable then ''
        # Upstream installer copies hook files from a read-only Nix store source; the
        # copies inherit that read-only mode, so re-running without this chmod fails
        # with "EACCES: permission denied" on the second and every subsequent switch
        # (confirmed directly). --force is deliberately not used here: without it the
        # installer correctly skips the already-installed plugin/marketplace steps
        # (no needless network calls on every rebuild) and only re-copies hook files.
        chmod -R u+w "$HOME/.claude/hooks" 2>/dev/null || true
        ${node} ${installer} --only claude --with-hooks --no-mcp-shrink --non-interactive || true
        # Caveman's installer records process.execPath into settings.json. If the
        # plugin is ever run by Homebrew's node, that becomes a versioned Cellar path
        # and breaks on the next brew upgrade. Keep Claude settings mutable, but
        # declaratively normalize only our managed hook commands to the stable Nix
        # profile node path after every switch.
        ${repairClaudeHookNode} "$HOME/.claude/settings.json" ${lib.escapeShellArg claudeHookNode} \
          || echo "Warning: failed to normalize caveman Claude hook node path" >&2
      '' else ''
        ${node} ${installer} --uninstall --non-interactive || true
      ''}
    fi
  '';

  config.home.packages = [
    nodePackage

    (pkgs.writeShellScriptBin "caveman-status" ''
      set -euo pipefail

      echo "Caveman source: ${cavemanSrc}"
      echo "Claude hook node: ${claudeHookNode}"
      echo "User-level skills (auto-discovered, no manifest needed):"
      echo "  Codex + Vibe follow the Agent Skills spec and read ~/.agents/skills/"
      echo "  Cursor also scans ~/.cursor/skills/ (cursor.com/docs/skills) -- catalog renders both"
      echo "  Source of truth: aiAgents.catalog.skills (owner=caveman)"
      ${cavemanSkillStatus}
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
      echo "Cursor has no global-rules file Nix can manage (User Rules are GUI-only, not exported"
      echo "to disk -- see cursor.com/help/customization/rules), so the skill above is *available*"
      echo "in Cursor (invoke with '/caveman' or a matching request) but not forced on-by-default"
      echo "the way it is for the other three. To force it in Cursor too: Cursor Settings > Rules >"
      echo "User Rules, and paste a short pointer at the skill (one-time manual step, per-machine)."
      echo
      echo "Claude's caveman plugin + hooks + statusline (beyond the default CLAUDE.md style"
      echo "above) install automatically on every switch (caveman.claudeHooks.enable, default"
      echo "true) -- self-cleaning, so setting it false and rebuilding runs the real"
      echo "'--uninstall' and removes them again. For just the plugin without hooks/statusline,"
      echo "run caveman-claude-install-minimal by hand."
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
  ];
}
