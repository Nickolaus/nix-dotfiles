{ lib, osConfig ? { }, pkgs, ... }:
let
  aiAgentsLib = import ../../../hosts/shared/ai-agents-lib.nix { inherit lib pkgs; };
  aiCfg = if osConfig ? aiAgents then osConfig.aiAgents else null;
  catalogEnabled = aiCfg != null && aiCfg.enable && aiCfg.catalog.enable;
  enabledTargets =
    if catalogEnabled then
      builtins.filter (target: aiCfg.targets.${target}.enable) [ "codex" "claude" "cursor" "vibe" ]
    else
      [ ];
  graphifyAutoStatus =
    if catalogEnabled && builtins.hasAttr "graphify-auto" aiCfg.catalog.skills then
      lib.concatMapStringsSep "\n"
        (path: ''
          path="$HOME/${path}/SKILL.md"
          if [ -f "$path" ]; then
            echo "  ok      $path"
          else
            echo "  missing $path  (home-manager switch installs it)"
          fi
        '')
        (aiAgentsLib.renderedSkillPathsFor enabledTargets "graphify-auto" aiCfg.catalog.skills.graphify-auto)
    else
      ''
        echo "  missing aiAgents.catalog.skills.graphify-auto"
      '';
  uv = "${pkgs.uv}/bin/uv";

  # PyPI package is `graphifyy`; `graphify` is the command it provides. `anthropic`
  # matches the backend most repos here already have credentials for (LLM-assisted
  # doc/media extraction) -- swap/add extras by editing this one constant if a
  # different backend/format is ever needed.
  graphifyFrom = "graphifyy[anthropic]";

  # `graphify install [--project] --platform <name>` is the one canonical, current CLI
  # surface (confirmed against the actually-installed CLI's own --help, not just docs --
  # the older per-platform bareword form like `graphify claude install` ignores scope
  # entirely and always resolves relative to cwd, which is not what we want here).
  mkInstall = extra: platform: [ "install" ] ++ extra ++ [ "--platform" platform ];

  # Platforms with a genuine *global* (user-home) install target -- installed
  # unconditionally on every switch so skill files are always derived from whatever
  # `graphify` is actually on disk, never a separately-maintained thing that can drift.
  # "cursor" is deliberately excluded here: its integration is a `.cursor/rules/*.mdc`
  # file that graphify always writes relative to cwd, with no global-home equivalent --
  # so it only makes sense at project scope (graphify-onboard, below). "agents" is the
  # cross-framework Agent-Skills spec location (~/.agents/skills/), which Vibe reads
  # directly (see vibe.nix) -- so it covers Vibe too even though upstream has no
  # dedicated Vibe platform.
  globalPlatforms = [ "claude" "codex" "agents" ];
  upstreamGlobalPlatforms = [ "codex" "agents" ];
  userSkillPath = {
    claude = ".claude/skills/graphify/SKILL.md";
    codex = ".codex/skills/graphify/SKILL.md";
    agents = ".agents/skills/graphify/SKILL.md";
  };
  syncClaudeGraphifySkill = ''
    sync_claude_graphify_skill() {
      local source_dir="$HOME/.agents/skills/graphify"
      local target_dir="$HOME/.claude/skills/graphify"

      if [ ! -f "$source_dir/SKILL.md" ]; then
        return 1
      fi

      ${pkgs.coreutils}/bin/mkdir -p "$target_dir"
      ${pkgs.coreutils}/bin/cp -R "$source_dir/." "$target_dir/"
    }
  '';
  # All platforms this machine onboards for a *project*-scope, shipped-with-the-repo
  # install (unlike global scope, cursor's project-relative rule file is exactly the
  # right shape here).
  projectPlatforms = [ "claude" "codex" "cursor" "agents" ];

  mkArgsShell = extra: p: lib.concatStringsSep " " (mkInstall extra p);

  graphifyRunFunction = ''
      graphify_run() {
        if [ -n "''${GEMINI_API_KEY:-}" ] \
          || [ -n "''${GOOGLE_API_KEY:-}" ] \
          || [ -n "''${MOONSHOT_API_KEY:-}" ] \
          || [ -n "''${ANTHROPIC_API_KEY:-}" ] \
          || [ -n "''${OPENAI_API_KEY:-}" ] \
          || [ -n "''${DEEPSEEK_API_KEY:-}" ]; then
          graphify "$@"
          return "$?"
        fi

        echo "No semantic Graphify API key found; using temporary code-only scan."
        backup_ignore=""
        had_ignore=0
        if [ -f .graphifyignore ]; then
          backup_ignore="$(mktemp "''${TMPDIR:-/tmp}/graphifyignore.XXXXXX")"
          cp .graphifyignore "$backup_ignore"
          had_ignore=1
        fi

    printf '%s\n' \
      "" \
      "# graphify-ensure temporary code-only fallback" \
      "*.md" \
      "*.mdx" \
      "*.txt" \
      "*.rst" \
      "*.adoc" \
      "*.pdf" \
      "*.png" \
      "*.jpg" \
      "*.jpeg" \
      "*.gif" \
      "*.webp" \
      "*.mp4" \
      "*.mp3" \
      "*.wav" \
      ".claude/" \
      ".codex/skills/graphify/" \
      ".cursor/rules/graphify.mdc" \
      ".agents/skills/graphify/" \
      >> .graphifyignore

        set +e
        graphify "$@"
        rc="$?"
        set -e

        if [ "$had_ignore" = "1" ]; then
          cp "$backup_ignore" .graphifyignore
          rm -f "$backup_ignore"
        else
          rm -f .graphifyignore
        fi
        return "$rc"
      }
  '';
in
{
  # Two layers, deliberately not conflated:
  #
  # 1. Global/personal (this module): a plain `uv tool install` puts a real `graphify`
  #    command on PATH in every shell/directory on this machine, independent of any
  #    project -- upstream's own recommended mode for solo/ad-hoc use ("Developers who
  #    work alone and always want Graphify available everywhere should continue using
  #    the default [user-scope] install"). Not Nix-packaged (same rationale as
  #    codebase-memory-mcp/headroom: this CLI ships fast, uv keeps it decoupled from a
  #    flake input pin) and not force-upgraded on every switch -- installed only if
  #    missing, so `home-manager switch` never needs network once it's there. Run
  #    `graphify-update` to opt into a newer released version.
  #
  # 2. Project-shipped (NOT managed here): a repo that wants Graphify committed --
  #    graph + project-scoped skill files, git hooks for auto-rebuild -- runs
  #    `graphify-onboard` once (wraps upstream's own recommended team-onboarding
  #    sequence). Whether that repo additionally pins an exact Graphify version in its
  #    own mise.toml for CI reproducibility is a separate, per-repo decision left to
  #    that repo (mise's pipx backend already shells out to `uv tool install` whenever
  #    uv is on PATH, which it is via packages.nix, so it needs no dotfiles wiring).
  #
  # Unlike the CLI binary, user-scope skill *files* are cheap to regenerate: `graphify
  # install --platform X` just copies content bundled inside whatever `graphify` is
  # already on disk, no network/model call involved. So instead of a second
  # "install/upgrade the skills" concern that can independently drift from whatever CLI
  # version happens to be installed (including a pre-existing manual install this
  # module never touched), every switch unconditionally re-derives the skill files from
  # the actually-installed package. There is nothing to keep in sync by hand.
  #
  # Caveat specific to "claude": upstream's global-scope install also tries to inject a
  # section into ~/.claude/CLAUDE.md and register a hook in ~/.claude/settings.json --
  # both of which are Nix-managed here. Install the neutral Agent-Skills copy first,
  # then mirror those files into Claude's skill directory without touching Claude's
  # managed instruction or hook files.
  home.activation.ensureGraphifyInstalled = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${uv} tool install ${lib.escapeShellArg graphifyFrom} >/dev/null 2>&1 \
      || echo "Warning: failed to install graphify (uv tool install ${graphifyFrom})" >&2

    # `uv tool install` puts the shim in its own tool bin dir, which the activation
    # script's PATH doesn't necessarily include -- resolve explicitly instead of
    # relying on `command -v` picking it up.
    graphifyBin="$(${uv} tool dir --bin 2>/dev/null)/graphify"
    if [ ! -x "$graphifyBin" ]; then
      graphifyBin="$(command -v graphify 2>/dev/null || true)"
    fi
    if [ -n "$graphifyBin" ] && [ -x "$graphifyBin" ]; then
      ${lib.concatMapStringsSep "\n      " (p: ''
        "$graphifyBin" ${mkArgsShell [ ] p} >/dev/null 2>&1 \
          || echo "Warning: 'graphify ${mkArgsShell [ ] p}' failed" >&2
      '') upstreamGlobalPlatforms}
      ${syncClaudeGraphifySkill}
      sync_claude_graphify_skill \
        || echo "Warning: failed to mirror Graphify agent skill into Claude skill directory" >&2
    fi
  '';

  home.packages = [
    (pkgs.writeShellScriptBin "graphify-status" ''
      set -euo pipefail

      if command -v graphify >/dev/null 2>&1; then
        version="$(graphify --version 2>/dev/null || echo 'version unknown')"
        echo "  ok      $(command -v graphify)  ($version)"
      else
        echo "  missing graphify -- run: uv tool install ${lib.escapeShellArg graphifyFrom}"
      fi

      echo
      echo "User-scope skill installs (re-derived from the installed package on every switch,"
      echo "always in sync -- nothing to update by hand):"
      ${lib.concatMapStringsSep "\n" (p: ''
        path="$HOME/${userSkillPath.${p}}"
        if [ -f "$path" ]; then
          echo "  ok      $path"
        else
          echo "  missing $path  (home-manager switch installs it)"
        fi
      '') globalPlatforms}
      echo "  n/a     cursor has no global scope -- its .cursor/rules/graphify.mdc is always"
      echo "          project-relative, see graphify-onboard"
      echo
      echo "Graphify auto skill (Nix-managed lazy trigger for graphify-ensure):"
      echo "  Source of truth: aiAgents.catalog.skills.graphify-auto"
      ${graphifyAutoStatus}

      echo
      if [ -f "graphify-out/graph.json" ] || [ -f "graphify-out/graph.json.gz" ]; then
        echo "This directory has a project-scope graph: graphify-out/"
      else
        echo "No project-scope graph here. Create/update it now: graphify-ensure"
        echo "Ready-to-ship setup (same graph + project skill files + hooks): graphify-onboard"
      fi
      echo "Aggregate multiple local repo graphs for cross-repo queries: graphify global add <graph.json> --as <name>"
    '')

    (pkgs.writeShellScriptBin "graphify-update" ''
      set -euo pipefail

      echo "Upgrading global graphify install (the only manual step -- this needs network to"
      echo "check PyPI for a newer release, so it's never done automatically on switch)..."
      ${uv} tool install --upgrade ${lib.escapeShellArg graphifyFrom}

      echo
      echo "Re-deriving user-scope skill files from the now-upgraded package (instant feedback;"
      echo "the next home-manager switch would do this anyway):"
      ${lib.concatMapStringsSep "\n" (p: ''
        echo "  graphify ${mkArgsShell [ ] p}"
        graphify ${mkArgsShell [ ] p} || echo "  warning: '${p}' install failed" >&2
      '') upstreamGlobalPlatforms}
      ${syncClaudeGraphifySkill}
      echo "  sync ~/.agents/skills/graphify -> ~/.claude/skills/graphify"
      sync_claude_graphify_skill || echo "  warning: claude skill mirror failed" >&2
    '')

    # Lazy per-repo automation: create the project graph when missing and update it
    # when present. This is intentionally an explicit command rather than a shell
    # chpwd hook: building a graph writes repo files and can be expensive, so agents
    # should run it when Graphify context is needed, not on every directory change.
    (pkgs.writeShellScriptBin "graphify-ensure" ''
      set -euo pipefail

      if [ "''${1:-}" = "--help" ] || [ "''${1:-}" = "-h" ]; then
        echo "Usage: graphify-ensure [repo-dir]"
        echo "Create graphify-out/ if missing, update it if present, and ensure project skill files/hooks."
        exit 0
      fi

      target="''${1:-.}"
      cd "$target"

      if ! command -v graphify >/dev/null 2>&1; then
        echo "graphify not found on PATH. Run 'home-manager switch' first (installs it globally)." >&2
        exit 1
      fi

      ${graphifyRunFunction}

      if git_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
        cd "$git_root"
        is_git=1
      else
        is_git=0
      fi

      if [ -f graphify-out/graph.json ] || [ -f graphify-out/graph.json.gz ]; then
        echo "==> Updating Graphify project graph ($(pwd))"
        graphify_run update . || graphify_run . --update
      else
        echo "==> Creating Graphify project graph ($(pwd))"
        graphify_run .
      fi
      echo

      echo "==> Ensuring project-scoped Graphify skill files"
      ${lib.concatMapStringsSep "\n" (p: ''
        echo "  graphify ${mkArgsShell [ "--project" ] p}"
        graphify ${mkArgsShell [ "--project" ] p} || echo "  warning: '${p}' install failed" >&2
      '') projectPlatforms}
      echo

      if [ "$is_git" = "1" ]; then
        echo "==> Ensuring Graphify git hooks"
        hooks_dir="$(git rev-parse --git-path hooks)"
        mkdir -p "$hooks_dir"
        for hook in post-commit post-checkout; do
          hook_path="$hooks_dir/$hook"
          if [ -L "$hook_path" ]; then
            tmp_hook="$hook_path.graphify-tmp"
            cat "$hook_path" > "$tmp_hook"
            chmod 755 "$tmp_hook"
            mv "$tmp_hook" "$hook_path"
          fi
        done
        graphify hook install || echo "  warning: hook install failed" >&2
        echo

        if [ -f .gitignore ] && ! grep -qF "graphify-out/cost.json" .gitignore; then
          printf '\n# Graphify (local-only artifact)\ngraphify-out/cost.json\n' >> .gitignore
          echo "==> Appended graphify-out/cost.json to .gitignore"
          echo
        fi

        echo "==> Project graph state:"
        git status --porcelain -- graphify-out .graphifyignore .gitignore \
          .claude .codex .cursor .agents CLAUDE.md AGENTS.md \
          2>/dev/null | sed 's/^/  /'
      fi
    '')

    # Onboards a repo onto Graphify, ready to ship: builds the initial graph, installs
    # project-scoped skill files for every platform this machine onboards, and wires
    # git hooks for auto-rebuild + conflict-free graph.json merges -- upstream's own
    # recommended team-onboarding sequence (`graphify .` -> `graphify install --project`
    # -> `graphify hook install` -> commit), just scripted so it's one command instead
    # of remembering five. Deliberately does not touch CI, .graphifyignore curation, or
    # any repo-specific pinning -- those stay reviewed, per-repo decisions.
    (pkgs.writeShellScriptBin "graphify-onboard" ''
      set -euo pipefail

      target="''${1:-.}"
      cd "$target"

      if ! command -v graphify >/dev/null 2>&1; then
        echo "graphify not found on PATH. Run 'home-manager switch' first (installs it globally)." >&2
        exit 1
      fi

      ${graphifyRunFunction}

      if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
        echo "Warning: $(pwd) is not inside a git repo -- 'graphify hook install' will be skipped." >&2
        is_git=0
      else
        is_git=1
      fi

      echo "==> Building the graph ($(pwd))"
      graphify_run .
      echo

      echo "==> Installing project-scoped skill files"
      ${lib.concatMapStringsSep "\n" (p: ''
        echo "  graphify ${mkArgsShell [ "--project" ] p}"
        graphify ${mkArgsShell [ "--project" ] p} || echo "  warning: '${p}' install failed" >&2
      '') projectPlatforms}
      echo

      if [ "$is_git" = "1" ]; then
        echo "==> Installing git hooks (auto-rebuild on commit + conflict-free graph.json merges)"
        hooks_dir="$(git rev-parse --git-path hooks)"
        mkdir -p "$hooks_dir"
        for hook in post-commit post-checkout; do
          hook_path="$hooks_dir/$hook"
          if [ -L "$hook_path" ]; then
            tmp_hook="$hook_path.graphify-tmp"
            cat "$hook_path" > "$tmp_hook"
            chmod 755 "$tmp_hook"
            mv "$tmp_hook" "$hook_path"
          fi
        done
        graphify hook install || echo "  warning: hook install failed" >&2
        echo
      fi

      if [ -f .gitignore ] && ! grep -qF "graphify-out/cost.json" .gitignore; then
        printf '\n# Graphify (local-only artifact)\ngraphify-out/cost.json\n' >> .gitignore
        echo "==> Appended graphify-out/cost.json to .gitignore"
        echo
      fi

      echo "==> Ready to ship. Review and commit:"
      if [ "$is_git" = "1" ]; then
        git status --porcelain -- graphify-out .graphifyignore .gitignore \
          .claude .codex .cursor .agents CLAUDE.md AGENTS.md \
          2>/dev/null | sed 's/^/  /'
      fi
      echo
      echo "Docs/media nodes need a model backend for headless extraction (ANTHROPIC_API_KEY"
      echo "etc.) or the /graphify skill run inside an IDE session (uses that session's model,"
      echo "no extra keys). Re-run after edits with: graphify update ."
    '')
  ];

}
