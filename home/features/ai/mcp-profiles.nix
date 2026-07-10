{ lib, osConfig ? { }, pkgs, ... }:
let
  inherit (lib) optionalAttrs optionalString;

  aiAgentsLib = import ../../../hosts/shared/ai-agents-lib.nix { inherit lib pkgs; };

  aiCfg = if osConfig ? aiAgents then osConfig.aiAgents else null;
  profiles = if aiCfg != null then aiCfg.mcpProfiles else { };
  profileNames = builtins.attrNames profiles;

  # FastMCP's own MCPConfig schema uses "transport" for HTTP backends (not
  # "type", which is what home/features/ai/agent-configs.nix's
  # renderMcpServerForJson emits for Cursor/Claude) -- this is its own small
  # renderer rather than a copy of that one. `inheritEnv`/`bearerTokenEnvVar`
  # are passed through as plain metadata (server names, never resolved
  # secret values) instead of being expanded here at eval time, so nothing
  # ever lands in the Nix store -- mcp-profile-gateway.py resolves them from
  # its own ambient environment at run time, the same trust boundary Claude
  # Code's own MCP rendering already relies on for inherited session env.
  renderProfileServerManifest = name: rawServer:
    if aiAgentsLib.isUrlTransport rawServer then
      { transport = rawServer.type; url = rawServer.url; }
      // optionalAttrs (rawServer.headers != { }) { headers = rawServer.headers; }
      // optionalAttrs (rawServer.bearerTokenEnvVar != null) { bearerTokenEnvVar = rawServer.bearerTokenEnvVar; }
    else
      aiAgentsLib.renderStdioCommand name rawServer
      // optionalAttrs (rawServer.args != [ ]) { args = rawServer.args; }
      // optionalAttrs (rawServer.env != { }) { env = rawServer.env; }
      // optionalAttrs (rawServer.inheritEnv != [ ]) { inheritEnv = rawServer.inheritEnv; };

  mkServerManifest = name: serverNames:
    pkgs.writeText "mcp-profile-${name}.json" (builtins.toJSON {
      mcpServers = builtins.listToAttrs (map
        (serverName: {
          name = serverName;
          value = renderProfileServerManifest serverName aiCfg.mcpServers.${serverName};
        })
        serverNames);
    });

  mkProfileManifest = profileName: profile:
    mkServerManifest profileName profile.servers;

  # Codex handles OAuth for HTTP MCP servers natively. Do not hide those behind
  # the FastMCP stdio profile proxy, or `codex mcp login <name>` has no real
  # remote HTTP server to authenticate. Profile onboarding still uses the proxy
  # for Cursor/Vibe and for non-OAuth stdio aggregations.
  codexDirectProfileServers = {
    atlassian = {
      atlassian = {
        url = aiCfg.mcpServers.atlassian.url;
      };
    };
  };

  codexDirectProfileCase = lib.concatStringsSep "\n" (map
    (profileName: ''
      ${profileName}) codex_direct_json=${lib.escapeShellArg (builtins.toJSON codexDirectProfileServers.${profileName})} ;;
    '')
    (builtins.attrNames codexDirectProfileServers));

  # One shared script for every profile: reads the pre-resolved, build-time
  # manifest named by argv[1], resolves inheritEnv/bearerTokenEnvVar from its
  # own environment at run time, and proxies the composed server set over
  # stdio via FastMCP's create_proxy -- fastmcp isn't in nixpkgs (same
  # situation as headroom-ai/mcp-server-fetch/mcp-server-time), so `uv run`
  # resolves it from the PEP 723 header below rather than a Nix-packaged
  # interpreter (contrast home/features/ai/vibe.nix's tomlkit script, which
  # uses pkgs.python3.withPackages precisely because tomlkit *is* packaged).
  gatewayScript = pkgs.writeText "mcp-profile-gateway.py" ''
    # /// script
    # dependencies = ["fastmcp"]
    # ///
    import json
    import os
    import sys

    from fastmcp.server import create_proxy

    manifest_path, profile_name = sys.argv[1], sys.argv[2]

    with open(manifest_path) as f:
        config = json.load(f)

    for entry in config.get("mcpServers", {}).values():
        inherit_env = entry.pop("inheritEnv", [])
        bearer_var = entry.pop("bearerTokenEnvVar", None)

        if inherit_env:
            env = dict(entry.get("env") or {})
            for var in inherit_env:
                if var in os.environ:
                    env[var] = os.environ[var]
            entry["env"] = env

        if bearer_var:
            headers = dict(entry.get("headers") or {})
            headers["Authorization"] = "Bearer " + os.environ.get(bearer_var, "")
            entry["headers"] = headers

    create_proxy(config, name=profile_name).run()
  '';

  # Spawned fresh per client invocation, exits when the client session ends --
  # never a persistent or shared process. That's a deliberate correctness
  # choice, not just the simple option: a shared/persistent backend would
  # multiplex unrelated repos onto the same Serena LSP workspace, the same
  # browser session (puppeteer/chrome-devtools), or the same in-process state
  # of any future stateful server, causing exactly the cross-repo "ghosting"
  # that a per-invocation process boundary avoids for free.
  mkProfileBinary = profileName: profile:
    pkgs.writeShellScriptBin "mcp-profile-${profileName}" ''
      set -euo pipefail
      exec ${pkgs.uv}/bin/uv run --script ${gatewayScript} \
        ${mkProfileManifest profileName profile} ${lib.escapeShellArg profileName}
    '';

  narrowedServers = [ "serena" "chrome-devtools" "puppeteer" "atlassian" "openaiDeveloperDocs" "memory" ];
  repoScopedOnlyServers = [ "codebase-memory" ];

  # Codex (`[mcp_servers.<name>]` dict-of-tables) and Vibe (`[[mcp_servers]]`
  # array-of-tables keyed by a `name` field) use different TOML shapes for the
  # same concept -- mirrors the schema each already gets from
  # agent-configs.nix's restoreCodexUserConfig / vibe.nix's mergeScript, so
  # onboarding writes into the exact same structure those files expect.
  # Same shared `tomlkitPython` derivation vibe.nix's own tomlkit script uses
  # (hosts/shared/ai-agents-lib.nix) -- one declaration, no new closure.
  onboardPython = aiAgentsLib.tomlkitPython;

  onboardCodexScript = pkgs.writeText "mcp-profile-onboard-codex.py" ''
    import json
    import sys

    import tomlkit

    config_path, name, command = sys.argv[1], sys.argv[2], sys.argv[3]
    direct_entries = json.loads(sys.argv[4]) if len(sys.argv) > 4 else {}

    try:
        with open(config_path) as f:
            doc = tomlkit.parse(f.read())
    except FileNotFoundError:
        doc = tomlkit.document()

    servers = doc.get("mcp_servers")
    if servers is None:
        servers = tomlkit.table()
        doc["mcp_servers"] = servers

    if direct_entries:
        if name in servers:
            del servers[name]

        for server_name, server in direct_entries.items():
            table = tomlkit.table()
            for key, value in server.items():
                table[key] = value
            servers[server_name] = table
    else:
        table = tomlkit.table()
        table["command"] = command
        servers[name] = table

    with open(config_path, "w") as f:
        f.write(tomlkit.dumps(doc))
  '';

  onboardVibeScript = pkgs.writeText "mcp-profile-onboard-vibe.py" ''
    import sys

    import tomlkit

    config_path, name, command = sys.argv[1], sys.argv[2], sys.argv[3]

    try:
        with open(config_path) as f:
            doc = tomlkit.parse(f.read())
    except FileNotFoundError:
        doc = tomlkit.document()

    existing = doc.get("mcp_servers", [])
    kept = [item for item in existing if item.get("name") != name]

    array = tomlkit.aot()
    for item in kept:
        array.append(item)

    table = tomlkit.table()
    table["name"] = name
    table["transport"] = "stdio"
    table["command"] = command
    array.append(table)

    doc["mcp_servers"] = array

    with open(config_path, "w") as f:
        f.write(tomlkit.dumps(doc))
  '';

  offboardCodexScript = pkgs.writeText "mcp-profile-offboard-codex.py" ''
    import json
    import os
    import sys

    import tomlkit

    config_path, name, tracked_mode = sys.argv[1], sys.argv[2], sys.argv[3]
    direct_entries = json.loads(sys.argv[4]) if len(sys.argv) > 4 else {}
    tracked = tracked_mode == "tracked"

    try:
        with open(config_path) as f:
            doc = tomlkit.parse(f.read())
    except FileNotFoundError:
        print("missing")
        raise SystemExit(0)

    changed = False
    servers = doc.get("mcp_servers")
    names = [name] + list(direct_entries.keys())
    if servers is not None:
        for server_name in names:
            if server_name in servers:
                del servers[server_name]
                changed = True

        if len(list(servers.keys())) == 0:
            del doc["mcp_servers"]

    rendered = tomlkit.dumps(doc).strip()
    if rendered == "":
        if tracked:
            print("restore-tracked" if changed else "empty")
            raise SystemExit(0)
        os.remove(config_path)
        print("deleted" if changed else "empty")
        raise SystemExit(0)

    with open(config_path, "w") as f:
        f.write(tomlkit.dumps(doc))

    print("updated" if changed else "unchanged")
  '';
in
{
  home.packages =
    (map (name: mkProfileBinary name profiles.${name}) profileNames)
    ++ [
      (pkgs.writeShellScriptBin "mcp-profile-status" ''
        set -euo pipefail

        echo "Declared MCP profiles (aiAgents.mcpProfiles) -- each is spawned fresh per"
        echo "invocation, never a persistent or shared process (no cross-repo process"
        echo "sharing by design; see hosts/shared/ai-agents.nix for the full rationale):"
        echo
        ${lib.concatMapStringsSep "\n" (name: ''
          echo "  mcp-profile-${name}"
          echo "    servers: ${lib.concatStringsSep ", " profiles.${name}.servers}"
          ${optionalString (profiles.${name}.description != "") ''
            echo "    ${profiles.${name}.description}"
          ''}
        '') profileNames}
        echo "Not natively registered for any client by default (aiAgents.mcpServers"
        echo "targets = [ ]) -- reachable only via one of the profiles above:"
        echo "  ${lib.concatStringsSep ", " narrowedServers}"
        echo
        echo "Repo-scoped only (declared in aiAgents, but not native/profile-loaded):"
        echo "  ${lib.concatStringsSep ", " repoScopedOnlyServers}"
        echo "  Register these in project-native MCP config with scoped per-repo state."
        echo
        echo "Reference a profile's binary from a repo's own project-native MCP config to"
        echo "opt in -- run 'mcp-profile-onboard <profile> [repo-dir]' to do this without"
        echo "committing your personal profile choice into that repo (see its own --help/output"
        echo "for the per-client mechanism), or by hand, e.g.:"
        echo '  .cursor/mcp.json: { "mcpServers": { "nix-dotfiles": { "command": "mcp-profile-nix-dotfiles" } } }'
        echo
        echo "Codex OAuth note: profiles that contain OAuth HTTP servers are written as"
        echo "direct Codex HTTP MCP entries instead of stdio profile proxies. Example:"
        echo "  mcp-profile-onboard atlassian <repo>"
        echo "  codex mcp login atlassian"
      '')

      # Wires a profile into a target repo's own project-native MCP config
      # *without* ever putting your personal profile choice in a commit or the
      # shared .gitignore -- the two are genuinely different concerns from
      # "is this server useful to the whole team" (that's the `targets`/
      # `mcpProfiles.<name>.servers` schema above, still an explicit,
      # reviewed, committed decision when that's what's wanted). Per client:
      #   - Claude Code has a real private-per-project scope built in
      #     (`claude mcp add`'s default `local` scope, stored in ~/.claude.json
      #     keyed by this repo's path) -- zero repo footprint, nothing to hide.
      #   - Cursor/Codex/Vibe have no such scope: their project config
      #     (.cursor/mcp.json, .codex/config.toml, .vibe/config.toml) is either
      #     absent (write it, then list it in .git/info/exclude -- a per-clone
      #     ignore list that lives inside .git/ itself, never touches the
      #     shared .gitignore, invisible to `git status`/diffs/PRs) or already
      #     tracked/shared (mark it `--skip-worktree` instead, so git ignores
      #     your local edit to that one file without altering its history or
      #     your teammates' copies).
      (pkgs.writeShellScriptBin "mcp-profile-onboard" ''
        set -euo pipefail

        known_profiles="${lib.concatStringsSep " " profileNames}"
        skip_claude=0

        while [ "$#" -gt 0 ]; do
          case "$1" in
            --skip-claude)
              skip_claude=1
              shift
              ;;
            --help|-h)
              echo "Usage: mcp-profile-onboard [--skip-claude] <profile> [repo-dir]" >&2
              echo "Known profiles: $known_profiles" >&2
              exit 0
              ;;
            --)
              shift
              break
              ;;
            -*)
              echo "Unknown option: $1" >&2
              echo "Usage: mcp-profile-onboard [--skip-claude] <profile> [repo-dir]" >&2
              exit 1
              ;;
            *)
              break
              ;;
          esac
        done

        profile="''${1:-}"
        repo_dir="''${2:-.}"

        if [ -z "$profile" ]; then
          echo "Usage: mcp-profile-onboard [--skip-claude] <profile> [repo-dir]" >&2
          echo "Known profiles: $known_profiles" >&2
          exit 1
        fi
        case " $known_profiles " in
          *" $profile "*) ;;
          *)
            echo "Unknown profile '$profile'. Known profiles: $known_profiles" >&2
            exit 1
            ;;
        esac

        binary="mcp-profile-$profile"
        if ! command -v "$binary" >/dev/null 2>&1; then
          echo "$binary not on PATH -- run 'home-manager switch' first." >&2
          exit 1
        fi

        cd "$repo_dir"
        root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
          echo "$(pwd) is not inside a git repo -- this needs git for the untracked-locally" >&2
          echo "mechanism (.git/info/exclude / --skip-worktree) below." >&2
          exit 1
        }
        cd "$root"

        entry_name="$binary"
        codex_direct_json='{}'
        case "$profile" in
          ${codexDirectProfileCase}
        esac

        echo "==> Onboarding '$profile' ($binary) into $root -- kept private to this clone,"
        echo "    never committed, never touches the shared .gitignore"
        echo

        if [ "$skip_claude" -eq 1 ]; then
          echo "-- Claude Code --"
          echo "   skipped (--skip-claude)"
          echo
        elif command -v claude >/dev/null 2>&1; then
          echo "-- Claude Code (local scope: private, ~/.claude.json, zero repo footprint) --"
          claude_err="$(mktemp)"
          claude_status=0
          if ${pkgs.coreutils}/bin/timeout 15s \
            claude mcp add --transport stdio "$entry_name" -- "$binary" \
            >"$claude_err" 2>&1 < /dev/null; then
            echo "   added"
          else
            claude_status=$?
          fi

          if [ "$claude_status" -eq 124 ]; then
            echo "   warning: 'claude mcp add' timed out after 15s; rerun this repo manually or use --skip-claude in batch mode" >&2
          elif [ "$claude_status" -ne 0 ] && grep -qi "already exists" "$claude_err"; then
            echo "   already registered"
          elif [ "$claude_status" -ne 0 ]; then
            echo "   warning: 'claude mcp add' failed:" >&2
            cat "$claude_err" >&2
          else
            :
          fi
          rm -f "$claude_err"
          echo
        fi

        keep_private() {
          rel="$1"
          if git ls-files --error-unmatch "$rel" >/dev/null 2>&1; then
            git update-index --skip-worktree "$rel"
            echo "   $rel is tracked by the team -- marked --skip-worktree: your local edit never"
            echo "   shows in 'git status'/diffs/PRs (undo: git update-index --no-skip-worktree $rel)"
          else
            mkdir -p .git/info
            if ! grep -qxF "$rel" .git/info/exclude 2>/dev/null; then
              echo "$rel" >> .git/info/exclude
            fi
            echo "   $rel added to .git/info/exclude -- untracked, local-only, invisible to"
            echo "   'git status'/diffs/PRs (undo: remove that line, then 'rm $rel')"
          fi
        }

        echo "-- Cursor --"
        mkdir -p .cursor
        [ -f .cursor/mcp.json ] || echo '{}' > .cursor/mcp.json
        tmp="$(mktemp)"
        ${pkgs.jq}/bin/jq --arg key "$entry_name" --arg cmd "$binary" \
          '.mcpServers[$key] = {"command": $cmd}' .cursor/mcp.json > "$tmp" && mv "$tmp" .cursor/mcp.json
        keep_private ".cursor/mcp.json"
        echo

        echo "-- Codex --"
        mkdir -p .codex
        ${onboardPython}/bin/python3 ${onboardCodexScript} .codex/config.toml "$entry_name" "$binary" "$codex_direct_json"
        keep_private ".codex/config.toml"
        if [ "$codex_direct_json" != '{}' ]; then
          echo "   Codex uses direct HTTP MCP entries for this profile so native OAuth works."
          echo "   Run 'codex mcp login atlassian' from this repo, then start a new Codex session."
        fi
        echo

        echo "-- Vibe --"
        mkdir -p .vibe
        ${onboardPython}/bin/python3 ${onboardVibeScript} .vibe/config.toml "$entry_name" "$binary"
        keep_private ".vibe/config.toml"
        echo

        echo "Done. 'git status' in $root should show nothing new from this."
      '')

      (pkgs.writeShellScriptBin "mcp-profile-onboard-many" ''
        set -euo pipefail

        skip_claude=0
        known_profiles="${lib.concatStringsSep " " profileNames}"

        while [ "$#" -gt 0 ]; do
          case "$1" in
            --skip-claude)
              skip_claude=1
              shift
              ;;
            --help|-h)
              echo "Usage: mcp-profile-onboard-many [--skip-claude] <profile> <root-dir>" >&2
              echo "Known profiles: $known_profiles" >&2
              exit 0
              ;;
            --)
              shift
              break
              ;;
            -*)
              echo "Unknown option: $1" >&2
              echo "Usage: mcp-profile-onboard-many [--skip-claude] <profile> <root-dir>" >&2
              exit 1
              ;;
            *)
              break
              ;;
          esac
        done

        profile="''${1:-}"
        root_dir="''${2:-.}"

        if [ -z "$profile" ] || [ -z "$root_dir" ]; then
          echo "Usage: mcp-profile-onboard-many [--skip-claude] <profile> <root-dir>" >&2
          echo "Known profiles: $known_profiles" >&2
          exit 1
        fi

        case " $known_profiles " in
          *" $profile "*) ;;
          *)
            echo "Unknown profile '$profile'. Known profiles: $known_profiles" >&2
            exit 1
            ;;
        esac

        root_dir="$(${pkgs.coreutils}/bin/realpath "$root_dir")"

        total=0
        ok=0
        failed=0

        while IFS= read -r -d "" gitdir; do
          repo="''${gitdir%/.git}"
          total=$((total + 1))
          echo "==> $repo"
          if [ "$skip_claude" -eq 1 ]; then
            if mcp-profile-onboard --skip-claude "$profile" "$repo" < /dev/null; then
              ok=$((ok + 1))
            else
              failed=$((failed + 1))
              echo "FAILED: $repo" >&2
            fi
          elif mcp-profile-onboard "$profile" "$repo" < /dev/null; then
            ok=$((ok + 1))
          else
            failed=$((failed + 1))
            echo "FAILED: $repo" >&2
          fi
          echo
        done < <(${pkgs.findutils}/bin/find "$root_dir" -name .git -type d -prune -print0)

        echo "Done. repos=$total ok=$ok failed=$failed"
      '')

      (pkgs.writeShellScriptBin "mcp-profile-offboard-codex" ''
        set -euo pipefail

        known_profiles="${lib.concatStringsSep " " profileNames}"
        profile="''${1:-}"
        repo_dir="''${2:-.}"

        if [ -z "$profile" ]; then
          echo "Usage: mcp-profile-offboard-codex <profile> [repo-dir]" >&2
          echo "Known profiles: $known_profiles" >&2
          exit 1
        fi
        case " $known_profiles " in
          *" $profile "*) ;;
          *)
            echo "Unknown profile '$profile'. Known profiles: $known_profiles" >&2
            exit 1
            ;;
        esac

        binary="mcp-profile-$profile"
        entry_name="$binary"
        codex_direct_json='{}'
        case "$profile" in
          ${codexDirectProfileCase}
        esac

        cd "$repo_dir"
        root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
          echo "$(pwd) is not inside a git repo." >&2
          exit 1
        }
        cd "$root"

        config_rel=".codex/config.toml"
        config_path="$root/$config_rel"
        tracked_mode="untracked"
        if git ls-files --error-unmatch "$config_rel" >/dev/null 2>&1; then
          tracked_mode="tracked"
        fi

        status="$(${onboardPython}/bin/python3 ${offboardCodexScript} "$config_path" "$entry_name" "$tracked_mode" "$codex_direct_json")"

        case "$status" in
          missing)
            echo "No $config_rel in $root"
            ;;
          updated)
            echo "Removed $entry_name from $config_rel in $root"
            ;;
          unchanged)
            echo "$entry_name not present in $config_rel in $root"
            ;;
          deleted)
            echo "Removed $entry_name and deleted empty $config_rel in $root"
            ;;
          empty)
            echo "$config_rel already empty in $root"
            ;;
          restore-tracked)
            if git show "HEAD:$config_rel" > "$config_path" 2>/dev/null; then
              echo "Restored tracked $config_rel in $root to committed HEAD version after removing $entry_name"
            else
              echo "Failed to restore tracked $config_rel from HEAD in $root" >&2
              exit 1
            fi
            ;;
          *)
            echo "Unexpected status '$status' from codex offboard helper" >&2
            exit 1
            ;;
        esac

        if git ls-files --error-unmatch "$config_rel" >/dev/null 2>&1; then
          git update-index --no-skip-worktree "$config_rel" >/dev/null 2>&1 || true
        else
          if [ ! -e "$config_rel" ] && [ -f .git/info/exclude ]; then
            tmp="$(mktemp)"
            ${pkgs.gnugrep}/bin/grep -vxF "$config_rel" .git/info/exclude > "$tmp" || true
            mv "$tmp" .git/info/exclude
          fi
        fi
      '')

      (pkgs.writeShellScriptBin "mcp-profile-offboard-codex-many" ''
        set -euo pipefail

        known_profiles="${lib.concatStringsSep " " profileNames}"
        profile="''${1:-}"
        root_dir="''${2:-.}"

        if [ -z "$profile" ] || [ -z "$root_dir" ]; then
          echo "Usage: mcp-profile-offboard-codex-many <profile> <root-dir>" >&2
          echo "Known profiles: $known_profiles" >&2
          exit 1
        fi

        root_dir="$(${pkgs.coreutils}/bin/realpath "$root_dir")"

        while IFS= read -r -d "" gitdir; do
          repo="''${gitdir%/.git}"
          mcp-profile-offboard-codex "$profile" "$repo"
        done < <(${pkgs.findutils}/bin/find "$root_dir" -name .git -type d -prune -print0)
      '')
    ];
}
