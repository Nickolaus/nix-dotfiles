{ config, lib, pkgs, ... }:

let
  inherit (lib) mkEnableOption mkIf mkOption types;

  cfg = config.aiWorkflowReceipts;

  kinds = [
    "plan"
    "review"
    "qa"
    "ship"
    "learning"
    "decision"
  ];

  statuses = [
    "info"
    "pass"
    "fail"
    "needs-work"
    "ready"
    "blocked"
  ];

  kindsPattern = builtins.concatStringsSep "|" kinds;
  statusesPattern = builtins.concatStringsSep "|" statuses;
  receiptOtelPython = pkgs.python3.withPackages (pythonPackages: [
    pythonPackages.opentelemetry-sdk
    pythonPackages.opentelemetry-exporter-otlp-proto-http
  ]);
  receiptOtelPythonBin = "${receiptOtelPython}/bin/python3";

  receiptHelpers = ''
    state_dir=${lib.escapeShellArg cfg.stateDir}

    repo_context() {
      git_cmd="${pkgs.git}/bin/git -c core.fsmonitor=false"
      root="$($git_cmd rev-parse --show-toplevel 2>/dev/null)" || {
        echo "$(pwd) is not inside a git repo -- workflow receipts are repo-scoped." >&2
        exit 1
      }

      branch="$($git_cmd -C "$root" branch --show-current 2>/dev/null || true)"
      if [ -z "$branch" ]; then
        branch="$($git_cmd -C "$root" rev-parse --short HEAD 2>/dev/null || echo detached)"
      fi

      commit="$($git_cmd -C "$root" rev-parse HEAD 2>/dev/null || echo unknown)"
      repo_base="$(${pkgs.coreutils}/bin/basename "$root" | ${pkgs.gnused}/bin/sed 's/[^A-Za-z0-9._-]/-/g; s/--*/-/g; s/^-//; s/-$//')"
      if [ -z "$repo_base" ]; then
        repo_base="repo"
      fi
      repo_hash="$(printf '%s' "$root" | ${pkgs.coreutils}/bin/sha256sum | ${pkgs.coreutils}/bin/cut -c1-12)"
      repo="$repo_base-$repo_hash"
      receipt_file="$state_dir/$repo.jsonl"
    }
  '';

  aiReceiptLog = pkgs.writeShellScriptBin "ai-receipt-log" ''
    set -euo pipefail

    usage() {
      echo "Usage: ai-receipt-log --kind <${kindsPattern}> --status <${statusesPattern}> --summary <text> [--evidence <text>]" >&2
    }

    kind=""
    status=""
    summary=""
    evidence=""

    while [ "$#" -gt 0 ]; do
      case "$1" in
        --kind)
          kind="''${2:-}"
          shift 2
          ;;
        --status)
          status="''${2:-}"
          shift 2
          ;;
        --summary)
          summary="''${2:-}"
          shift 2
          ;;
        --evidence)
          evidence="''${2:-}"
          shift 2
          ;;
        --help|-h)
          usage
          exit 0
          ;;
        *)
          echo "Unknown argument: $1" >&2
          usage
          exit 1
          ;;
      esac
    done

    case "$kind" in
      ${kindsPattern}) ;;
      "")
        echo "Missing --kind." >&2
        usage
        exit 1
        ;;
      *)
        echo "Invalid --kind: $kind" >&2
        usage
        exit 1
        ;;
    esac

    case "$status" in
      ${statusesPattern}) ;;
      "")
        echo "Missing --status." >&2
        usage
        exit 1
        ;;
      *)
        echo "Invalid --status: $status" >&2
        usage
        exit 1
        ;;
    esac

    if [ -z "$summary" ]; then
      echo "Missing --summary." >&2
      usage
      exit 1
    fi

    ${receiptHelpers}
    repo_context
    ${pkgs.coreutils}/bin/mkdir -p "$state_dir"
    ts="$(${pkgs.coreutils}/bin/date -u +"%Y-%m-%dT%H:%M:%SZ")"

    ${pkgs.jq}/bin/jq -cn \
      --arg ts "$ts" \
      --arg repo "$repo" \
      --arg branch "$branch" \
      --arg commit "$commit" \
      --arg kind "$kind" \
      --arg status "$status" \
      --arg summary "$summary" \
      --arg evidence "$evidence" \
      '{
        schema_version: 1,
        ts: $ts,
        repo: $repo,
        branch: $branch,
        commit: $commit,
        kind: $kind,
        status: $status,
        summary: $summary,
        evidence: $evidence
      }' >> "$receipt_file"

    if [ "''${AI_RECEIPT_OTLP_DISABLE:-0}" != "1" ]; then
      if [ -n "$($git_cmd -C "$root" status --short --untracked-files=all 2>/dev/null)" ]; then
        dirty=true
      else
        dirty=false
      fi

      evidence_present=false
      if [ -n "$evidence" ]; then
        evidence_present=true
      fi

      ${receiptOtelPythonBin} - \
        "''${AI_RECEIPT_OTLP_TRACES_ENDPOINT:-http://127.0.0.1:6006/v1/traces}" \
        "$repo" \
        "$branch" \
        "$commit" \
        "$dirty" \
        "$kind" \
        "$status" \
        "''${#summary}" \
        "$evidence_present" <<'PY' || true
    import hashlib
    import logging
    import sys

    from opentelemetry import trace
    from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
    from opentelemetry.sdk.resources import Resource
    from opentelemetry.sdk.trace import TracerProvider
    from opentelemetry.sdk.trace.export import SimpleSpanProcessor

    (
        endpoint,
        repo,
        branch,
        commit,
        dirty,
        kind,
        status,
        summary_len,
        evidence_present,
    ) = sys.argv[1:]

    def as_bool(value: str) -> bool:
        return value.lower() == "true"

    def size_class(value: str) -> str:
        try:
            size = int(value)
        except ValueError:
            return "unknown"
        if size == 0:
            return "empty"
        if size <= 80:
            return "short"
        if size <= 240:
            return "medium"
        return "long"

    def hash_value(value: str) -> str:
        return hashlib.sha256(value.encode("utf-8", "replace")).hexdigest()[:16]

    try:
        logging.disable(logging.CRITICAL)
        provider = TracerProvider(
            resource=Resource.create(
                {
                    "service.name": "nix-dotfiles-workflow-receipts",
                    "service.version": "1",
                }
            )
        )
        provider.add_span_processor(SimpleSpanProcessor(OTLPSpanExporter(endpoint=endpoint, timeout=1)))
        trace.set_tracer_provider(provider)
        tracer = trace.get_tracer("nix-dotfiles.ai-observability.receipts", "1")

        with tracer.start_as_current_span("ai.workflow.receipt") as span:
            span.set_attribute("ai.setup.agent", "workflow-receipts")
            span.set_attribute("ai.setup.backend", "phoenix")
            span.set_attribute("ai.setup.capture_mode", "metadata-only")
            span.set_attribute("ai.setup.config_commit", commit)
            span.set_attribute("ai.setup.dirty", as_bool(dirty))
            span.set_attribute("ai.workflow.kind", kind)
            span.set_attribute("ai.workflow.status", status)
            span.set_attribute("ai.workflow.repo", repo)
            span.set_attribute("ai.workflow.branch_hash", hash_value(branch))
            span.set_attribute("ai.workflow.summary_size_class", size_class(summary_len))
            span.set_attribute("ai.workflow.evidence_present", as_bool(evidence_present))
        provider.shutdown()
    except Exception:
        pass
    PY
    fi

    echo "logged $kind/$status receipt: $receipt_file"
  '';

  aiReceiptStatus = pkgs.writeShellScriptBin "ai-receipt-status" ''
    set -euo pipefail

    ${receiptHelpers}
    repo_context

    echo "AI workflow receipts"
    echo "  repo:   $repo"
    echo "  branch: $branch"
    echo "  head:   $commit"
    echo "  file:   $receipt_file"
    echo

    if [ ! -f "$receipt_file" ]; then
      echo "No receipts yet."
      exit 0
    fi

    ${pkgs.jq}/bin/jq -s -r --arg head "$commit" --argjson kinds '${builtins.toJSON kinds}' '
      def latest($kind):
        [ .[] | select(.schema_version == 1 and .kind == $kind) ] | last;

      $kinds[] as $kind
      | latest($kind) as $r
      | if $r == null then
          "\($kind): none"
        else
          "\($kind): \($r.status) [\($r.branch)] \($r.summary)\n  ts: \($r.ts)\n  commit: \($r.commit)" +
          (if ($r.evidence // "") != "" then "\n  evidence: \($r.evidence)" else "" end) +
        (if $r.commit != $head then "\n  stale: receipt commit differs from HEAD; re-check before relying" else "" end)
        end
    ' "$receipt_file"
  '';

  receiptInstructions = ''

    ## AI Workflow Receipts

    Before review, QA, or ship work, run `ai-receipt-status` from the repo root.
    Use previous receipts as workflow context, but treat commit mismatch warnings
    as stale evidence until re-checked.

    Log only meaningful outcomes, not every step:
    - after plan/review/QA/ship/decision work, run `ai-receipt-log`;
    - use `--kind plan|review|qa|ship|learning|decision`;
    - use `--status info|pass|fail|needs-work|ready|blocked`;
    - keep `--summary` short and factual;
    - put compact verification pointers in `--evidence`.

    Never put prompts, secrets, cookies, file contents, full paths, or raw logs
    in workflow receipts. Receipts are local state, not project source.
  '';
in
{
  options.aiWorkflowReceipts = {
    enable = mkEnableOption "local AI workflow receipt scripts and agent instructions" // {
      default = true;
    };

    stateDir = mkOption {
      type = types.str;
      default =
        if pkgs.stdenv.hostPlatform.isDarwin then
          "/private/tmp/${config.home.username}/ai-workflow"
        else
          "${config.xdg.stateHome}/ai-workflow";
      description = "Directory for repo-scoped AI workflow receipt JSONL files.";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [
      aiReceiptLog
      aiReceiptStatus
    ];

    home.file.".codex/AGENTS.md".text = receiptInstructions;
    home.file.".vibe/AGENTS.md".text = receiptInstructions;
    home.file.".claude/CLAUDE.md".text = receiptInstructions;
  };
}
