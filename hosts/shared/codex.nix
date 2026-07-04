{ config, lib, pkgs, ... }:
let
  inherit (lib) filterAttrs mkIf mkMerge optionalAttrs;

  aiAgentsLib = import ./ai-agents-lib.nix { inherit lib pkgs; };
  tomlFormat = pkgs.formats.toml { };
  cfg = config.aiAgents;

  enabledMcpServers = filterAttrs (_: server: server.enabled && builtins.elem "codex" server.targets) cfg.mcpServers;

  renderCodexMcpServer = name: rawServer:
    let
      server = aiAgentsLib.effectiveServerFor "codex" rawServer;
    in
    (if server.type == "http" then
      {
        url = server.url;
      } // optionalAttrs (server.headers != { }) {
        http_headers = server.headers;
      } // optionalAttrs (server.bearerTokenEnvVar != null) {
        bearer_token_env_var = server.bearerTokenEnvVar;
      }
    else
      aiAgentsLib.renderStdioCommand name server
      // optionalAttrs (server.args != [ ]) {
        args = server.args;
      } // optionalAttrs (server.env != { }) {
        env = server.env;
      })
    // optionalAttrs (server.startupTimeoutSec != null) {
      startup_timeout_sec = server.startupTimeoutSec;
    };

  managedConfigSettings = {
    # Redirects the built-in "openai" provider (default `codex`, ChatGPT sign-in *or* an
    # API key -- either stays intact) through the always-on Headroom compression proxy
    # (home/features/ai/headroom.nix, aiAgents.headroom.proxies.shared -- single source of
    # truth). That proxy's own openaiTargetUrl is left at its real-OpenAI default, so this
    # is the same destination and auth as before, just compressed.
    # `openai_base_url` (as opposed to a custom `model_providers.*` entry, which requires
    # `env_key` and can't use ChatGPT sign-in) is what keeps the provider's identity
    # intact -- see https://developers.openai.com/codex/config-advanced.
    # Opt out: `headroom-pause`.
    openai_base_url = "${cfg.headroom.proxies.shared.url}/v1";

    shell_environment_policy.exclude = [
      "GH_TOKEN"
      "GITHUB_TOKEN"
      "GITHUB_PERSONAL_ACCESS_TOKEN"
      "CODEX_GITHUB_TOKEN"
    ];

    model_providers.local_coding_ollama = {
      name = "Ollama";
      base_url = cfg.localCoding.openaiBaseUrl;
    };

    mcp_servers = lib.mapAttrs renderCodexMcpServer enabledMcpServers;
  };
in
{
  config = mkIf (cfg.enable && cfg.targets.codex.enable && cfg.codex.managed.enable) (mkMerge [
    {
      environment.etc."codex/managed_config.toml".source =
        tomlFormat.generate "codex-managed-config.toml" managedConfigSettings;
    }
    (mkIf cfg.codex.requirements.enable {
      environment.etc."codex/requirements.toml".source =
        tomlFormat.generate "codex-requirements.toml" cfg.codex.requirements.settings;
    })
  ]);
}
