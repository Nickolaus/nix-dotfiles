{ config, lib, pkgs, ... }:
let
  inherit (lib)
    mkAliasOptionModule
    mkEnableOption
    mkOption
    types
    ;

  clientType = types.enum [ "codex" "claude" "cursor" "vibe" ];

  # Servers that stay natively registered for all 4 clients (targets unchanged
  # below): universal, cheap, no meaningful downside to loading every session.
  # Everything else is `targets = [ ]` (defined, but not natively pushed to any
  # client) and reachable only by explicitly opting into one of the
  # `mcpProfiles` below -- see that option's own comment for why. Every
  # profile that needs the "generally useful anywhere" baseline extends this
  # list instead of re-declaring it, so the two never drift apart.
  defaultProfileServers = [
    "context7"
    "fetch"
    "sequential-thinking"
    "time"
    "github"
    "codebase-memory"
    "headroom"
  ];

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
        # Single-purpose (OpenAI API docs only) -- not natively registered,
        # reachable via aiAgents.mcpProfiles.openai-api.
        openaiDeveloperDocs = {
          type = "http";
          url = "https://developers.openai.com/mcp";
          targets = [ ];
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
        # Browser automation -- not natively registered, reachable together via
        # aiAgents.mcpProfiles.web.
        chrome-devtools = {
          type = "stdio";
          command = "${pkgs.nodejs}/bin/npx";
          args = [ "-y" "chrome-devtools-mcp@latest" ];
          targets = [ ];
        };
        puppeteer = {
          type = "stdio";
          command = "${pkgs.nodejs}/bin/npx";
          args = [ "-y" "puppeteer-mcp-server@latest" ];
          isolateWorkingDirectory = true;
          targets = [ ];
        };
        fetch = {
          type = "stdio";
          command = "${pkgs.uv}/bin/uvx";
          args = [ "mcp-server-fetch" ];
        };
        # @modelcontextprotocol/server-memory defaults to storing memory.jsonl
        # next to its own installed package, not per-repo -- it's already a
        # single global scratchpad shared across every repo/client regardless
        # of targets here. That surprising global-by-default behavior is why
        # it stays an explicit opt-in (aiAgents.mcpProfiles.scratchpad) rather
        # than natively loaded everywhere.
        memory = {
          type = "stdio";
          command = "${pkgs.nodejs}/bin/npx";
          args = [ "-y" "@modelcontextprotocol/server-memory" ];
          targets = [ ];
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
        # Single-purpose (Jira/Confluence) -- not natively registered,
        # reachable via aiAgents.mcpProfiles.atlassian.
        atlassian = {
          type = "http";
          url = "https://mcp.atlassian.com/v1/mcp/authv2";
          targets = [ ];
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
        # Heaviest tool surface + slowest startup (LSP indexing) of any server
        # here -- only valuable during active code-navigation sessions, not
        # every session. Not natively registered, reachable via
        # aiAgents.mcpProfiles.nix-dotfiles (or any other profile that opts
        # in). Profile rendering uses this base definition as-is (the
        # targetOverrides below are keyed by codex/claude/cursor/vibe and only
        # ever apply to those 4 native renderers, never to the profile
        # gateway) -- i.e. every profile gets the `--context=codex` variant.
        serena = {
          type = "stdio";
          command = "serena";
          args = [ "start-mcp-server" "--project-from-cwd" "--context=codex" "--open-web-dashboard" "False" ];
          startupTimeoutSec = 15;
          targets = [ ];
          targetOverrides = {
            claude.args = [ "start-mcp-server" "--context=claude-code" "--project-from-cwd" "--open-web-dashboard" "False" ];
            cursor.args = [ "start-mcp-server" "--context=ide" "--project-from-cwd" "--open-web-dashboard" "False" ];
          };
        };
      };
      description = "Neutral cross-tool MCP server definitions rendered for each supported agent.";
    };

    mcpProfiles = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          servers = mkOption {
            type = types.listOf types.str;
            description = "Names of aiAgents.mcpServers entries aggregated into this profile.";
          };

          description = mkOption {
            type = types.str;
            default = "";
            description = "Human-readable description shown by mcp-profile-status.";
          };
        };
      });
      default = {
        default = {
          servers = defaultProfileServers;
          description = "Universal baseline -- mirrors the servers natively registered for all 4 clients.";
        };
        nix-dotfiles = {
          servers = defaultProfileServers ++ [ "serena" ];
          description = "Editing this repo -- adds Nix-aware LSP code navigation.";
        };
        web = {
          servers = defaultProfileServers ++ [ "chrome-devtools" "puppeteer" ];
          description = "Browser automation / frontend work.";
        };
        atlassian = {
          servers = defaultProfileServers ++ [ "atlassian" ];
          description = "Jira/Confluence-integrated repos.";
        };
        openai-api = {
          servers = defaultProfileServers ++ [ "openaiDeveloperDocs" ];
          description = "OpenAI API integration work.";
        };
        scratchpad = {
          servers = defaultProfileServers ++ [ "memory" ];
          description = "Opt-in cross-repo notes -- memory.jsonl is global by upstream design, not per-repo.";
        };
      };
      description = ''
        Named, on-demand compositions of aiAgents.mcpServers, aggregated by a
        FastMCP proxy (home/features/ai/mcp-profiles.nix -- one
        `mcp-profile-<name>` binary per entry here) into a single stdio
        endpoint. Each profile is spawned fresh per client invocation --
        never a persistent or shared process, so member servers keep the
        same per-invocation isolation they already have today (see the MCP
        gateway sharing discussion this option's design is based on).
        Independent of each server's `targets`/`enabled` fields: those
        govern direct native registration into the 4 clients above, profiles
        are a separate, explicit opt-in -- the two mechanisms together are
        how a server goes "off by default, on via profile" (see
        `defaultProfileServers` and the six servers above with
        `targets = [ ]`). A repo pulls a profile in with one committed
        stdio entry in its own project-native MCP config (`.mcp.json`,
        `.cursor/mcp.json`, `.codex/config.toml`, `.vibe/config.toml`),
        e.g. `{ "command": "mcp-profile-nix-dotfiles" }`.
      '';
    };

    localCoding = {
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

    claude.managed.settings = mkOption {
      type = types.attrs;
      default = { };
      description = ''
        Structured contents for Claude Code's managed-settings.json (macOS:
        /Library/Application Support/ClaudeCode/managed-settings.json; Linux:
        /etc/claude-code/managed-settings.json), written when `claude.managed.enable`
        is true. Empty by default: a managed policy takes precedence over even
        user settings, so forcing ANTHROPIC_BASE_URL/AUTH_TOKEN/API_KEY/model
        here for local-Ollama routing would silently disable claude.ai
        subscription connectors and Remote Control for anyone the policy
        applies to, with no easy user-level override (see
        home/features/ai/agent-configs.nix for the same trade-off already made
        at the user-settings layer). Claude Code has no local-coding route at
        all -- unlike Codex/OpenCode, it has no native multi-provider config,
        and a wrapper script would still race with other local-coding
        consumers for the single-loaded-model backend (see
        home/features/ai/ollama.nix, aiAgents.headroom.proxies.shared).
      '';
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
        # Codex's real-OpenAI traffic, compressed. `openaiTargetUrl` is left null
        # (Headroom's own default: real OpenAI) -- only `anthropicTargetUrl` or
        # `openaiTargetUrl` need setting here, and only when routing that wire
        # protocol somewhere other than the real provider.
        shared = {
          port = 8787;
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
        config.aiAgents.mcpServers
      ++ lib.concatMap
        (profileName:
          let
            profile = config.aiAgents.mcpProfiles.${profileName};
            unknown = builtins.filter (s: !(config.aiAgents.mcpServers ? ${s})) profile.servers;
          in
          [{
            assertion = unknown == [ ];
            message =
              "aiAgents.mcpProfiles.${profileName}.servers references unknown aiAgents.mcpServers: "
              + builtins.concatStringsSep ", " unknown;
          }])
        (builtins.attrNames config.aiAgents.mcpProfiles);
  };
}
