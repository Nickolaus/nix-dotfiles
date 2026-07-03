{ config, lib, osConfig ? { }, pkgs, ... }:
let
  inherit (lib) filterAttrs mkIf optionalAttrs;

  aiAgentsLib = import ../../../hosts/shared/ai-agents-lib.nix { inherit lib pkgs; };

  aiCfg = if osConfig ? aiAgents then osConfig.aiAgents else null;

  vibeEnabled = aiCfg != null && aiCfg.enable && aiCfg.targets.vibe.enable;

  enabledMcpServers =
    if aiCfg != null then
      filterAttrs (_: server: server.enabled && builtins.elem "vibe" server.targets) aiCfg.mcpServers
    else
      { };

  # Vibe's config.toml requires an explicit `transport` per server -- unlike
  # Codex/Claude/Cursor, which infer stdio vs. http from which fields are set.
  transportFor = server: if server.type == "http" then "streamable-http" else "stdio";

  # Codex gets bearer-token auth for HTTP MCP servers via its native
  # `bearer_token_env_var` field; Vibe has an equally native equivalent
  # (`api_key_env` + `api_key_header` + `api_key_format`), so -- unlike
  # Claude/Cursor -- no literal-string env-var expansion trick is needed here.
  renderVibeMcpServer = name: rawServer:
    let
      server = aiAgentsLib.effectiveServerFor "vibe" rawServer;
    in
    { inherit name; transport = transportFor server; }
    // (
      if server.type == "http" then
        { url = server.url; }
        // optionalAttrs (server.headers != { }) { headers = server.headers; }
        // optionalAttrs (server.bearerTokenEnvVar != null) {
          api_key_env = server.bearerTokenEnvVar;
          api_key_header = "Authorization";
          api_key_format = "Bearer {token}";
        }
      else
        aiAgentsLib.renderStdioCommand name server
        // optionalAttrs (server.args != [ ]) { args = server.args; }
        // optionalAttrs (server.env != { }) { env = server.env; }
    )
    // optionalAttrs (server.startupTimeoutSec != null) {
      startup_timeout_sec = server.startupTimeoutSec;
    };

  managedServersList = lib.mapAttrsToList renderVibeMcpServer enabledMcpServers;
  managedServerNames = builtins.attrNames enabledMcpServers;
  managedServersJson = pkgs.writeText "vibe-managed-mcp-servers.json" (builtins.toJSON managedServersList);

  # `~/.vibe/config.toml` also holds live, interactively-edited user state
  # (model choice, default_agent, tool permissions, `/mcp add`-created OAuth
  # servers, ...), so we can't blindly overwrite the whole file the way
  # Claude's `.claude/settings.json` does. tomlkit does a format-preserving
  # parse/edit/dump, so only the `[[mcp_servers]]` entries we own are
  # replaced; anything else in the file (including a user's own manually
  # added servers) survives untouched, mirroring the surgical approach
  # `restoreCodexUserConfig` takes for Codex's `config.toml` via awk.
  mergeScript = pkgs.writeText "vibe-merge-mcp-servers.py" ''
    import json
    import sys

    import tomlkit

    config_path, generated_path = sys.argv[1], sys.argv[2]

    with open(generated_path) as f:
        managed = json.load(f)
    managed_names = {entry["name"] for entry in managed}

    try:
        with open(config_path) as f:
            doc = tomlkit.parse(f.read())
    except FileNotFoundError:
        doc = tomlkit.document()

    existing = doc.get("mcp_servers", [])
    kept = [item for item in existing if item.get("name") not in managed_names]

    array = tomlkit.aot()
    for item in kept:
        array.append(item)
    for entry in managed:
        table = tomlkit.table()
        for key, value in entry.items():
            table[key] = value
        array.append(table)

    doc["mcp_servers"] = array

    with open(config_path, "w") as f:
        f.write(tomlkit.dumps(doc))
  '';

  mergePython = pkgs.python3.withPackages (ps: [ ps.tomlkit ]);
in
{
  home.activation.mergeVibeMcpServers = mkIf vibeEnabled (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      vibe_dir="${config.home.homeDirectory}/.vibe"
      mkdir -p "$vibe_dir"
      ${mergePython}/bin/python3 ${mergeScript} "$vibe_dir/config.toml" ${managedServersJson}
    ''
  );

  home.packages = mkIf vibeEnabled [
    (pkgs.writeShellScriptBin "vibe-status" ''
      set -euo pipefail

      echo "Vibe config: ~/.vibe/config.toml"
      if [ -f "$HOME/.vibe/config.toml" ]; then
        echo "  ok      file exists"
      else
        echo "  missing not created yet -- apply Home Manager, or run 'vibe' once"
      fi

      echo
      echo "Managed MCP servers (merged in declaratively, same set as Codex):"
      for name in ${builtins.concatStringsSep " " (map lib.escapeShellArg managedServerNames)}; do
        echo "  - $name"
      done

      echo
      echo "Skills: Vibe follows the Agent Skills spec and reads ~/.agents/skills/ directly --"
      echo "the same directory Codex uses -- so skills installed via caveman.nix (see caveman-status)"
      echo "are already available in Vibe with no extra wiring. Project-local .agents/skills/ and"
      echo ".vibe/skills/ are also picked up automatically in trusted folders."

      echo
      echo "API key: first run prompts interactively and saves to ~/.vibe/.env, or set MISTRAL_API_KEY,"
      echo "or run 'vibe --setup' explicitly."

      echo
      echo "Note: any MCP server you add yourself via '/mcp add' inside Vibe is left alone by the"
      echo "declarative merge above -- only the \$name entries listed here are managed by Nix."
    '')
  ];
}
