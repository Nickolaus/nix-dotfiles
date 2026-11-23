{ config, lib, pkgs, ... }:

let
  inherit (lib) mkEnableOption mkIf mkOption types;

  cfg = config.hitGate;
  localAi = config.localAi;
  curl = "${pkgs.curl}/bin/curl";
  jq = "${pkgs.jq}/bin/jq";
  # `toString 0.1` renders "0.100000"; trim trailing zeros for prose and CLI defaults.
  fmtFloat = f:
    let m = builtins.match "(-?[0-9]+\\.[0-9]*[1-9])0*" (toString f);
    in if m == null then toString (builtins.floor f) else builtins.head m;

  # Frozen gate schema, passed with every request so a caller cannot widen the
  # question set. The research query travels in the state, not in the
  # instructions, so one loaded model serves every query.
  gateQuestions = pkgs.writeText "hit-gate-questions.json" (builtins.toJSON {
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

  gateScript = pkgs.writeText "hit-gate.py" ''
    """Score search hits (JSONL on stdin) with a local Ollama decision model."""

    import argparse
    import concurrent.futures
    import json
    import sys
    import time
    import urllib.error
    import urllib.request

    ENDPOINT = "${localAi.endpoint}"
    QUESTIONS = json.load(open("${gateQuestions}"))


    def main() -> int:
        parser = argparse.ArgumentParser(
            description="Read search hits as JSONL ({title, url, snippet, ...}) on stdin, "
            "print one JSONL decision per hit on stdout in input order."
        )
        parser.add_argument("--query", required=True, help="research query the hits were found for")
        parser.add_argument("--model", default="${cfg.model}")
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

        def decide(hit):
            state = {"query": args.query, **{k: v for k, v in hit.items() if k != "query"}}
            body = json.dumps({"model": args.model, "questions": QUESTIONS, "state": state}).encode()
            request = urllib.request.Request(
                ENDPOINT + "/v1/systemone", data=body, headers={"Content-Type": "application/json"}
            )
            try:
                with urllib.request.urlopen(request, timeout=300) as response:
                    return json.load(response)
            except urllib.error.HTTPError as error:
                detail = error.read().decode(errors="replace")
                if error.code == 404:
                    detail += "\nRun llm-pull gate to install the decision model."
                raise SystemExit(f"hit-gate: HTTP {error.code}: {detail}")
            except urllib.error.URLError as error:
                raise SystemExit(
                    f"hit-gate: {ENDPOINT} unreachable ({error.reason}). Check llm-status."
                )

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
        print(f"hit-gate: kept {kept}/{len(hits)} in {elapsed:.1f}s", file=sys.stderr)
        return 0


    if __name__ == "__main__":
        raise SystemExit(main())
  '';

  hitGateInstructions = ''

    ## Search-hit gating (local decision model)

    `hit-gate` scores search results with the `${cfg.model}` decision model on
    the local Ollama service (`${localAi.endpoint}`), which answers a fixed
    question schema in one forward pass per hit.

    Default command surface:
    - `hit-gate --query "<query>" < hits.jsonl` scores search hits given as
      JSONL (`{"title","url","snippet"}` per line) and prints one decision per
      line with `keep`, `fetch`, `confidence` and `relevant`.
    - `hit-gate-status` shows the endpoint, the model, and whether it is
      installed and loaded.
    - `llm-pull gate` installs the model (about ${cfg.modelSize}, one time).

    Boundary rules:
    - Use it to decide which of 10-20 search results to open before `fetch` or
      Crawl4AI. One `hit-gate` call per result list.
    - It scores result metadata only (title, url, snippet). Validating the
      content of a page is the job of whatever fetches it.
    - Drop a result only when `keep` is false: `fetch` is `skip` and either its
      `confidence` is at least ${fmtFloat cfg.skipConfidence} or `relevant` is
      below ${fmtFloat cfg.dropRelevantBelow}. Never drop on `relevant` alone.
    - Prefer ranking over dropping when a list is long: open the highest
      `relevant` scores first rather than discarding the tail.
    - Never use it to choose skills, MCP profiles, tools, or triage and
      escalation steps.
  '';
in
{
  options.hitGate = {
    enable = mkEnableOption "local decision-model gating for search hits" // {
      default = localAi.enable;
    };

    model = mkOption {
      type = types.str;
      default = localAi.profiles.gate.model;
      description = "Ollama decision model `hit-gate` sends its question schema to.";
    };

    modelSize = mkOption {
      type = types.str;
      default = localAi.profiles.gate.size;
      description = "Approximate download size quoted in the rendered agent instructions.";
    };

    skipConfidence = mkOption {
      type = types.float;
      default = 0.5;
      description = "Minimum `fetch=skip` confidence at which hit-gate drops a hit on its own.";
    };

    dropRelevantBelow = mkOption {
      type = types.float;
      default = 0.1;
      description = ''
        `relevant` score below which hit-gate also drops a `fetch=skip` hit
        whose confidence is under `skipConfidence`.
      '';
    };
  };

  config = mkIf cfg.enable {
    home.file.".codex/AGENTS.md".text = hitGateInstructions;
    home.file.".vibe/AGENTS.md".text = hitGateInstructions;
    home.file.".claude/CLAUDE.md".text = hitGateInstructions;
    home.file.".config/opencode/AGENTS.md".text = hitGateInstructions;

    home.packages = [
      (pkgs.writeShellScriptBin "hit-gate" ''
        exec ${pkgs.python3}/bin/python3 ${gateScript} "$@"
      '')

      (pkgs.writeShellScriptBin "hit-gate-status" ''
        set -uo pipefail
        echo "Endpoint: ${localAi.endpoint}"
        echo "Model:    ${cfg.model} (${cfg.modelSize})"
        echo "Drop:     fetch=skip and (confidence >= ${fmtFloat cfg.skipConfidence} or relevant < ${fmtFloat cfg.dropRelevantBelow})"
        echo
        if ! ${curl} -fsS --max-time 2 "${localAi.endpoint}/api/tags" > /dev/null 2>&1; then
          echo "Service: unreachable -- run llm-status"
          exit 1
        fi
        echo "Service: reachable"
        if ${curl} -fsS "${localAi.endpoint}/api/tags" \
          | ${jq} -e --arg m "${cfg.model}" '.models[]?.name | select(. == $m)' > /dev/null; then
          echo "Model:   installed"
        else
          echo "Model:   not installed -- run llm-pull gate"
          exit 1
        fi
        echo
        echo "Loaded models:"
        ${curl} -fsS "${localAi.endpoint}/api/ps" \
          | ${jq} -r '.models[]? | "  \(.name)  until \(.expires_at)"'
      '')
    ];
  };
}
