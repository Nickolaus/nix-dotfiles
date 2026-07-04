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

  directMistralApiUrl = "https://api.mistral.ai/v1";
  vibeProxyBaseUrl =
    if aiCfg != null then aiCfg.headroom.proxies.vibe.url else "http://127.0.0.1:8788";
  vibeProxyUrl = "${vibeProxyBaseUrl}/v1";
  # Headroom's proxy (home/features/ai/headroom.nix) only ever runs on Darwin, so the
  # "target" the guarded rewrite below drives towards is the direct URL (a harmless no-op)
  # everywhere else -- never a URL nothing is listening on.
  mistralTargetUrl = if pkgs.stdenv.hostPlatform.isDarwin then vibeProxyUrl else directMistralApiUrl;

  # `~/.vibe/config.toml` also holds live, interactively-edited user state (model choice,
  # default_agent, tool permissions, `/mcp add`-created OAuth servers, the "mistral"
  # provider's own `api_base`, ...), so we can't blindly overwrite the whole file the way
  # Claude's `.claude/settings.json` does. tomlkit does a format-preserving parse/edit/dump,
  # so only the pieces we own are replaced: the `[[mcp_servers]]` entries by name (mirroring
  # the surgical approach `restoreCodexUserConfig` takes for Codex's `config.toml` via awk),
  # and the "mistral" provider's `api_base` -- routed through Headroom by default, same
  # "opt-out, not opt-in" philosophy as Claude/Codex (hosts/shared/claude-code.nix,
  # codex.nix; live-validated end-to-end against Mistral's real API), but *only* rewritten
  # while it's still holding a value we recognise (the direct default or our own proxy URL
  # already) -- a value the user customized to something else themselves is left untouched.
  #
  # A plain "keep anything not currently declared" filter can't tell a genuinely
  # user-added entry apart from one Nix used to manage but no longer declares (e.g.
  # a server narrowed out of aiAgents.mcpServers.<name>.targets) -- both look
  # identical once removed from `managed`. So a small state side-car
  # (`.nix-managed-mcp-servers.json`, written after every merge) records exactly
  # which names Nix managed last time; only names in *neither* the current nor the
  # previous managed set are assumed to be the user's own and survive untouched.
  mergeScript = pkgs.writeText "vibe-merge-config.py" ''
    import json
    import sys

    import tomlkit

    config_path, generated_path, state_path, mistral_direct_url, mistral_target_url = (
        sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]
    )

    with open(generated_path) as f:
        managed = json.load(f)
    managed_names = {entry["name"] for entry in managed}

    try:
        with open(state_path) as f:
            previously_managed_names = set(json.load(f))
    except FileNotFoundError:
        previously_managed_names = set()

    try:
        with open(config_path) as f:
            doc = tomlkit.parse(f.read())
    except FileNotFoundError:
        doc = tomlkit.document()

    existing = doc.get("mcp_servers", [])
    kept = [
        item for item in existing
        if item.get("name") not in managed_names
        and item.get("name") not in previously_managed_names
    ]

    array = tomlkit.aot()
    for item in kept:
        array.append(item)
    for entry in managed:
        table = tomlkit.table()
        for key, value in entry.items():
            table[key] = value
        array.append(table)

    doc["mcp_servers"] = array

    for entry in doc.get("providers", []):
        if entry.get("name") == "mistral" and entry.get("api_base") in (mistral_direct_url, mistral_target_url):
            entry["api_base"] = mistral_target_url

    with open(config_path, "w") as f:
        f.write(tomlkit.dumps(doc))

    with open(state_path, "w") as f:
        json.dump(sorted(managed_names), f)
  '';

  mergePython = pkgs.python3.withPackages (ps: [ ps.tomlkit ]);

  # Read-only status helper for `vibe-status`. There's deliberately no matching "set"
  # script/enable-disable command pair here: opting out of Vibe's default routing uses the
  # exact same mechanism Claude/Codex already rely on (`headroom-pause vibe` stops the proxy
  # process itself), rather than a bespoke Vibe-only TOML mutation with its own reversion
  # semantics -- one universal opt-out path for all three tools, not three different ones.
  getMistralApiBaseScript = pkgs.writeText "vibe-get-mistral-api-base.py" ''
    import sys

    import tomlkit

    try:
        with open(sys.argv[1]) as f:
            doc = tomlkit.parse(f.read())
    except FileNotFoundError:
        sys.exit(0)

    for entry in doc.get("providers", []):
        if entry.get("name") == "mistral":
            print(entry.get("api_base", ""))
  '';
in
{
  home.activation.mergeVibeMcpServers = mkIf vibeEnabled (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      vibe_dir="${config.home.homeDirectory}/.vibe"
      mkdir -p "$vibe_dir"
      ${mergePython}/bin/python3 ${mergeScript} "$vibe_dir/config.toml" ${managedServersJson} \
        "$vibe_dir/.nix-managed-mcp-servers.json" \
        ${lib.escapeShellArg directMistralApiUrl} ${lib.escapeShellArg mistralTargetUrl}
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
      echo "Headroom compression: ON BY DEFAULT for the mistral provider (opt-out, same as"
      echo "Claude/Codex -- same destination/auth, just compressed):"
      current_api_base="$(${mergePython}/bin/python3 ${getMistralApiBaseScript} "$HOME/.vibe/config.toml" 2>/dev/null || true)"
      if [ "$current_api_base" = ${lib.escapeShellArg vibeProxyUrl} ]; then
        echo "  on      mistral provider routed through ${vibeProxyUrl}"
      elif [ -n "$current_api_base" ]; then
        echo "  custom  mistral provider -> $current_api_base (customized by you; left alone)"
      else
        echo "  n/a     no 'mistral' provider yet -- run 'vibe --setup' first"
      fi
      echo "  opt out: headroom-pause vibe   (same mechanism Claude/Codex use; a rebuild"
      echo "           reasserts it, same as it does for them)."

      echo
      echo "Note: any MCP server you add yourself via '/mcp add' inside Vibe is left alone by the"
      echo "declarative merge above -- only the \$name entries listed here are managed by Nix."
    '')
  ];
}
