#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat <<'EOF'
Usage: ./scripts/check-skill-pins.sh [--strict]

Compare the pinned skill source inputs in flake.nix with their upstream
releases or default-branch HEAD. `nix flake update` never moves a tag or
commit pin, so this is the only signal that a pin has fallen behind.
Report only: exits 0 unless --strict is given and a pin is behind.
EOF
}

strict=false
while [[ $# -gt 0 ]]; do
    case "$1" in
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

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if ! command -v gh > /dev/null 2>&1; then
    echo "Skipping skill pin check: gh is not installed." >&2
    exit 0
fi

# Flake inputs that feed aiAgents.catalog skill sources, read out of the typed
# registry that the catalog modules themselves resolve, so adding a skill input
# there cannot leave this check behind. Read textually rather than with
# `nix eval`: flake/ai-agent-sources.nix is a function of the flake, so it has
# no standalone attribute to evaluate, and going through the flake would cost a
# full evaluation in a script whose contract is a quick upstream report.
# Matching the awk pass over flake.nix below, which is already textual.
sources_registry="flake/ai-agent-sources.nix"
if [[ ! -f "$sources_registry" ]]; then
    echo "error: missing skill source registry: $sources_registry" >&2
    exit 2
fi

mapfile -t inputs < <(awk '
    /^  skills = \{/ { found = 1; next }
    found && /^  \};/ { exit }
    found { print }
' "$sources_registry" | sed -nE 's/^[[:space:]]*[A-Za-z0-9_-]+[[:space:]]*=[[:space:]]*flake\.inputs\.([A-Za-z0-9_.-]+)[[:space:]]*;.*/\1/p')

if [[ "${#inputs[@]}" -eq 0 ]]; then
    echo "error: no skill inputs found in $sources_registry" >&2
    exit 2
fi

behind=0

for name in "${inputs[@]}"; do
    spec=$(awk -v n="$name" '
        $1 == n && $2 == "=" && $3 == "{" { found = 1; next }
        found && /url = / { print; exit }
    ' flake.nix | sed -E 's/.*"github:([^"]+)".*/\1/')
    if [[ -z "$spec" ]]; then
        printf '  %-18s not found in flake.nix\n' "$name"
        continue
    fi

    IFS=/ read -r owner repo ref <<< "$spec"
    if [[ -z "${ref:-}" ]]; then
        printf '  %-18s unpinned (tracks the default branch)\n' "$name"
        behind=1
        continue
    fi

    if [[ "$ref" =~ ^[0-9a-f]{40}$ ]]; then
        if ! head_sha=$(gh api "repos/$owner/$repo/commits/HEAD" --jq .sha 2> /dev/null); then
            printf '  %-18s %s: upstream lookup failed\n' "$name" "${ref:0:7}"
            continue
        fi
        ahead=$(gh api "repos/$owner/$repo/compare/$ref...$head_sha" --jq .ahead_by 2> /dev/null || echo "?")
        if [[ "$ahead" == "0" ]]; then
            printf '  %-18s %s  current\n' "$name" "${ref:0:7}"
        else
            printf '  %-18s %s  BEHIND: %s commit(s) on the default branch (no releases to pin)\n' \
                "$name" "${ref:0:7}" "$ahead"
            behind=1
        fi
        continue
    fi

    latest=$(gh api "repos/$owner/$repo/releases/latest" --jq .tag_name 2> /dev/null \
        || gh api "repos/$owner/$repo/tags" --jq '.[0].name' 2> /dev/null || true)
    if [[ -z "$latest" ]]; then
        printf '  %-18s %s: upstream lookup failed\n' "$name" "$ref"
    elif [[ "$latest" == "$ref" ]]; then
        unreleased=$(gh api "repos/$owner/$repo/compare/$ref...HEAD" --jq .ahead_by 2> /dev/null || echo "?")
        printf '  %-18s %s  current (%s unreleased commit(s) upstream)\n' "$name" "$ref" "$unreleased"
    else
        printf '  %-18s %s  BEHIND: latest release is %s\n' "$name" "$ref" "$latest"
        behind=1
    fi
done

if [[ "$strict" == true && "$behind" -ne 0 ]]; then
    exit 1
fi
