{ lib, pkgs, ... }:
let
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
  userSkillPath = {
    claude = ".claude/skills/graphify/SKILL.md";
    codex = ".codex/skills/graphify/SKILL.md";
    agents = ".agents/skills/graphify/SKILL.md";
  };

  # All platforms this machine onboards for a *project*-scope, shipped-with-the-repo
  # install (unlike global scope, cursor's project-relative rule file is exactly the
  # right shape here).
  projectPlatforms = [ "claude" "codex" "cursor" "agents" ];

  mkArgsShell = extra: p: lib.concatStringsSep " " (mkInstall extra p);
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
  # Caveat specific to "claude": its global-scope install *also* tries to inject a
  # section into ~/.claude/CLAUDE.md and register a hook in ~/.claude/settings.json --
  # both of which are Nix-managed (read-only) symlinks here (caveman.nix,
  # codebase-memory.nix, agent-configs.nix), so that half of the command fails every
  # switch. That's expected and harmless: the actually-useful SKILL.md install happens
  # first and always succeeds, the failure is swallowed by the `|| echo warning` below,
  # and its stdout/stderr is already suppressed.
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
      '') globalPlatforms}
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
      if [ -f "graphify-out/graph.json" ] || [ -f "graphify-out/graph.json.gz" ]; then
        echo "This directory has a project-scope graph: graphify-out/"
      else
        echo "No project-scope graph here. Ad-hoc: 'graphify .'  Ready-to-ship setup"
        echo "(graph + project skill files + auto-rebuild hooks): graphify-onboard"
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
      '') globalPlatforms}
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

      if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
        echo "Warning: $(pwd) is not inside a git repo -- 'graphify hook install' will be skipped." >&2
        is_git=0
      else
        is_git=1
      fi

      echo "==> Building the graph ($(pwd))"
      graphify .
      echo

      echo "==> Installing project-scoped skill files"
      ${lib.concatMapStringsSep "\n" (p: ''
        echo "  graphify ${mkArgsShell [ "--project" ] p}"
        graphify ${mkArgsShell [ "--project" ] p} || echo "  warning: '${p}' install failed" >&2
      '') projectPlatforms}
      echo

      if [ "$is_git" = "1" ]; then
        echo "==> Installing git hooks (auto-rebuild on commit + conflict-free graph.json merges)"
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
