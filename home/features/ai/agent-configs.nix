{ config, lib, osConfig ? { }, pkgs, ... }:
let
  inherit (lib) filterAttrs optionalAttrs;

  aiCfg =
    if osConfig ? aiAgents then
      osConfig.aiAgents
    else
      null;

  tomlFormat = pkgs.formats.toml { };

  cursorEnvRef = name: "\${env:${name}}";
  enabledMcpServers =
    if aiCfg != null then
      filterAttrs (_: server: server.enabled) aiCfg.mcpServers
    else
      { };

  serverEnabledFor = target: server: builtins.elem target server.targets;

  renderEnvForCursor = server:
    server.env
    // builtins.listToAttrs (map (name: {
      inherit name;
      value = cursorEnvRef name;
    }) server.inheritEnv);

  renderEnvForInheritedSession = server: server.env;

  renderMcpServerForCodex = _name: server:
    if server.type == "http" then
      {
        url = server.url;
      } // optionalAttrs (server.headers != { }) {
        http_headers = server.headers;
      }
    else
      {
        command = server.command;
      } // optionalAttrs (server.args != [ ]) {
        args = server.args;
      } // optionalAttrs (server.env != { }) {
        env = server.env;
      };

  renderMcpServerForJson = envRenderer: _name: server:
    if server.type == "http" then
      {
        type = "http";
        url = server.url;
      } // optionalAttrs (server.headers != { }) {
        headers = server.headers;
      }
    else
      {
        command = server.command;
      } // optionalAttrs (server.args != [ ]) {
        args = server.args;
      } // optionalAttrs ((envRenderer server) != { }) {
        env = envRenderer server;
      };

  codexConfig = {
    model_providers.local_coding_ollama = {
      name = "Ollama";
      base_url = aiCfg.localCoding.openaiBaseUrl;
    };

    profiles.local-coding = {
      model = aiCfg.localCoding.model;
      model_provider = "local_coding_ollama";
    };

    mcp_servers = lib.mapAttrs renderMcpServerForCodex (
      filterAttrs (_: server: serverEnabledFor "codex" server) enabledMcpServers
    );
  };

  claudeSettings = {
    model = aiCfg.localCoding.model;
    env = {
      ANTHROPIC_BASE_URL = aiCfg.localCoding.anthropicBaseUrl;
      ANTHROPIC_AUTH_TOKEN = "ollama";
      ANTHROPIC_API_KEY = "";
    };
  };

  cursorMcpSettings = {
    mcpServers = lib.mapAttrs (renderMcpServerForJson renderEnvForCursor) (
      filterAttrs (_: server: serverEnabledFor "cursor" server) enabledMcpServers
    );
  };

  claudeMcpSettings = {
    mcpServers = lib.mapAttrs (renderMcpServerForJson renderEnvForInheritedSession) (
      filterAttrs (_: server: serverEnabledFor "claude" server) enabledMcpServers
    );
  };
in
{
  home.file =
    lib.optionalAttrs (aiCfg != null && aiCfg.enable && aiCfg.targets.codex.enable) {
      ".codex/config.toml".source = tomlFormat.generate "codex-config.toml" codexConfig;
    }
    // lib.optionalAttrs (aiCfg != null && aiCfg.enable && aiCfg.targets.claude.enable) {
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
}
