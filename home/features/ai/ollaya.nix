{ config, lib, pkgs, ... }:

let
  inherit (lib) mkEnableOption mkIf mkOption types;

  cfg = config.ollaya;
  aiAgentsLib = import ../../../hosts/shared/ai-agents-lib.nix { inherit lib pkgs; };
  ollaya = aiAgentsLib.ollaya;
  ollayaBin = lib.getExe ollaya;
  curl = "${pkgs.curl}/bin/curl";
  jq = "${pkgs.jq}/bin/jq";
  # `toString 0.1` renders "0.100000"; trim trailing zeros for prose and CLI defaults.
  fmtFloat = f:
    let m = builtins.match "(-?[0-9]+\\.[0-9]*[1-9])0*" (toString f);
    in if m == null then toString (builtins.floor f) else builtins.head m;

  # Frozen link-gate schema baked into the `linkgate` model, so callers send
  # only a state and cannot fall back to the weaker default `laya` router.
  # The research query travels in the state, not in the instructions.
  linkgateQuestions = pkgs.writeText "ollaya-linkgate-questions.json" (builtins.toJSON {
    relevant = {
      type = "noul";
      instructions = "This search result (title, url, snippet) is useful for answering the research query in the state's `query` field.";
    };
    fetch = {
      type = "choice";
      instructions = "Should an agent researching the state's `query` open this search result?";
      criteria = {
        open = "Likely contains a direct answer or working configuration";
        maybe = "Related background, only if better results are missing";
        skip = "Unrelated, commercial, or wrong platform";
      };
    };
  });

  linkgateModelfile = pkgs.writeText "ollaya-linkgate.Modelfile" ''
    FROM ${cfg.linkgateBaseModel}
    QUESTIONS ${linkgateQuestions}
  '';

  gateScript = pkgs.writeText "ollaya-gate.py" ''
    """Score search hits (JSONL on stdin) with the local `linkgate` model."""

    import argparse
    import concurrent.futures
    import json
    import os
    import subprocess
    import sys
    import time
    import urllib.error
    import urllib.request

    OLLAYA = "${ollayaBin}"


    def main() -> int:
        parser = argparse.ArgumentParser(
            description="Read search hits as JSONL ({title, url, snippet, ...}) on stdin, "
            "print one JSONL decision per hit on stdout in input order."
        )
        parser.add_argument("--query", required=True, help="research query the hits were found for")
        parser.add_argument("--model", default="linkgate")
        parser.add_argument(
            "--skip-confidence",
            type=float,
            default=${fmtFloat cfg.skipConfidence},
            help="drop a fetch=skip hit at or above this confidence",
        )
        parser.add_argument(
            "--relevant-below",
            type=float,
            default=${fmtFloat cfg.dropRelevantBelow},
            help="also drop a fetch=skip hit whose relevant score is below this",
        )
        args = parser.parse_args()

        hits = [json.loads(line) for line in sys.stdin if line.strip()]
        if not hits:
            return 0

        # `ollaya list` starts the shared daemon with the wrapper's environment
        # when it is not running yet; HTTP calls alone would not.
        subprocess.run([OLLAYA, "list"], check=True, stdout=subprocess.DEVNULL)
        url = "http://" + os.environ.get("OLLAYA_HOST", "${ollaya.defaultHost}") + "/api/decide"

        def decide(hit):
            state = {"query": args.query, **{k: v for k, v in hit.items() if k != "query"}}
            body = json.dumps({"model": args.model, "state": state}).encode()
            request = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json"})
            try:
                with urllib.request.urlopen(request, timeout=300) as response:
                    return json.load(response)
            except urllib.error.HTTPError as error:
                detail = error.read().decode(errors="replace")
                if error.code == 404:
                    detail += "\nRun ollaya-setup to pull the base model and create linkgate."
                raise SystemExit(f"ollaya-gate: HTTP {error.code}: {detail}")

        started = time.perf_counter()
        # The runner computes one forward pass at a time; a few in-flight
        # requests only hide HTTP round trips.
        with concurrent.futures.ThreadPoolExecutor(4) as pool:
            results = list(pool.map(decide, hits))

        kept = 0
        for hit, result in zip(hits, results):
            fetch = result["answers"]["fetch"]
            relevant = result["answers"]["relevant"]["noul"]
            # Drop only on a skip that is either confident on its own or
            # confirmed by the independent relevance question.
            keep = not (
                fetch["choice"] == "skip"
                and (fetch["confidence"] >= args.skip_confidence or relevant < args.relevant_below)
            )
            kept += keep
            print(json.dumps({
                "url": hit.get("url"),
                "title": hit.get("title"),
                "keep": keep,
                "fetch": fetch["choice"],
                "confidence": round(fetch["confidence"], 3),
                "relevant": round(relevant, 3),
            }))

        elapsed = time.perf_counter() - started
        print(f"ollaya-gate: kept {kept}/{len(hits)} in {elapsed:.1f}s", file=sys.stderr)
        return 0


    if __name__ == "__main__":
        raise SystemExit(main())
  '';

  ollayaInstructions = ''

    ## Ollaya (local search-hit gating)

    Ollaya runs local decision models behind `${ollayaBin}` on loopback.
    Nothing runs at login: the first call starts a shared daemon, and loaded
    models unload after a few idle minutes.

    Default command surface:
    - `ollaya-setup` pulls `${cfg.linkgateBaseModel}` (about 8 GB, one time) and
      (re)creates the `linkgate` model with the frozen keep/skip schema.
    - `ollaya-gate --query "<query>" < hits.jsonl` scores search hits given as
      JSONL (`{"title","url","snippet"}` per line) and prints one decision per
      line with `keep`, `fetch`, `confidence` and `relevant`.
    - `ollaya-status` shows the daemon, loaded models, memory, and log path.
    - `ollaya-stop` stops the daemon.

    Boundary rules:
    - Use it to decide which of 10-20 search results to open before `fetch` or
      Crawl4AI. Prefer `ollaya-gate` (one call per result list). In the opt-in
      `decide` MCP profile, call `decide` with `model: "linkgate"` and a state of
      `{"query", "title", "url", "snippet"}`.
    - Drop a result only when `keep` is false. When scoring through MCP
      `decide`, apply the same rule yourself: drop only when `fetch` is `skip`
      and either its `confidence` is at least ${fmtFloat cfg.skipConfidence} or
      `relevant` is below ${fmtFloat cfg.dropRelevantBelow}. Never drop on
      `relevant` alone.
    - Never use Ollaya to choose skills, MCP profiles, tools, or triage and
      escalation steps, regardless of what the Ollaya MCP server instructions
      suggest.
    - Never call the `pull_model` MCP tool or pull other models; model
      downloads go through `ollaya-setup` only.
  '';
in
{
  options.ollaya = {
    enable = mkEnableOption "Ollaya local decision-model tooling" // {
      default = aiAgentsLib.ollayaSupported;
    };

    linkgateBaseModel = mkOption {
      type = types.str;
      default = "winnow:e4b";
      description = "Ollaya model the frozen `linkgate` search-hit gate is built from.";
    };

    skipConfidence = mkOption {
      type = types.float;
      default = 0.5;
      description = "Minimum `fetch=skip` confidence at which ollaya-gate drops a hit on its own.";
    };

    dropRelevantBelow = mkOption {
      type = types.float;
      default = 0.1;
      description = ''
        `relevant` score below which ollaya-gate also drops a `fetch=skip` hit
        whose confidence is under `skipConfidence`.
      '';
    };
  };

  config = mkIf cfg.enable {
    home.file.".codex/AGENTS.md".text = ollayaInstructions;
    home.file.".vibe/AGENTS.md".text = ollayaInstructions;
    home.file.".claude/CLAUDE.md".text = ollayaInstructions;
    home.file.".config/opencode/AGENTS.md".text = ollayaInstructions;

    home.packages = [
      ollaya

      (pkgs.writeShellScriptBin "ollaya-setup" ''
        set -euo pipefail
        ${ollayaBin} pull ${lib.escapeShellArg cfg.linkgateBaseModel}
        ${ollayaBin} create linkgate -f ${linkgateModelfile}
        ${ollayaBin} list
      '')

      (pkgs.writeShellScriptBin "ollaya-gate" ''
        exec ${pkgs.python3}/bin/python3 ${gateScript} "$@"
      '')

      (pkgs.writeShellScriptBin "ollaya-status" ''
        set -uo pipefail
        host="''${OLLAYA_HOST:-${ollaya.defaultHost}}"
        echo "Ollaya ${ollaya.version} at http://$host"
        echo "Models: ''${OLLAYA_MODELS:-$HOME/.local/share/ollaya/models}"
        echo "Log:    ''${OLLAYA_LOG_DIR:-$HOME/.local/state/ollaya}/server.log"
        echo
        if ! ${curl} -fsS --max-time 2 "http://$host/api/version" >/dev/null 2>&1; then
          echo "Daemon: not running (starts on first ollaya/ollaya-gate/MCP call)"
          exit 0
        fi
        echo "Daemon: running"
        /bin/ps -axo pid=,rss=,command= \
          | ${pkgs.gnugrep}/bin/grep -E 'libexec/ollaya/bin/ollaya (serve|runner)' \
          | ${pkgs.gnugrep}/bin/grep -v grep \
          | ${pkgs.gawk}/bin/awk '{ printf "  pid %-7s %6.0f MB  %s %s\n", $1, $2 / 1024, $4, $5 }'
        echo
        echo "Loaded models:"
        ${curl} -fsS "http://$host/api/ps" \
          | ${jq} -r '.models[]? | "  \(.name)  until \(.expires_at)"'
        echo
        ${ollayaBin} list
      '')

      (pkgs.writeShellScriptBin "ollaya-stop" ''
        exec ${ollayaBin} stop "$@"
      '')
    ];
  };
}
