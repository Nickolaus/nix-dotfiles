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
