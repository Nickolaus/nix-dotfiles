{ config, lib, osConfig ? { }, pkgs, ... }:
let
  inherit (lib) filterAttrs optionalAttrs;

  aiAgentsLib = import ../../../hosts/shared/ai-agents-lib.nix { inherit lib pkgs; };

  aiCfg =
    if osConfig ? aiAgents then
      osConfig.aiAgents
    else
      null;

  cursorEnvRef = name: "\${env:${name}}";
  enabledMcpServers =
    if aiCfg != null then
      filterAttrs (_: server: server.enabled) aiCfg.mcpServers
    else
      { };

  serverEnabledFor = target: server: builtins.elem target server.targets;

  codexManagedMcpServers =
    filterAttrs (_: server: serverEnabledFor "codex" server) enabledMcpServers;

  codexManagedMcpServerNamesShell =
    lib.concatMapStringsSep " " lib.escapeShellArg (builtins.attrNames codexManagedMcpServers);

  renderEnvForCursor = server:
    server.env
    // builtins.listToAttrs (map
      (name: {
        inherit name;
        value = cursorEnvRef name;
      })
      server.inheritEnv);

  renderEnvForInheritedSession = server: server.env;

  # Codex gets bearer-token auth for HTTP MCP servers natively via
  # `bearer_token_env_var`. Claude Code and Cursor have no such field -- both
  # instead expand environment variable references inside literal `headers`
  # string values at startup, but with different placeholder syntax.
  claudeHeaderAuthRenderer = varName: "Bearer \${${varName}}";
  cursorHeaderAuthRenderer = varName: "Bearer \${env:${varName}}";

  renderMcpServerForJson = target: envRenderer: headerAuthRenderer: name: rawServer:
    let
      server = aiAgentsLib.effectiveServerFor target rawServer;
    in
    if server.type == "http" then
      {
        type = "http";
        url = server.url;
      } // optionalAttrs (server.headers != { } || server.bearerTokenEnvVar != null) {
        headers = server.headers // optionalAttrs (server.bearerTokenEnvVar != null) {
          Authorization = headerAuthRenderer server.bearerTokenEnvVar;
        };
      }
    else
      aiAgentsLib.renderStdioCommand name server
      // optionalAttrs (server.args != [ ]) {
        args = server.args;
      } // optionalAttrs ((envRenderer server) != { }) {
        env = envRenderer server;
      };

  cursorMcpSettings = {
    mcpServers = lib.mapAttrs (renderMcpServerForJson "cursor" renderEnvForCursor cursorHeaderAuthRenderer) (
      filterAttrs (_: server: serverEnabledFor "cursor" server) enabledMcpServers
    );
  };

  claudeMcpSettings = {
    mcpServers = lib.mapAttrs (renderMcpServerForJson "claude" renderEnvForInheritedSession claudeHeaderAuthRenderer) (
      filterAttrs (_: server: serverEnabledFor "claude" server) enabledMcpServers
    );
  };

  # Codex's real managed MCP servers live in a separate system file
  # (/etc/codex/managed_config.toml, hosts/shared/codex.nix) that Codex itself layers on
  # top -- this script only prunes stale `[mcp_servers.<name>]` tables a currently-managed
  # name might still hold in the user's own config.toml (e.g. left over from before that
  # name was narrowed out of targets). Delete-only, no insertion, so unlike Vibe's merge
  # (which must coexist with genuinely user-added entries) there's no state sidecar to
  # track "previously managed" -- a real TOML parse is enough to know exactly which table
  # belongs to which name, correctly handling shapes a naive `[mcp_servers.` line-match
  # can't (inline tables, quoted dotted keys, ...).
  codexPruneScript = pkgs.writeText "codex-prune-managed-mcp.py" ''
    import sys

    import tomlkit

    config_path, output_path, managed_names_str = sys.argv[1], sys.argv[2], sys.argv[3]
    managed_names = set(managed_names_str.split())

    with open(config_path) as f:
        doc = tomlkit.parse(f.read())

    servers = doc.get("mcp_servers")
    if servers is not None:
        for name in list(servers.keys()):
            if name in managed_names:
                del servers[name]

    with open(output_path, "w") as f:
        f.write(tomlkit.dumps(doc))
  '';
in
{
  home.file =
    # Deliberately does *not* touch `.claude/settings.json`: unlike Codex (whose managed
    # config only overrides `openai_base_url` for compression, never the default provider's
    # identity -- see hosts/shared/codex.nix), forcing ANTHROPIC_BASE_URL/AUTH_TOKEN/API_KEY
    # here would count as "another auth source" to Claude Code and silently disable a
    # logged-in claude.ai subscription's connectors, Remote Control, and subscription
    # billing. Claude Code has no local-coding route at all as a result -- OpenCode is the
    # one tool with a local-coding provider (home/features/ai/headroom.nix).
    #
    # `.claude/settings.json` has no single owner: besides not being managed here, it's
    # also written directly by third-party installers (e.g. an IDE's own Claude Code
    # plugin/hook installer) and by Claude Code's own CLI/settings persistence. Don't
    # assume Nix controls its contents when debugging it.
    lib.optionalAttrs (aiCfg != null && aiCfg.enable && aiCfg.targets.claude.enable)
      {
        ".claude/ai-agents-mcp.json".text = builtins.toJSON claudeMcpSettings;
      }
    // lib.optionalAttrs (aiCfg != null && aiCfg.enable && aiCfg.targets.cursor.enable) {
      ".cursor/mcp.json".text = builtins.toJSON cursorMcpSettings;
    };

  home.activation.mergeClaudeUserMcp =
    lib.mkIf (aiCfg != null && aiCfg.enable && aiCfg.targets.claude.enable)
      (lib.hm.dag.entryAfter [ "writeBoundary" ] (aiAgentsLib.mkJsonMergeActivation {
        configPath = "${config.home.homeDirectory}/.claude.json";
        jqArgName = "generated";
        jqFilter = ".mcpServers = ($generated[0].mcpServers // {})";
        valueFile = "${config.home.homeDirectory}/.claude/ai-agents-mcp.json";
        invalidJsonWarning = "warning: ~/.claude.json is not valid JSON; skipping aiAgents MCP merge for Claude Code";
      }));

  home.activation.restoreCodexUserConfig =
    lib.mkIf (aiCfg != null && aiCfg.enable && aiCfg.targets.codex.enable)
      (lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        codex_dir="${config.home.homeDirectory}/.codex"
        codex_config="$codex_dir/config.toml"
        codex_backup="$codex_dir/config.toml.backup"
        codex_prune_backup="$codex_dir/config.toml.pre-ai-agents-mcp-prune"

        mkdir -p "$codex_dir"

        if [ ! -e "$codex_config" ] && [ -f "$codex_backup" ]; then
          cp "$codex_backup" "$codex_config"
        fi

        if [ -f "$codex_config" ]; then
          tmp_file="$(mktemp)"

          ${aiAgentsLib.tomlkitPython}/bin/python3 ${codexPruneScript} \
            "$codex_config" "$tmp_file" ${lib.escapeShellArg codexManagedMcpServerNamesShell}

          if ! cmp -s "$tmp_file" "$codex_config"; then
            if [ ! -e "$codex_prune_backup" ]; then
              cp "$codex_config" "$codex_prune_backup"
              chmod 0600 "$codex_prune_backup" 2>/dev/null || true
            fi
            mv "$tmp_file" "$codex_config"
          else
            rm -f "$tmp_file"
          fi
        fi
      '');
}
