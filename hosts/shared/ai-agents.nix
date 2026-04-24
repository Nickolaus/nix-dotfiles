{ config, lib, pkgs, ... }:
let
  inherit (lib)
    mkAliasOptionModule
    mkEnableOption
    mkOption
    types
    ;

  clientType = types.enum [ "codex" "claude" "cursor" ];

  mcpServerType = types.submodule ({ ... }: {
    options = {
      enabled = mkOption {
        type = types.bool;
        default = true;
        description = "Whether this MCP server should be rendered for supported agent clients.";
      };

      type = mkOption {
        type = types.enum [ "http" "stdio" ];
        default = "http";
        description = "Neutral MCP transport type for per-tool renderers.";
      };

      url = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Streamable HTTP endpoint for HTTP MCP servers.";
      };

      command = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Command used to launch stdio MCP servers.";
      };

      args = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Arguments for stdio MCP servers.";
      };

      env = mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "Environment variables for stdio MCP servers.";
      };

      headers = mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "Static headers for HTTP MCP servers.";
      };

      inheritEnv = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Environment variable names that should be inherited from the surrounding user session.";
      };

      targets = mkOption {
        type = types.listOf clientType;
        default = [ "codex" "claude" "cursor" ];
        description = "Agent clients that should receive this MCP definition.";
      };
    };

  });
in
{
  imports = [
    (mkAliasOptionModule [ "codexManaged" "enable" ] [ "aiAgents" "codex" "managed" "enable" ])
    (mkAliasOptionModule [ "codexManaged" "homeManagerUser" ] [ "aiAgents" "homeManagerUser" ])
    (mkAliasOptionModule [ "codexManaged" "requirements" "enable" ] [ "aiAgents" "codex" "requirements" "enable" ])
    (mkAliasOptionModule [ "codexManaged" "requirements" "settings" ] [ "aiAgents" "codex" "requirements" "settings" ])
  ];

  options.aiAgents = {
    enable = mkEnableOption "shared AI agent defaults" // {
      default = true;
    };

    homeManagerUser = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Home Manager user whose localAi settings seed shared agent defaults.";
    };

    targets = {
      codex.enable = mkEnableOption "Codex configuration rendering" // {
        default = true;
      };

      claude.enable = mkEnableOption "Claude Code configuration rendering" // {
        default = true;
      };

      cursor.enable = mkEnableOption "Cursor configuration rendering" // {
        default = true;
      };
    };

    mcpServers = mkOption {
      type = types.attrsOf mcpServerType;
      default = {
        openaiDeveloperDocs = {
          type = "http";
          url = "https://developers.openai.com/mcp";
        };
        context7 = {
          type = "stdio";
          command = "${pkgs.nodejs}/bin/npx";
          args = [ "-y" "@upstash/context7-mcp" ];
          inheritEnv = [ "CONTEXT7_API_KEY" ];
        };
        github = {
          type = "stdio";
          command = "${pkgs.nodejs}/bin/npx";
          args = [ "-y" "@modelcontextprotocol/server-github" ];
          inheritEnv = [ "GITHUB_PERSONAL_ACCESS_TOKEN" ];
        };
        chrome-devtools = {
          type = "stdio";
          command = "${pkgs.nodejs}/bin/npx";
          args = [ "-y" "chrome-devtools-mcp@latest" ];
        };
        fetch = {
          type = "stdio";
          command = "${pkgs.uv}/bin/uvx";
          args = [ "mcp-server-fetch" ];
        };
        memory = {
          type = "stdio";
          command = "${pkgs.nodejs}/bin/npx";
          args = [ "-y" "@modelcontextprotocol/server-memory" ];
        };
        sequential-thinking = {
          type = "stdio";
          command = "${pkgs.nodejs}/bin/npx";
          args = [ "-y" "@modelcontextprotocol/server-sequential-thinking" ];
        };
        time = {
          type = "stdio";
          command = "${pkgs.uv}/bin/uvx";
          args = [ "mcp-server-time" ];
        };
        atlassian = {
          type = "stdio";
          command = "${pkgs.nodejs}/bin/npx";
          args = [ "-y" "mcp-remote@latest" "https://mcp.atlassian.com/v1/mcp" ];
        };
      };
      description = "Neutral cross-tool MCP server definitions rendered for each supported agent.";
    };

    localCoding = {
      openaiBaseUrl = mkOption {
        type = types.str;
        readOnly = true;
        description = "Shared OpenAI-compatible base URL for the local coding route.";
      };

      anthropicBaseUrl = mkOption {
        type = types.str;
        readOnly = true;
        description = "Shared Anthropic-compatible base URL for the local coding route.";
      };

      model = mkOption {
        type = types.str;
        readOnly = true;
        description = "Shared local coding model identifier.";
      };
    };

    codex.requirements = {
      enable = mkEnableOption "managed Codex requirements";

      settings = mkOption {
        type = types.attrs;
        default = { };
        description = "Structured contents for Codex requirements settings.";
      };
    };

    codex.managed.enable = mkEnableOption "system-managed Codex policy under /etc/codex" // {
      default = false;
    };

    claude.managedMcp = {
      enable = mkEnableOption "managed Claude Code MCP file";

      settings = mkOption {
        type = types.attrs;
        default = { };
        description = "Additional JSON merged into Claude Code's managed-mcp.json when enabled.";
      };
    };

    claude.managed.enable = mkEnableOption "system-managed Claude Code policy under the platform policy path" // {
      default = false;
    };
  };

  config = {
    assertions =
      lib.mapAttrsToList
        (name: server: {
          assertion =
            if server.type == "http" then
              server.url != null
            else
              server.command != null;
          message =
            if server.type == "http" then
              "aiAgents.mcpServers.${name}.url must be set for HTTP MCP servers."
            else
              "aiAgents.mcpServers.${name}.command must be set for stdio MCP servers.";
        })
        config.aiAgents.mcpServers;
  };
}
