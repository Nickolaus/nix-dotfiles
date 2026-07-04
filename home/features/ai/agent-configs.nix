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

  claudeSettings = {
    model = aiCfg.localCoding.model;
    env = {
      # Mirrors hosts/shared/claude-code.nix's managed-settings.json: routes through the
      # always-on Headroom compression proxy (home/features/ai/headroom.nix,
      # aiAgents.headroom.proxies.shared -- single source of truth), which forwards on to
      # this same `aiCfg.localCoding.anthropicBaseUrl` -- same free/local Ollama
      # destination as before, now compressed by default.
      ANTHROPIC_BASE_URL = aiCfg.headroom.proxies.shared.url;
      ANTHROPIC_AUTH_TOKEN = "ollama";
      ANTHROPIC_API_KEY = "";
    };
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
in
{
  home.file =
    lib.optionalAttrs (aiCfg != null && aiCfg.enable && aiCfg.targets.claude.enable)
      {
        ".claude/settings.json".text = builtins.toJSON claudeSettings;
        ".claude/ai-agents-mcp.json".text = builtins.toJSON claudeMcpSettings;
      }
    // lib.optionalAttrs (aiCfg != null && aiCfg.enable && aiCfg.targets.cursor.enable) {
      ".cursor/mcp.json".text = builtins.toJSON cursorMcpSettings;
    };

  home.activation.mergeClaudeUserMcp =
    lib.mkIf (aiCfg != null && aiCfg.enable && aiCfg.targets.claude.enable)
      (lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        claude_state_file="${config.home.homeDirectory}/.claude.json"
        generated_mcp_file="${config.home.homeDirectory}/.claude/ai-agents-mcp.json"
        tmp_file="$(mktemp)"

        if [ -f "$claude_state_file" ]; then
          if ! ${pkgs.jq}/bin/jq empty "$claude_state_file" >/dev/null 2>&1; then
            echo "warning: $claude_state_file is not valid JSON; skipping aiAgents MCP merge for Claude Code" >&2
            rm -f "$tmp_file"
          else
            ${pkgs.jq}/bin/jq --slurpfile generated "$generated_mcp_file" \
              '.mcpServers = ($generated[0].mcpServers // {})' \
              "$claude_state_file" > "$tmp_file"
            mv "$tmp_file" "$claude_state_file"
          fi
        else
          ${pkgs.jq}/bin/jq -n --slurpfile generated "$generated_mcp_file" \
            '{ mcpServers: ($generated[0].mcpServers // {}) }' > "$tmp_file"
          mv "$tmp_file" "$claude_state_file"
        fi
      '');

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

          ${pkgs.gawk}/bin/awk -v managed_names=${lib.escapeShellArg codexManagedMcpServerNamesShell} '
            BEGIN {
              split(managed_names, names, " ")
              for (idx in names) {
                if (names[idx] != "") {
                  managed[names[idx]] = 1
                }
              }
            }

            function is_managed_mcp_table(line, inner, parts) {
              if (line !~ /^\[mcp_servers\./) {
                return 0
              }

              inner = line
              sub(/^\[mcp_servers\./, "", inner)
              sub(/\]$/, "", inner)
              split(inner, parts, ".")

              return parts[1] in managed
            }

            /^\[/ {
              skip = is_managed_mcp_table($0)
            }

            !skip {
              print
            }
          ' "$codex_config" > "$tmp_file"

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
