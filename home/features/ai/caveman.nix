{ config, flake, lib, pkgs, ... }:
let
  cfg = config.caveman;
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
  # Codex and Vibe both follow the Agent Skills spec and read ~/.agents/skills/ directly.
  # Cursor discovers skills from *either* ~/.agents/skills/ or its own ~/.cursor/skills/
  # (cursor.com/docs/skills) -- both are documented, auto-scanned, global locations with
  # no manifest/registration step, so skillDestDirs just fans the same
  # cavemanSkills/cavemanSrc pair out to both prefixes instead of hand-duplicating the
  # list. Cursor's own built-in skills live separately under ~/.cursor/skills-cursor/ and
  # are unaffected.
  skillDirPrefixes = [ ".agents/skills" ".cursor/skills" ];
  skillDestDirs = builtins.listToAttrs (lib.concatMap
    (prefix: map
      (skill: {
        name = "${prefix}/${skill}";
        value = {
          source = cavemanSrc + "/skills/${skill}";
        };
      })
      cavemanSkills)
    skillDirPrefixes);
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

  config.home.file = skillDestDirs // {
    ".codex/AGENTS.md".text = cavemanDefaultInstructions;
    ".vibe/AGENTS.md".text = cavemanDefaultInstructions;
    ".claude/CLAUDE.md".text = cavemanDefaultInstructions;
  };

  config.home.activation.cavemanClaudeHooks = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
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
      '' else ''
        ${node} ${installer} --uninstall --non-interactive || true
      ''}
    fi
  '';

  config.home.packages = [
    (pkgs.writeShellScriptBin "caveman-status" ''
      set -euo pipefail

      echo "Caveman source: ${cavemanSrc}"
      echo "User-level skills (auto-discovered, no manifest needed):"
      echo "  Codex + Vibe follow the Agent Skills spec and read ~/.agents/skills/"
      echo "  Cursor also scans ~/.cursor/skills/ (cursor.com/docs/skills) -- same content, mirrored"
      for prefix in ${builtins.concatStringsSep " " (map lib.escapeShellArg skillDirPrefixes)}; do
        for skill in ${builtins.concatStringsSep " " cavemanSkills}; do
          skill_path="$HOME/$prefix/$skill/SKILL.md"
          if [ -f "$skill_path" ]; then
            echo "  ok      $skill_path"
          else
            echo "  missing $skill_path"
          fi
        done
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
