#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

all_systems=false
skip_skill_scan=false

check_candidate_skills() {
    if [[ "$skip_skill_scan" == true ]]; then
        if [[ -n "${CI:-}" ]]; then
            echo "error: SkillSpector bypass is forbidden in CI" >&2
            return 2
        fi
        echo "Skipping SkillSpector gate (explicit emergency bypass)." >&2
        return 0
    fi

    local manifest=$1
    local scan_rc=0
    ./scripts/check-skills.sh --manifest "$manifest" || scan_rc=$?
    if [[ "$scan_rc" -ne 0 ]]; then
        echo "SkillSpector gate failed" >&2
        return "$scan_rc"
    fi
}

check_candidate_skills_from_flake() {
    local config_attr=$1
    local manifest
    local eval_rc=0
    manifest=$(mktemp "${TMPDIR:-/tmp}/nix-dotfiles-catalog.XXXXXX")
    if ! nix eval --raw "$config_attr" > "$manifest"; then
        rm -f -- "$manifest"
        echo "error: could not evaluate candidate catalog manifest" >&2
        return 1
    fi
    check_candidate_skills "$manifest" || eval_rc=$?
    rm -f -- "$manifest"
    return "$eval_rc"
}

usage() {
    cat << 'EOF'
Usage: ./scripts/check-config.sh [--all-systems]

Validate the current platform by default. Use --all-systems from a Linux
machine or a configured remote builder to evaluate every declared host.
The SkillSpector gate is enabled by default; only update-system.sh may bypass
it after interactive confirmation with --skip-skill-scan.
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --all-systems)
                all_systems=true
                ;;
            --skip-skill-scan)
                skip_skill_scan=true
                ;;
            --help | -h)
                usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                usage >&2
                exit 1
                ;;
        esac
        shift
    done
}

check_darwin() {
    echo "Checking AI agent catalog candidate..."
    nix eval '.#darwinConfigurations.zoidberg.config.home-manager.users."C.Hessel".home.file.".agents/catalog/manifest.json".text' > /dev/null
    check_candidate_skills_from_flake '.#darwinConfigurations.zoidberg.config.home-manager.users."C.Hessel".home.file.".agents/catalog/manifest.json".text'
    if command -v agent-catalog-check > /dev/null 2>&1 && [ -f "$HOME/.agents/catalog/manifest.json" ]; then
        echo "Checking applied AI agent catalog..."
        agent-catalog-check
    else
        echo "Skipping applied AI agent catalog check (agent-catalog-check or manifest not present yet)."
    fi

    echo "Evaluating Darwin host: zoidberg"
    nix eval .#darwinConfigurations.zoidberg.config.system.build.toplevel.drvPath > /dev/null
}

check_nixos() {
    local host=$1
    local system=$2

    echo "Evaluating NixOS host: $host"
    nix eval ".#nixosConfigurations.$host.config.system.build.toplevel.drvPath" > /dev/null
    check_candidate_skills_from_flake ".#nixosConfigurations.$host.config.home-manager.users.\"C.Hessel\".home.file.\".agents/catalog/manifest.json\".text"

    echo "Evaluating installer package: farnsworth-installer $system"
    nix eval ".#packages.$system.farnsworth-installer.drvPath" > /dev/null
}

check_wsl() {
    local host=$1

    echo "Evaluating NixOS host: $host"
    nix eval ".#nixosConfigurations.$host.config.system.build.toplevel.drvPath" > /dev/null
}

check_home_configs() {
    local name=$1

    echo "Evaluating standalone Home Manager: $name"
    nix eval ".#homeConfigurations.\"$name\".activationPackage.drvPath" > /dev/null
}

check_all_systems() {
    echo "Checking all flake systems..."
    nix flake check --all-systems
    check_darwin
    check_nixos farnsworth aarch64-linux
    check_nixos farnsworth-x86 x86_64-linux
    check_wsl bender
    check_wsl bender-aarch64
    check_home_configs "C.Hessel"
    check_home_configs "C.Hessel-aarch64"
}

check_native_system() {
    echo "Checking current-system flake outputs..."
    nix flake check

    case "$(uname -s):$(uname -m)" in
        Darwin:*)
            check_darwin
            ;;
        Linux:aarch64)
            check_nixos farnsworth aarch64-linux
            ;;
        Linux:x86_64)
            check_nixos farnsworth-x86 x86_64-linux
            ;;
        *)
            echo "Unsupported platform: $(uname -s) $(uname -m)" >&2
            exit 1
            ;;
    esac
}

parse_args "$@"

if [[ "$all_systems" == true ]]; then
    check_all_systems
else
    check_native_system
fi

echo "Configuration checks passed."
