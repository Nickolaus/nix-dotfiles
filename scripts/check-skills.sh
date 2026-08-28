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
        case "$recommendation:$severity" in
            SAFE:*)
                echo "  safe     score=$score severity=$severity"
                ;;
            CAUTION:MEDIUM)
                echo "  warning  score=$score severity=$severity recommendation=$recommendation"
                warnings=$((warnings + 1))
                if [[ "$strict" == true ]]; then
                    echo "error: strict mode blocks CAUTION recommendation for $skill_name" >&2
                    exit 1
                fi
                ;;
            DO_NOT_INSTALL:HIGH | DO_NOT_INSTALL:CRITICAL | CAUTION:HIGH | CAUTION:CRITICAL)
                echo "error: $skill_name: score=$score severity=$severity recommendation=$recommendation" >&2
                exit 1
                ;;
            *)
                echo "error: $skill_name: unknown recommendation: $recommendation" >&2
                exit 2
                ;;
        esac
        scanned=$((scanned + 1))
    done < <("$jq_bin" -c '.scanSources[]?' <<<"$skill_record")
done < <("$jq_bin" -c '.skills[] | select(.managed == true)' "$manifest")

echo "SkillSpector gate passed: $scanned source director$( [[ "$scanned" == 1 ]] && echo y || echo ies ) scanned, $warnings caution warning(s)."
