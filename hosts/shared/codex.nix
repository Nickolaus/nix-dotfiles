{ config, lib, pkgs, ... }:
let
  inherit (lib) filterAttrs mkIf mkMerge optionalAttrs;

  tomlFormat = pkgs.formats.toml { };
  cfg = config.aiAgents;

  enabledMcpServers = filterAttrs (_: server: server.enabled && builtins.elem "codex" server.targets) cfg.mcpServers;

  renderCodexMcpServer = _name: server:
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

  managedConfigSettings = {
    model_providers.local_coding_ollama = {
      name = "Ollama";
      base_url = cfg.localCoding.openaiBaseUrl;
    };

    profiles.local-coding = {
      model = cfg.localCoding.model;
      model_provider = "local_coding_ollama";
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
