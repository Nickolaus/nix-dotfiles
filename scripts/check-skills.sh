#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat <<'EOF'
Usage: ./scripts/check-skills.sh --manifest PATH [--strict]

Scan managed catalog skill sources with SkillSpector in static-only mode.
--strict also blocks CAUTION recommendations; the normal upgrade policy warns.
EOF
}

manifest=""
strict=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --manifest)
            [[ $# -ge 2 ]] || { echo "error: --manifest needs a path" >&2; exit 2; }
            manifest=$2
            shift 2
            ;;
        --strict)
            strict=true
            shift
            ;;
        --help | -h)
            usage
            exit 0
            ;;
        *)
            echo "error: unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if [[ -z "$manifest" ]]; then
    echo "error: --manifest is required" >&2
    usage >&2
    exit 2
fi

if [[ ! -f "$manifest" ]]; then
    echo "error: missing catalog manifest: $manifest" >&2
    exit 2
fi

if ! command -v skillspector >/dev/null 2>&1; then
    echo "error: skillspector is not installed; run scripts/update-system.sh" >&2
    exit 2
fi

jq_bin=${JQ_BIN:-jq}
if ! command -v "$jq_bin" >/dev/null 2>&1; then
    echo "error: jq is required to read the catalog manifest" >&2
    exit 2
fi

"$jq_bin" empty "$manifest"
if ! "$jq_bin" -e '(.enabled | type == "boolean") and (.skills | type == "array") and all(.skills[]; ((.managed | type == "boolean") and ((.managed | not) or ((.scanSources | type == "array") and (.scanSources | length > 0)))))' "$manifest" >/dev/null; then
    echo "error: malformed catalog manifest inventory" >&2
    exit 2
fi

if [[ "${CI:-}" != "" && "${NIX_DOTFILES_SKIP_SKILL_SCAN:-0}" == "1" ]]; then
    echo "error: SkillSpector bypass is forbidden in CI" >&2
    exit 2
fi

report_root=${SKILLSPECTOR_REPORT_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/nix-dotfiles/skillspector}
scan_id=$(date -u +%Y%m%dT%H%M%SZ)
report_dir="$report_root/$scan_id"
mkdir -p "$report_dir"

seen_sources=()
scanned=0
warnings=0

source_was_seen() {
    local candidate=$1
    local seen_source
    for seen_source in "${seen_sources[@]}"; do
        [[ "$seen_source" == "$candidate" ]] && return 0
    done
    return 1
}

# Catalog skills whose scan findings were manually investigated (source
# read, finding context checked) and confirmed to be SkillSpector false
# positives -- the static scanner pattern-matches on surface strings and
# cannot tell a security control (a secrets denylist, a hardened
# subprocess call) from the thing it defends against. This is a reviewed
# suppression list, not an emergency bypass: findings are still scanned,
# reported, and counted as warnings for every skill, including these; the
# only change is that a DO_NOT_INSTALL/CAUTION verdict on a listed skill
# doesn't fail the gate. Stays in effect in CI and --strict -- unlike
# --skip-skill-scan, this isn't skipping the check, it's a recorded
# decision about its result. Add an entry only after reading the actual
# flagged lines, never to silence a finding you haven't verified.
SCAN_EXCEPTIONS=(
    # 2026-09-09: browser-qa-lab's third-party reference bundle is already
    # excluded from scanSources (catalog.skills.browser-qa-lab.scanExtraFiles
    # = false); kept here too as a second layer in case that bundle grows
    # back into scope. Original findings were prose inside upstream gstack
    # docs (a "don't substitute unit tests for browser QA" line read as
    # anti-refusal, a token-file `chmod 600` read as privilege escalation, a
    # /pair-agent connection-setup comment read as prompt leakage).
    "browser-qa-lab"
    # 2026-09-09: caveman v2.6.0's compress.py/detect.py. Flagged strings are
    # a secrets/credentials-file denylist ("hard refuse before read", per its
    # own comment) misread as the privilege escalation it prevents, and a
    # shutil.which-resolved, shell=True-free subprocess.run call (with
    # --strict-mcp-config hardening) misread as dangerous code execution.
    "caveman-compress"
)

is_scan_exception() {
    local candidate=$1
    local exception
    for exception in "${SCAN_EXCEPTIONS[@]}"; do
        [[ "$exception" == "$candidate" ]] && return 0
    done
    return 1
}

while IFS= read -r skill_record; do
    skill_name=$(printf '%s\n' "$skill_record" | "$jq_bin" -r '.name')
    while IFS= read -r source_path; do
        [[ -n "$source_path" ]] || continue
        if [[ ! -e "$source_path" ]]; then
            if ! command -v nix-store >/dev/null 2>&1 || ! nix-store --realise "$source_path" >/dev/null; then
                echo "error: $skill_name: scan source is missing and could not be realised: $source_path" >&2
                exit 2
            fi
        fi
        if source_was_seen "$source_path"; then
            continue
        fi
        seen_sources+=("$source_path")
        report="$report_dir/$scanned.json"
        echo "Scanning $skill_name: $source_path"
        set +e
        skillspector scan "$source_path" --no-llm --format json --output "$report"
        scan_rc=$?
        set -e
        if [[ "$scan_rc" -ne 0 && "$scan_rc" -ne 1 ]]; then
            echo "error: $skill_name: SkillSpector failed (exit $scan_rc)" >&2
            exit 2
        fi
        if [[ ! -s "$report" ]]; then
            echo "error: $skill_name: SkillSpector produced no JSON report" >&2
            exit 2
        fi

        recommendation=$("$jq_bin" -er '.risk_assessment.recommendation' "$report") || {
            echo "error: $skill_name: malformed SkillSpector report" >&2
            exit 2
        }
        severity=$("$jq_bin" -r '.risk_assessment.severity // "UNKNOWN"' "$report")
        score=$("$jq_bin" -r '.risk_assessment.score // "UNKNOWN"' "$report")
        # Upstream's documented contract keys allow/warn/block purely on
        # `recommendation` (SAFE/CAUTION/DO_NOT_INSTALL); severity is
        # informational. A recommendation+severity combo case here previously
        # left gaps (e.g. CAUTION:LOW) that fell through to the fatal
        # "unknown recommendation" branch even though CAUTION is documented
        # to warn, not block.
        case "$recommendation" in
            SAFE)
                echo "  safe     score=$score severity=$severity"
                ;;
            CAUTION)
                echo "  warning  score=$score severity=$severity recommendation=$recommendation"
                warnings=$((warnings + 1))
                if [[ "$strict" == true ]] && ! is_scan_exception "$skill_name"; then
                    echo "error: strict mode blocks CAUTION recommendation for $skill_name" >&2
                    exit 1
                fi
                ;;
            DO_NOT_INSTALL)
                if is_scan_exception "$skill_name"; then
                    echo "  exception score=$score severity=$severity recommendation=$recommendation (documented false positive, see SCAN_EXCEPTIONS)"
                    warnings=$((warnings + 1))
                else
                    echo "error: $skill_name: score=$score severity=$severity recommendation=$recommendation" >&2
                    exit 1
                fi
                ;;
            *)
                echo "error: $skill_name: unknown recommendation: $recommendation" >&2
                exit 2
                ;;
        esac
        scanned=$((scanned + 1))
    done < <("$jq_bin" -r '.scanSources[]?' <<<"$skill_record")
done < <("$jq_bin" -c '.skills[] | select(.managed == true)' "$manifest")

echo "SkillSpector gate passed: $scanned source director$( [[ "$scanned" == 1 ]] && echo y || echo ies ) scanned, $warnings caution warning(s)."
