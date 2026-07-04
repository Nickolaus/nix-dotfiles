{ config, lib, pkgs, ... }:
let
  inherit (lib)
    mkAliasOptionModule
    mkEnableOption
    mkOption
    types
    ;

  clientType = types.enum [ "codex" "claude" "cursor" "vibe" ];

  mcpServerTargetOverrideType = types.submodule ({ ... }: {
    options = {
      type = mkOption {
        type = types.nullOr (types.enum [ "http" "stdio" ]);
        default = null;
        description = "Target-specific MCP transport type override.";
      };

      url = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Target-specific HTTP endpoint override.";
      };

      command = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Target-specific stdio command override.";
      };

      args = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = "Target-specific stdio arguments override.";
      };

      env = mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "Target-specific environment variables merged with the base environment.";
      };

      isolateWorkingDirectory = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = "Target-specific isolated working directory override.";
      };

      workingDirectory = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Target-specific working directory override.";
      };

      headers = mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "Target-specific HTTP headers merged with the base headers.";
      };

      bearerTokenEnvVar = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Target-specific bearer token environment variable override.";
      };

      inheritEnv = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = "Target-specific inherited environment variable override.";
      };

      startupTimeoutSec = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Target-specific MCP startup timeout override where supported.";
      };
    };
  });

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

      isolateWorkingDirectory = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to launch this stdio MCP server from a stable per-server state directory instead of the invoking project directory.";
      };

      workingDirectory = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Explicit working directory for stdio MCP servers. When unset and isolateWorkingDirectory is enabled, a per-server state directory is used.";
      };

      headers = mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "Static headers for HTTP MCP servers.";
      };

      bearerTokenEnvVar = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Environment variable containing a bearer token for HTTP MCP servers that require bearer-token authentication.";
      };

      inheritEnv = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Environment variable names that should be inherited from the surrounding user session.";
      };

      startupTimeoutSec = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "MCP server startup timeout in seconds for clients that support it.";
      };

      targets = mkOption {
        type = types.listOf clientType;
        default = [ "codex" "claude" "cursor" "vibe" ];
        description = "Agent clients that should receive this MCP definition.";
      };

      targetOverrides = mkOption {
        type = types.submodule ({ ... }: {
          options = {
            codex = mkOption {
              type = mcpServerTargetOverrideType;
              default = { };
              description = "Codex-specific MCP server overrides.";
            };

            claude = mkOption {
              type = mcpServerTargetOverrideType;
              default = { };
              description = "Claude Code-specific MCP server overrides.";
            };

            cursor = mkOption {
              type = mcpServerTargetOverrideType;
              default = { };
              description = "Cursor-specific MCP server overrides.";
            };

            vibe = mkOption {
              type = mcpServerTargetOverrideType;
              default = { };
              description = "Vibe-specific MCP server overrides.";
            };
          };
        });
        default = { };
        description = "Target-specific MCP server overrides. Scalars and lists replace base values; env and headers merge.";
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

      vibe.enable = mkEnableOption "Mistral Vibe configuration rendering" // {
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
          type = "http";
          url = "https://api.githubcopilot.com/mcp/";
          bearerTokenEnvVar = "GITHUB_MCP_PAT";
        };
        chrome-devtools = {
          type = "stdio";
          command = "${pkgs.nodejs}/bin/npx";
          args = [ "-y" "chrome-devtools-mcp@latest" ];
        };
        puppeteer = {
          type = "stdio";
          command = "${pkgs.nodejs}/bin/npx";
          args = [ "-y" "puppeteer-mcp-server@latest" ];
          isolateWorkingDirectory = true;
          targets = [ "codex" "vibe" ];
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
          type = "http";
          url = "https://mcp.atlassian.com/v1/mcp/authv2";
        };
        codebase-memory = {
          type = "stdio";
          command = "codebase-memory-mcp";
        };
        headroom = {
          type = "stdio";
          command = "${pkgs.uv}/bin/uvx";
          args = [ "--from" "headroom-ai[mcp]" "headroom" "mcp" "serve" ];
        };
        serena = {
          type = "stdio";
          command = "serena";
          args = [ "start-mcp-server" "--project-from-cwd" "--context=codex" "--open-web-dashboard" "False" ];
          startupTimeoutSec = 15;
          targetOverrides = {
            claude.args = [ "start-mcp-server" "--context=claude-code" "--project-from-cwd" "--open-web-dashboard" "False" ];
            cursor.args = [ "start-mcp-server" "--context=ide" "--project-from-cwd" "--open-web-dashboard" "False" ];
          };
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
      default = true;
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

    headroom.proxies = mkOption {
      type = types.attrsOf (types.submodule ({ config, ... }: {
        options = {
          port = mkOption {
            type = types.port;
            description = "Port this Headroom compression-proxy instance (home/features/ai/headroom.nix) binds to.";
          };

          url = mkOption {
            type = types.str;
            readOnly = true;
            default = "http://127.0.0.1:${toString config.port}";
            description = "Full base URL for this proxy instance, derived from `port`.";
          };

          anthropicTargetUrl = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = ''
              Upstream for the Anthropic-wire route (/v1/messages). Null
              leaves Headroom's own default (real Anthropic) in place.
            '';
          };

          openaiTargetUrl = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = ''
              Upstream for the OpenAI-compatible wire routes
              (/v1/chat/completions, /v1/responses). Null leaves Headroom's
              own default (real OpenAI) in place.
            '';
          };
        };
      }));
      default = {
        # Claude Code + Codex: a single `headroom proxy` process handles both,
        # since one process happily serves *different* wire protocols
        # (Anthropic Messages for Claude, OpenAI-compatible for Codex) on the
        # same port simultaneously -- it only ever has *one* upstream per
        # protocol, which is why this can't also carry Vibe's traffic below.
        shared = {
          port = 8787;
          anthropicTargetUrl = config.aiAgents.localCoding.anthropicBaseUrl;
        };
        # Vibe's Mistral Cloud traffic needs its own instance/port: it's also
        # OpenAI-compatible wire format, but to a *different* upstream than
        # Codex's real OpenAI, and a single proxy process only ever forwards
        # that route to one place.
        vibe = {
          port = 8788;
          openaiTargetUrl = "https://api.mistral.ai";
        };
      };
      description = ''
        Declarative registry of Headroom compression-proxy instances
        (home/features/ai/headroom.nix): one launchd-managed process/port per
        attrset entry. headroom.nix itself has zero per-tool knowledge -- it
        just spins up whatever's declared here -- so onboarding a future
        provider that needs OpenAI/Anthropic-wire compression to a
        *different* upstream than the ones already covered is exactly one
        new attrset entry here, plus pointing that consumer's own base-URL
        config at `<entry>.url`, never a change to headroom.nix itself.
        Every consumer (hosts/shared/claude-code.nix, codex.nix,
        home/features/ai/agent-configs.nix, vibe.nix) reads its proxy's URL
        from here, so each one is only ever defined once.
      '';
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
        config.aiAgents.mcpServers
      ++ lib.mapAttrsToList
        (name: server: {
          assertion = server.type == "stdio" || (!server.isolateWorkingDirectory && server.workingDirectory == null);
          message = "aiAgents.mcpServers.${name}.isolateWorkingDirectory and workingDirectory are only supported for stdio MCP servers.";
        })
        config.aiAgents.mcpServers
      ++ lib.mapAttrsToList
        (name: server: {
          assertion = server.workingDirectory == null || builtins.substring 0 1 server.workingDirectory == "/";
          message = "aiAgents.mcpServers.${name}.workingDirectory must be an absolute path.";
        })
        config.aiAgents.mcpServers;
  };
}
