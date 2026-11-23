{ config
, lib
, pkgs
, ...
}:

# Scheduled pruning for the developer caches that have no bound of their own.
#
# These live in $HOME, so the Nix store collector never sees them, and both
# caches here share one failure mode: entries are created automatically, keyed
# by something that outlives its referent, and never evicted.
#
# uv: every MCP server runs as `uv tool uvx ...` and holds a shared lock on the
# cache for its whole lifetime, so a plain `uv cache prune` blocks on that lock
# and times out. A prune therefore only succeeds while no MCP server is up,
# which in practice is never, and the cache grows without bound. `--force`
# skips the in-use check, not the reference check: entries a cached environment
# still references survive, so the environments running servers execute from
# are left intact.
#
# codebase-memory: the cache key is a hash of the absolute git root, so every
# worktree gets its own graph (~600 MB each) and a deleted worktree leaves an
# entry nothing can reach. The wrapper in hosts/shared/ai-agents.nix records
# the source path in each entry so this pruner can test it.
#
# codex: session transcripts accumulate one file per session under a dated tree
# with no retention of its own. Unlike the two caches above this is recorded
# history rather than derived state, so the bound is deliberately generous and
# is the one value here worth revisiting.
#
# See docs/nix-store-disk-growth-root-cause.md.

let
  inherit (pkgs.stdenv.hostPlatform) isDarwin;

  logDir = "${config.home.homeDirectory}/Library/Logs/cache-hygiene";

  uvPruneScript = pkgs.writeShellScript "uv-cache-prune" ''
    set -euo pipefail
    export PATH="${config.home.profileDirectory}/bin:${pkgs.coreutils}/bin:$PATH"

    cache_dir="''${UV_CACHE_DIR:-$HOME/.cache/uv}"

    if ! command -v uv > /dev/null 2>&1; then
      echo "uv not on PATH; nothing to prune"
      exit 0
    fi

    if [ ! -d "$cache_dir" ]; then
      echo "no uv cache at $cache_dir"
      exit 0
    fi

    echo "=== uv-cache-prune $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
    echo "before: $(du -sh "$cache_dir" | cut -f1)"
    uv cache prune --force
    echo "after:  $(du -sh "$cache_dir" | cut -f1)"
  '';

  # Entries whose recorded worktree is gone are unreachable and are removed.
  # Entries with no marker predate the wrapper writing one; those fall back to
  # an access-time bound rather than being deleted outright, because a live
  # worktree that simply has not been indexed recently must survive.
  staleGraphDays = 60;

  cbmPruneScript = pkgs.writeShellScript "cbm-cache-prune" ''
    set -euo pipefail
    export PATH="${pkgs.coreutils}/bin:${pkgs.findutils}/bin:$PATH"

    repos_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/codebase-memory-mcp/repos"

    if [ ! -d "$repos_dir" ]; then
      echo "no codebase-memory cache at $repos_dir"
      exit 0
    fi

    echo "=== cbm-cache-prune $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
    echo "before: $(du -sh "$repos_dir" | cut -f1)"

    removed=0
    for entry in "$repos_dir"/*; do
      [ -d "$entry" ] || continue

      if [ -f "$entry/.source-path" ]; then
        source_path="$(head -n 1 "$entry/.source-path")"
        if [ -n "$source_path" ] && [ ! -d "$source_path" ]; then
          echo "orphan (worktree gone: $source_path): $(basename "$entry")"
          rm -rf -- "$entry"
          removed=$((removed + 1))
        fi
        continue
      fi

      if [ -z "$(find "$entry" -maxdepth 0 -mtime -${toString staleGraphDays})" ]; then
        echo "stale (unmarked, untouched ${toString staleGraphDays}d): $(basename "$entry")"
        rm -rf -- "$entry"
        removed=$((removed + 1))
      fi
    done

    echo "removed $removed entr(y|ies)"
    echo "after:  $(du -sh "$repos_dir" | cut -f1)"
  '';

  # Session transcripts are history, not a cache: nothing regenerates them.
  # 180 days keeps two quarters of context while still bounding growth.
  codexRetentionDays = 180;

  codexPruneScript = pkgs.writeShellScript "codex-session-prune" ''
    set -euo pipefail
    export PATH="${pkgs.coreutils}/bin:${pkgs.findutils}/bin:$PATH"

    codex_dir="$HOME/.codex"

    if [ ! -d "$codex_dir" ]; then
      echo "no codex state at $codex_dir"
      exit 0
    fi

    echo "=== codex-session-prune $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
    echo "before: $(du -sh "$codex_dir" | cut -f1)"

    for sub in sessions archived_sessions; do
      target="$codex_dir/$sub"
      [ -d "$target" ] || continue

      count="$(find "$target" -type f -mtime +${toString codexRetentionDays} | wc -l | tr -d ' ')"
      echo "$sub: $count file(s) older than ${toString codexRetentionDays}d"

      find "$target" -type f -mtime +${toString codexRetentionDays} -delete
      # The tree is nested by date, so pruning files leaves empty day/month
      # directories behind; drop those but never $target itself.
      find "$target" -mindepth 1 -type d -empty -delete
    done

    echo "after:  $(du -sh "$codex_dir" | cut -f1)"
  '';
in
lib.mkIf isDarwin {
  home.activation.cacheHygieneLogDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p ${lib.escapeShellArg logDir}
  '';

  # These three agents run in the `user` launchd domain. They touch only files
  # under $HOME and need no Aqua session, and launchd loads
  # ~/Library/LaunchAgents only at graphical login. In the `user` domain the
  # nix-darwin side of Home Manager bootstraps them at boot instead, so a
  # Saturday prune still runs on a machine that is powered on but sitting at
  # the login window.
  launchd.agents.codex-session-prune = {
    enable = true;
    domain = "user";
    config = {
      ProgramArguments = [ "${codexPruneScript}" ];
      # Saturday 05:15, last in the chain so the three never contend for IO.
      StartCalendarInterval = [
        {
          Weekday = 6;
          Hour = 5;
          Minute = 15;
        }
      ];
      StandardOutPath = "${logDir}/codex-session-prune.log";
      StandardErrorPath = "${logDir}/codex-session-prune.error.log";
      ProcessType = "Background";
      EnvironmentVariables = {
        PATH = "/etc/profiles/per-user/${config.home.username}/bin:/usr/bin:/bin:/usr/sbin:/sbin";
        HOME = config.home.homeDirectory;
      };
    };
  };

  launchd.agents.cbm-cache-prune = {
    enable = true;
    domain = "user";
    config = {
      ProgramArguments = [ "${cbmPruneScript}" ];
      # Saturday 04:45, after the uv prune so the two do not contend for IO.
      StartCalendarInterval = [
        {
          Weekday = 6;
          Hour = 4;
          Minute = 45;
        }
      ];
      StandardOutPath = "${logDir}/cbm-cache-prune.log";
      StandardErrorPath = "${logDir}/cbm-cache-prune.error.log";
      ProcessType = "Background";
      EnvironmentVariables = {
        PATH = "/etc/profiles/per-user/${config.home.username}/bin:/usr/bin:/bin:/usr/sbin:/sbin";
        HOME = config.home.homeDirectory;
      };
    };
  };

  launchd.agents.uv-cache-prune = {
    enable = true;
    domain = "user";
    config = {
      ProgramArguments = [ "${uvPruneScript}" ];
      # Saturday 04:15, a day before the system GC in
      # hosts/shared/nix-gc-darwin.nix, so the two never contend for IO.
      StartCalendarInterval = [
        {
          Weekday = 6;
          Hour = 4;
          Minute = 15;
        }
      ];
      StandardOutPath = "${logDir}/uv-cache-prune.log";
      StandardErrorPath = "${logDir}/uv-cache-prune.error.log";
      # Background throttles IO; pruning is never urgent. launchd agents get a
      # minimal environment, so HOME has to be passed explicitly - the script
      # derives the cache path from it.
      ProcessType = "Background";
      EnvironmentVariables = {
        PATH = "/etc/profiles/per-user/${config.home.username}/bin:/usr/bin:/bin:/usr/sbin:/sbin";
        HOME = config.home.homeDirectory;
      };
    };
  };
}
