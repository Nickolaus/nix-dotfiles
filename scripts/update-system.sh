#!/usr/bin/env bash

# nix-dotfiles System Update Script
# Comprehensive update workflow for Determinate Systems Nix + nix-darwin/NixOS

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

UPGRADE_BREW=false
UPGRADE_AUTO_UPDATE_CASKS=false
PRUNE_BREW=false
DRY_RUN=false
CLEANUP_ONLY=false
SKIP_SKILL_SCAN=false

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)

# SkillSpector's pin and version comparison are shared with
# scripts/check-skills.sh, so the installed scanner and the gate's expectation
# cannot drift apart.
# shellcheck source=lib/skillspector.sh
source "$SCRIPT_DIR/lib/skillspector.sh"

DARWIN_HOST=${NIX_DARWIN_HOST:-zoidberg}
NIXOS_HOST=${NIXOS_HOST:-}

# Generation retention for cleanup_generations. Every retained generation is a
# live GC root pinning its whole closure, so this value is the upper bound on
# how much the store can be reclaimed, not just a convenience setting.
GC_RETENTION=${GC_RETENTION:-45d}
GC_KEEP_MIN=${GC_KEEP_MIN:-5}

# A rebuild needs headroom for the new closure before any of the old one can be
# freed. Determinate's own collector only targets 5-20% free, which on a large
# disk is far less than a full system closure, so the script enforces its own
# floor before building.
MIN_FREE_GIB=${MIN_FREE_GIB:-50}
TEMP_FILES=()
FAILED_HOMEBREW_UPGRADES=()
STRANDED_CASK_APPS=()

track_temp_file() {
    TEMP_FILES+=("$1")
}

cleanup_temp_files() {
    local file
    for file in "${TEMP_FILES[@]}"; do
        rm -f -- "$file"
    done
}

trap cleanup_temp_files EXIT

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "\n${BLUE}===${NC} $1 ${BLUE}===${NC}"
}

print_indented_error() {
    local message=$1
    printf '  %s\n' "${message//$'\n'/$'\n  '}" >&2
}

confirm() {
    local prompt=$1

    read -p "$prompt (y/N): " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

ensure_skillspector() {
    if ! command -v uv > /dev/null 2>&1; then
        log_error "uv is required to install SkillSpector"
        exit 1
    fi

    local tool_python
    tool_python="$(uv tool dir)/skillspector/bin/python"
    if command -v skillspector > /dev/null 2>&1 && skillspector_version_matches_pin \
        && "$tool_python" -c 'import yara' > /dev/null 2>&1; then
        log_success "SkillSpector $SKILLSPECTOR_TAG is already installed"
        return 0
    fi

    # Transitional fallback: SkillSpector is not currently available as a
    # nixpkgs package, and upstream only ships via git (never published to
    # PyPI) -- install only when absent, at the wrong pinned tag, or with a
    # YARA analyzer that cannot load; normal upgrades reuse the
    # already-installed binary and stay offline.
    log_info "Installing pinned SkillSpector $SKILLSPECTOR_TAG..."
    if uv tool install --force --python "$SKILLSPECTOR_PYTHON" "skillspector @ git+${SKILLSPECTOR_REPO}@${SKILLSPECTOR_TAG}"; then
        log_success "SkillSpector $SKILLSPECTOR_TAG is ready"
    else
        log_error "Could not install SkillSpector $SKILLSPECTOR_TAG"
        exit 1
    fi
}

run_config_check() {
    if [[ "$SKIP_SKILL_SCAN" == true ]]; then
        ./scripts/check-config.sh --skip-skill-scan
    else
        ./scripts/check-config.sh
    fi
}

# Detect platform
detect_platform() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "darwin"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    else
        log_error "Unsupported platform: $OSTYPE"
        exit 1
    fi
}

# Check if we're in the dotfiles directory
check_directory() {
    if [[ ! -f "$REPO_ROOT/flake.nix" ]]; then
        log_error "Could not find flake.nix at repository root: $REPO_ROOT"
        exit 1
    fi
}

determinate_restart_hint() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "sudo launchctl kickstart -k system/org.nixos.nix-daemon"
    else
        echo "sudo systemctl restart nix-daemon"
    fi
}

resolve_nixos_host() {
    local host=${NIXOS_HOST:-}

    if [[ -z "$host" ]]; then
        case "$(uname -m)" in
            aarch64) host=farnsworth ;;
            x86_64) host=farnsworth-x86 ;;
            *)
                log_error "Unsupported Linux architecture for NixOS host selection: $(uname -m)"
                exit 1
                ;;
        esac
    fi

    case "$host" in
        farnsworth | farnsworth-x86)
            echo "$host"
            ;;
        *)
            log_error "Unknown NixOS host: $host"
            log_info "Supported hosts: farnsworth, farnsworth-x86"
            exit 1
            ;;
    esac
}

# Step 1: Check System Health
check_system_health() {
    log_step "Step 1: Checking System Health"

    if command -v determinate-nixd > /dev/null 2>&1; then
        log_info "Checking Determinate Systems daemon status..."
        daemon_status=""
        if daemon_status=$(determinate-nixd status 2>&1); then
            log_success "Determinate Systems daemon is healthy"
        elif echo "$daemon_status" | grep -q "invalid-token"; then
            log_warning "Authentication token expired (non-critical - only affects FlakeHub access)"
            log_info "To restore FlakeHub access, run: determinate-nixd login"
        else
            log_error "Determinate Systems daemon is not healthy"
            print_indented_error "$daemon_status"
            log_info "Try restarting with: $(determinate_restart_hint)"
            exit 1
        fi
    else
        log_warning "Determinate Systems daemon not found; skipping daemon health check"
    fi

    log_info "Validating current configuration..."
    if ! run_config_check; then
        log_error "Configuration validation failed"
        log_info "Fix configuration errors before proceeding"
        exit 1
    fi

    log_success "System health check passed"
}

# Step 2: Update Determinate Systems
update_determinate() {
    log_step "Step 2: Updating Determinate Systems"

    if ! command -v determinate-nixd > /dev/null 2>&1; then
        log_info "Determinate Systems not installed; skipping Nix daemon upgrade"
        return 0
    fi

    current_version=$(determinate_version)
    log_info "Current Determinate Nix version: $current_version"

    if ! sudo determinate-nixd upgrade; then
        # Not critical: the rest of the update works on the current daemon.
        log_warning "Determinate Systems upgrade failed; continuing"
        return 0
    fi

    new_version=$(determinate_version)
    if [[ "$new_version" == "$current_version" ]]; then
        log_success "Determinate Nix $current_version is already current"
        return 0
    fi
    log_success "Determinate Nix upgraded: $current_version -> $new_version"

    daemon_status=""
    if daemon_status=$(determinate-nixd status 2>&1); then
        log_success "Determinate Systems is healthy after upgrade"
    elif echo "$daemon_status" | grep -q "invalid-token"; then
        log_warning "Determinate Systems is running after upgrade (FlakeHub token expired)"
        log_info "This is non-critical. To restore FlakeHub access: determinate-nixd login"
    else
        log_error "Determinate Systems daemon issues after upgrade"
        print_indented_error "$daemon_status"
        log_info "Try restarting with: $(determinate_restart_hint)"
        exit 1
    fi
}

# First semantic version in `determinate-nixd version` output (the daemon's).
determinate_version() {
    local output version
    output=$(determinate-nixd version 2> /dev/null) || output=""
    version=$(grep -m1 -oE '[0-9]+\.[0-9]+\.[0-9]+' <<< "$output") || version="unknown"
    echo "$version"
}

# Step 3: Update Configuration
update_configuration() {
    log_step "Step 3: Updating Configuration"

    # Tag and commit pins never move with `nix flake update`; surface the ones that lag.
    log_info "Checking skill source pins against upstream..."
    ./scripts/check-skill-pins.sh || log_warning "Skill pin check failed; continuing"

    log_info "Updating flake inputs to latest versions..."
    # Unauthenticated GitHub API calls share a 60/hour per-IP budget, which one
    # flake update nearly exhausts. Lend Nix the gh CLI login for this call
    # only, through the environment so the token stays out of process args.
    local nix_config="${NIX_CONFIG:-}" github_token
    if github_token=$(gh auth token 2> /dev/null) && [[ -n "$github_token" ]]; then
        nix_config+=$'\n'"access-tokens = github.com=$github_token"
    fi
    if NIX_CONFIG="$nix_config" nix flake update; then
        log_success "Flake inputs updated successfully"
    else
        log_error "Failed to update flake inputs"
        exit 1
    fi

    log_info "Updating package-manager MCP runtime version pins..."
    if ./scripts/update-mcp-runtime-versions.py --write --sync-private-codex; then
        log_success "MCP runtime version pins updated successfully"
    else
        log_error "Failed to update MCP runtime version pins"
        exit 1
    fi

    log_info "Validating updated configuration..."
    if run_config_check; then
        log_success "Updated configuration is valid"
    else
        log_error "Updated configuration validation failed"
        log_info "You may need to fix compatibility issues with updated inputs"
        exit 1
    fi
}

render_homebrew_brewfile() {
    local brewfile=$1

    log_info "Rendering declarative Brewfile from the updated flake..."
    if ! nix eval --raw "$REPO_ROOT#darwinConfigurations.$DARWIN_HOST.config.homebrew.brewfile" > "$brewfile"; then
        log_error "Failed to render Homebrew Brewfile from nix-darwin configuration"
        return 1
    fi
}

list_declared_outdated_homebrew() {
    local brewfile=$1
    local kind=$2
    local outdated_args=()
    local declared_args=()
    local label

    case "$kind" in
        formula)
            declared_args=(--formula)
            outdated_args=(--formula)
            label="formulae"
            ;;
        cask)
            declared_args=(--cask)
            outdated_args=(--cask)
            if [[ "$UPGRADE_AUTO_UPDATE_CASKS" == true ]]; then
                outdated_args+=(--greedy)
            fi
            label="casks"
            ;;
        *)
            log_error "Unknown Homebrew dependency kind: $kind"
            return 1
            ;;
    esac

    local declared_file
    local outdated_file
    declared_file=$(mktemp -t nix-dotfiles-brew-declared.XXXXXX)
    outdated_file=$(mktemp -t nix-dotfiles-brew-outdated.XXXXXX)
    track_temp_file "$declared_file"
    track_temp_file "$outdated_file"

    if ! HOMEBREW_NO_AUTO_UPDATE=1 brew bundle list --file="$brewfile" "${declared_args[@]}" > "$declared_file"; then
        rm -f "$declared_file" "$outdated_file"
        log_error "Failed to list declared Homebrew $label"
        return 1
    fi

    if brew outdated "${outdated_args[@]}" > "$outdated_file"; then
        :
    else
        local brew_status=$?
        rm -f "$declared_file" "$outdated_file"
        log_error "Failed to query outdated Homebrew $label"
        return "$brew_status"
    fi

    awk 'NR == FNR { declared[$1] = 1; next } declared[$1] { print $1 }' "$declared_file" "$outdated_file" | sort -u
    rm -f "$declared_file" "$outdated_file"
}

upgrade_declared_homebrew() {
    local brewfile=$1
    local formulae_file
    local casks_file
    formulae_file=$(mktemp -t nix-dotfiles-brew-formulae.XXXXXX)
    casks_file=$(mktemp -t nix-dotfiles-brew-casks.XXXXXX)
    track_temp_file "$formulae_file"
    track_temp_file "$casks_file"

    list_declared_outdated_homebrew "$brewfile" formula > "$formulae_file"
    list_declared_outdated_homebrew "$brewfile" cask > "$casks_file"

    if [[ ! -s "$formulae_file" && ! -s "$casks_file" ]]; then
        rm -f "$formulae_file" "$casks_file"
        log_success "Declared Homebrew packages are already current"
        return 0
    fi

    log_warning "Mutable Homebrew upgrades requested explicitly"
    if [[ -s "$formulae_file" ]]; then
        log_info "Declared outdated formulae:"
        sed 's/^/  - /' "$formulae_file"
    fi
    if [[ -s "$casks_file" ]]; then
        log_info "Declared outdated casks:"
        sed 's/^/  - /' "$casks_file"
    fi

    if ! confirm "Upgrade the declared Homebrew packages listed above sequentially?"; then
        rm -f "$formulae_file" "$casks_file"
        log_warning "Skipping mutable Homebrew upgrades"
        return 0
    fi

    local name
    while IFS= read -r name; do
        [[ -n "$name" ]] || continue
        log_info "Upgrading Homebrew formula: $name"
        if ! HOMEBREW_NO_AUTO_UPDATE=1 brew upgrade "$name"; then
            FAILED_HOMEBREW_UPGRADES+=("formula:$name")
            log_warning "Homebrew formula upgrade failed; continuing: $name"
        fi
    done < "$formulae_file"

    local cask_log
    cask_log=$(mktemp -t nix-dotfiles-brew-cask.XXXXXX)
    track_temp_file "$cask_log"

    while IFS= read -r name; do
        [[ -n "$name" ]] || continue
        log_info "Upgrading Homebrew cask: $name"
        if ! HOMEBREW_NO_AUTO_UPDATE=1 brew upgrade --cask "$name" 2>&1 | tee "$cask_log"; then
            FAILED_HOMEBREW_UPGRADES+=("cask:$name")
            log_warning "Homebrew cask upgrade failed; continuing: $name"
            if grep -q "It seems there is already an App at" "$cask_log"; then
                log_info "App at destination is not owned by the cask; retry with: brew install --cask --force $name"
            fi
        fi
    done < "$casks_file"

    rm -f "$formulae_file" "$casks_file"
    if ((${#FAILED_HOMEBREW_UPGRADES[@]} == 0)); then
        log_success "Declared Homebrew upgrades completed"
    else
        log_warning "Declared Homebrew upgrades completed with failures"
    fi
}

prune_homebrew() {
    local brewfile=$1

    log_warning "Homebrew prune requested explicitly"
    log_info "Previewing Homebrew dependencies not declared in the generated Brewfile..."
    # `brew bundle cleanup` without `--force` is only a preview when it cannot
    # reach a terminal. On a TTY it prompts and, when the prompt is accepted,
    # performs the whole cleanup itself and then exits 0 - indistinguishable
    # here from having found nothing to prune. Closing stdin keeps the call a
    # true preview, so exit 1 means "would uninstall" and the removal stays
    # behind this script's own confirmation below.
    if HOMEBREW_NO_AUTO_UPDATE=1 brew bundle cleanup --file="$brewfile" --all < /dev/null; then
        log_success "No undeclared Homebrew dependencies to prune"
        return 0
    fi

    if ! confirm "Remove undeclared Homebrew dependencies shown above?"; then
        log_warning "Skipping Homebrew prune"
        return 0
    fi

    if HOMEBREW_NO_AUTO_UPDATE=1 brew bundle cleanup --file="$brewfile" --force --all; then
        log_success "Undeclared Homebrew dependencies pruned"
    else
        log_error "Homebrew bundle cleanup failed"
        return 1
    fi
}

# Homebrew installs a cask's `app` artifact by renaming the staged bundle out of
# the Caskroom into the app directory, and uninstalls it by renaming it back. An
# upgrade is both in sequence, so an upgrade that is interrupted or denied
# between the two can leave the bundle parked in the Caskroom with an empty
# directory at the install path. The receipt still records the version as
# installed, so `brew list --cask` and `brew outdated` keep reporting the cask as
# healthy while the app cannot launch at all.
#
# Finishing the rename needs no App Management grant: rename(2) onto an empty
# directory is permitted where deleting an app bundle is not. Anything other than
# an empty directory at the install path is reported instead of touched, because
# it is no longer the interrupted-rename shape and only a reinstall can repair it.
repair_stranded_cask_apps() {
    local appdir=/Applications
    if [[ "${HOMEBREW_CASK_OPTS:-}" =~ --appdir(=|[[:space:]]+)([^[:space:]]+) ]]; then
        appdir=${BASH_REMATCH[2]}
    fi

    local caskroom
    caskroom="$(brew --prefix)/Caskroom"
    [[ -d "$caskroom" ]] || return 0

    log_info "Checking installed casks for app bundles stranded in the Caskroom..."

    local repaired=0
    local staged
    local target
    local token
    while IFS= read -r -d '' staged; do
        # A symlink is how `brew install --cask --adopt` records a bundle it
        # adopted where it already stood, not a stranded one.
        [[ -L "$staged" ]] && continue
        [[ -d "$staged/Contents/MacOS" ]] || continue

        target="$appdir/$(basename "$staged")"
        token=$(basename "$(dirname "$(dirname "$staged")")")

        # Nothing at the install path is not the interrupted-rename shape. It
        # is also how a cask that stages an installer or a helper bundle looks
        # once it is correctly installed, so it carries no signal either way.
        [[ -d "$target" ]] || continue

        if [[ -n "$(ls -A "$target" 2> /dev/null)" ]]; then
            # A populated install path alongside a staged copy is only a
            # problem when the installed bundle is incomplete.
            if [[ ! -d "$target/Contents/MacOS" ]]; then
                log_warning "Cask $token has an incomplete app bundle at $target"
                log_info "Repair it with: brew reinstall --cask $token"
                STRANDED_CASK_APPS+=("$token")
            fi
            continue
        fi

        log_info "Finishing interrupted cask install for $token: $staged -> $target"
        if mv "$staged" "$appdir/"; then
            repaired=$((repaired + 1))
            log_success "Restored app bundle: $target"
        else
            log_warning "Could not restore app bundle: $target"
            log_info "Repair it with: brew reinstall --cask $token"
            STRANDED_CASK_APPS+=("$token")
        fi
    done < <(find "$caskroom" -mindepth 3 -maxdepth 3 -name "*.app" -print0 2> /dev/null)

    if ((repaired > 0)); then
        log_success "Restored $repaired stranded cask app bundle(s); relaunch those apps"
    elif ((${#STRANDED_CASK_APPS[@]} == 0)); then
        log_success "No stranded cask app bundles found"
    fi
}

# Step 4: Converge Homebrew declarations
update_homebrew() {
    local platform=$1

    if [[ "$platform" != "darwin" ]]; then
        return 0
    fi

    log_step "Step 4: Converging Homebrew declarations"

    if ! command -v brew > /dev/null 2>&1; then
        log_warning "Homebrew is not installed; skipping Homebrew update"
        return 0
    fi

    local brewfile
    brewfile=$(mktemp -t nix-dotfiles-Brewfile.XXXXXX)
    track_temp_file "$brewfile"

    if ! render_homebrew_brewfile "$brewfile"; then
        rm -f "$brewfile"
        exit 1
    fi

    log_info "Updating Homebrew metadata without upgrading installed packages..."
    if ! brew update; then
        rm -f "$brewfile"
        log_error "Homebrew update failed"
        exit 1
    fi

    log_info "Installing missing declared Homebrew packages without upgrading existing packages..."
    if ! HOMEBREW_NO_AUTO_UPDATE=1 brew bundle --file="$brewfile" --no-upgrade --jobs=1; then
        rm -f "$brewfile"
        log_error "Homebrew bundle convergence failed"
        # A self-updating app that Homebrew no longer tracks fails adoption here.
        log_info "If a cask failed with 'chgrp: ... Operation not permitted', re-adopt it from a terminal that has App Management permission: brew install --cask --adopt <cask>"
        exit 1
    fi

    log_success "Homebrew declarations are installed"

    if [[ "$UPGRADE_BREW" == true ]]; then
        if ! upgrade_declared_homebrew "$brewfile"; then
            rm -f "$brewfile"
            exit 1
        fi
    else
        log_info "Skipping mutable Homebrew upgrades; pass --upgrade-brew to opt in"
    fi

    if [[ "$PRUNE_BREW" == true ]]; then
        if ! prune_homebrew "$brewfile"; then
            rm -f "$brewfile"
            exit 1
        fi
    else
        log_info "Skipping Homebrew prune; pass --prune-brew to opt in"
    fi

    repair_stranded_cask_apps

    rm -f "$brewfile"
}

# Step 5: Apply Changes
apply_changes() {
    local platform=$1
    local rebuild_log
    local system_path
    log_step "Step 5: Applying Changes"

    case $platform in
        "darwin")
            # Only activation needs root; building the closure does not. Doing
            # the build first means a refused elevation costs nothing but the
            # activation itself, and leaves a store path that a later
            # `darwin-rebuild switch` activates without rebuilding.
            log_info "Building the macOS system closure without elevation..."
            if ! system_path=$(nix build "$REPO_ROOT#darwinConfigurations.$DARWIN_HOST.system" \
                --no-link --print-out-paths --show-trace); then
                log_error "Failed to build the macOS system closure"
                exit 1
            fi
            log_success "System closure built: $system_path"

            log_info "Activating the macOS configuration..."
            rebuild_log=$(mktemp -t nix-dotfiles-darwin-rebuild.XXXXXX)
            track_temp_file "$rebuild_log"
            if sudo darwin-rebuild switch --flake "$REPO_ROOT#$DARWIN_HOST" --show-trace 2>&1 | tee "$rebuild_log"; then
                log_success "macOS configuration applied successfully"
            elif grep -q "reloadHammerspoon" "$rebuild_log" && grep -q "Killed: 9" "$rebuild_log"; then
                # A failed Hammerspoon reload does not undo the activation.
                log_warning "Hammerspoon reload failed (non-critical)"
                log_info "Manually reloading Hammerspoon..."
                killall Hammerspoon 2> /dev/null || true
                sleep 1
                open -a Hammerspoon 2> /dev/null || true
                log_success "macOS configuration applied (with manual Hammerspoon reload)"
            elif grep -qiE "blocked by the IT-Admins|Endpoint Privilege Management" "$rebuild_log"; then
                # Endpoint policy refused the elevation, so nothing was
                # activated and no generation was created. A rollback hint
                # would point at the previous generation, which is still the
                # current one.
                log_error "Activation needs root and endpoint policy refused the sudo elevation"
                log_info "Everything up to activation is done; the built closure is $system_path"
                log_info "Activate it once elevation is available with: sudo darwin-rebuild switch --flake $REPO_ROOT#$DARWIN_HOST"
                exit 1
            else
                log_error "Failed to apply macOS configuration"
                log_info "You can rollback with: sudo nix-env --rollback --profile /nix/var/nix/profiles/system"
                exit 1
            fi
            ;;
        "linux")
            local nixos_host
            nixos_host=$(resolve_nixos_host)
            log_info "Applying Linux configuration changes..."
            log_info "Using NixOS host: $nixos_host"
            if sudo nixos-rebuild switch --flake "$REPO_ROOT#$nixos_host" --show-trace; then
                log_success "Linux configuration applied successfully"
            else
                log_error "Failed to apply Linux configuration"
                log_info "You can rollback with: sudo nix-env --rollback --profile /nix/var/nix/profiles/system"
                exit 1
            fi
            ;;
        *)
            log_error "Unknown platform: $platform"
            exit 1
            ;;
    esac
}

# Step 6: Verify System Health
verify_system_health() {
    log_step "Step 6: Verifying System Health"

    log_info "Confirming Determinate Systems is healthy..."
    if ! command -v determinate-nixd > /dev/null 2>&1; then
        log_info "Determinate Systems not installed; skipping daemon verification"
    else
        daemon_status=""
        if daemon_status=$(determinate-nixd status 2>&1); then
            log_success "Determinate Systems is healthy"
        elif echo "$daemon_status" | grep -q "invalid-token"; then
            log_success "Determinate Systems daemon is running (FlakeHub token expired)"
            log_info "This is non-critical. To restore FlakeHub access: determinate-nixd login"
        else
            log_warning "Determinate Systems status check failed"
            print_indented_error "$daemon_status"
            log_info "System may still be functional, but check daemon logs"
        fi
    fi

    log_info "Checking current system generation..."
    if sudo nix-env --list-generations --profile /nix/var/nix/profiles/system | tail -3; then
        log_success "System generation information displayed above"
    else
        log_warning "Could not retrieve system generation information"
    fi

    log_success "System update completed successfully!"
    log_info "Test your applications and tools to ensure everything works correctly"
}

# Remove macOS user-intent ACL markers from dead app bundles before GC.
scrub_macl_from_dead_apps() {
    if [[ "$(detect_platform)" != "darwin" ]]; then
        return 0
    fi

    local dead_paths_file
    dead_paths_file=$(mktemp -t nix-dotfiles-dead-paths.XXXXXX)
    track_temp_file "$dead_paths_file"

    log_info "Scanning dead Nix store paths for macOS app access-control metadata..."
    if ! nix-store --gc --print-dead > "$dead_paths_file"; then
        rm -f "$dead_paths_file"
        log_warning "Could not list dead store paths; skipping com.apple.macl scrub"
        return 0
    fi

    local scrubbed=0
    local prepared=0
    local dead_path
    local app_path
    while IFS= read -r dead_path; do
        [[ -d "$dead_path" ]] || continue

        while IFS= read -r -d '' app_path; do
            if xattr -p com.apple.macl "$app_path" > /dev/null 2>&1; then
                log_info "Removing com.apple.macl from dead app bundle: $app_path"
                if sudo xattr -d com.apple.macl "$app_path"; then
                    scrubbed=$((scrubbed + 1))
                else
                    log_warning "Could not remove com.apple.macl from: $app_path"
                fi
            fi

            log_info "Making dead app bundle directories writable for GC: $app_path"
            if sudo find "$app_path" -type d -exec chmod u+w {} +; then
                prepared=$((prepared + 1))
            else
                log_warning "Could not prepare app bundle directories for GC: $app_path"
            fi
        done < <(find "$dead_path" -type d -name "*.app" -prune -print0 2> /dev/null)
    done < "$dead_paths_file"

    rm -f "$dead_paths_file"

    if [[ "$scrubbed" -gt 0 ]]; then
        log_success "Removed com.apple.macl from $scrubbed dead app bundle(s)"
    else
        log_info "No com.apple.macl attributes found on dead app bundles"
    fi

    if [[ "$prepared" -gt 0 ]]; then
        log_success "Prepared $prepared dead app bundle(s) for garbage collection"
    fi
}

# Prune uv's cache.
#
# The MCP servers in this configuration run as `uv tool uvx ...` and
# `uv run --script ...`, which hold a shared lock on $UV_CACHE_DIR for their
# entire lifetime. Plain `uv cache prune` therefore blocks on the lock and
# times out whenever any MCP server is up - which is always. That is why the
# cache is able to grow without bound.
#
# `--force` skips the in-use check rather than the reference check: it still
# only removes entries no cached environment references, so environments the
# running servers execute from survive. Resolution and install work is a
# different matter, because it writes into the cache concurrently, so a uv
# process doing that is still a hard skip.
prune_uv_cache() {
    if ! command -v uv > /dev/null 2>&1; then
        log_info "uv is not installed; skipping uv cache prune"
        return 0
    fi

    local writing_uv_processes
    writing_uv_processes=$(
        ps -axo pid=,command= |
            awk '
                $0 !~ /uv cache (prune|clear)/ &&
                $0 !~ /awk / &&
                /(^|\/| )uv( |$)/ &&
                (/ (add|build|export|lock|pip|publish|remove|sync|venv|tree)( |$)/ ||
                 / tool (install|upgrade|uninstall)( |$)/ ||
                 / python (install|uninstall)( |$)/) {
                    print
                    count++
                }
                END { exit(count > 0 ? 0 : 1) }
            '
    ) || true

    if [[ -n "$writing_uv_processes" ]]; then
        log_warning "A uv process is writing to the cache; skipping uv cache prune"
        echo "$writing_uv_processes" | sed -n '1,10p'
        return 0
    fi

    local before
    before=$(du -sh "${UV_CACHE_DIR:-$HOME/.cache/uv}" 2> /dev/null | awk '{ print $1 }')
    log_info "Pruning uv cache (currently ${before:-unknown})..."

    if uv cache prune --force; then
        local after
        after=$(du -sh "${UV_CACHE_DIR:-$HOME/.cache/uv}" 2> /dev/null | awk '{ print $1 }')
        log_success "uv cache pruned (${before:-unknown} -> ${after:-unknown})"
    else
        log_warning "uv cache prune failed (non-critical)"
    fi

    log_info "A full reset needs the long-running uv MCP servers stopped first:"
    log_info "  quit Claude Code and headroom, then run: uv cache clear"
}

# Offer to drop the codebase-memory MCP graph cache.
#
# The cache is derived state: each graph is rebuilt on the next
# index_repository call, so dropping it costs indexing time, not data.
# It has no size bound of its own, so it is worth checking on every cleanup.
prune_codebase_memory_cache() {
    local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/codebase-memory-mcp"

    if [[ ! -d "$cache_dir" ]]; then
        log_info "No codebase-memory cache present; nothing to prune"
        return 0
    fi

    local size
    size=$(du -sh "$cache_dir" 2> /dev/null | awk '{ print $1 }')
    log_info "codebase-memory cache: ${size:-unknown} at $cache_dir"

    if ! confirm "Drop the codebase-memory graph cache? (rebuilt on next index)"; then
        log_info "Keeping the codebase-memory cache"
        return 0
    fi

    if rm -rf -- "$cache_dir"; then
        log_success "codebase-memory cache dropped"
    else
        log_warning "Could not drop the codebase-memory cache (non-critical)"
    fi
}

# Cleanup old generations
cleanup_generations() {
    log_step "Cleanup: Removing Old Generations"

    local retention="$GC_RETENTION"
    local user_profile="/nix/var/nix/profiles/per-user/$USER/profile"

    log_info "Cleaning up old generations (keeping last $retention, minimum $GC_KEEP_MIN)..."

    if command -v nh > /dev/null 2>&1; then
        log_info "Removing old generations with nh..."
        if ! nh clean all --keep "$GC_KEEP_MIN" --keep-since "$retention" --elevation-strategy auto --no-gc; then
            log_warning "nh generation cleanup failed (non-critical)"
        fi

        scrub_macl_from_dead_apps

        log_info "Running Nix store garbage collection and optimisation with nh..."
        if nh clean all --keep "$GC_KEEP_MIN" --keep-since "$retention" --elevation-strategy auto --optimise; then
            log_success "Old generations cleaned up, unreachable store paths deleted, and store optimised"
        else
            log_warning "nh store garbage collection failed (non-critical)"
        fi

        prune_uv_cache
        prune_codebase_memory_cache

        return 0
    fi

    if [[ -e /nix/var/nix/profiles/system ]]; then
        log_info "Removing system profile history older than $retention..."
        if ! sudo nix profile wipe-history --profile /nix/var/nix/profiles/system --older-than "$retention"; then
            log_warning "System profile history cleanup failed (non-critical)"
        fi
    fi

    if [[ -e "$user_profile" ]]; then
        log_info "Removing user profile history older than $retention..."
        if ! nix profile wipe-history --profile "$user_profile" --older-than "$retention"; then
            log_warning "User profile history cleanup failed (non-critical)"
        fi
    fi

    scrub_macl_from_dead_apps

    log_info "Running Nix store garbage collection..."
    if sudo nix store gc; then
        log_success "Old generations cleaned up and unreachable store paths deleted"
    else
        log_warning "Store garbage collection failed (non-critical)"
    fi

    log_info "Optimising Nix store..."
    if sudo nix store optimise; then
        log_success "Nix store optimised"
    else
        log_warning "Nix store optimisation failed (non-critical)"
    fi

    prune_uv_cache
    prune_codebase_memory_cache
}

# Report free GiB on the filesystem holding the Nix store.
free_store_gib() {
    # df -k is POSIX on both macOS and Linux; -P keeps the output on one line
    # even when the device name is long.
    df -Pk /nix/store 2>/dev/null | awk 'NR == 2 { printf "%d", $4 / 1024 / 1024 }'
}

# Guard the rebuild against running out of space mid-build.
#
# A rebuild that exhausts the disk aborts before any cleanup step can free
# space, so the next run starts from the same state and fails the same way.
# This runs before apply_changes and prunes generations first when space is
# short, which is the only ordering that breaks that cycle.
ensure_build_headroom() {
    log_step "Pre-flight: Nix Store Headroom"

    local free_gib
    free_gib=$(free_store_gib)

    if [[ -z "$free_gib" ]]; then
        log_warning "Could not determine free space on /nix/store; skipping headroom check"
        return 0
    fi

    log_info "Free space on /nix/store: ${free_gib} GiB (floor: ${MIN_FREE_GIB} GiB)"

    if [[ "$free_gib" -ge "$MIN_FREE_GIB" ]]; then
        log_success "Sufficient headroom for a rebuild"
        return 0
    fi

    log_warning "Below the ${MIN_FREE_GIB} GiB floor; a rebuild may fail part-way through"

    local generations=0
    if [[ -d /nix/var/nix/profiles ]]; then
        generations=$(find /nix/var/nix/profiles -maxdepth 1 -name 'system-*-link' | wc -l | tr -d ' ')
        log_info "System profile holds $generations generation(s), each pinning its full closure"
    fi

    if ! confirm "Run generation cleanup and garbage collection now, before building?"; then
        log_warning "Proceeding without cleanup; the rebuild may fail on low disk"
        return 0
    fi

    cleanup_generations

    free_gib=$(free_store_gib)
    log_info "Free space after cleanup: ${free_gib} GiB"

    if [[ -n "$free_gib" && "$free_gib" -lt "$MIN_FREE_GIB" ]]; then
        log_warning "Still below the ${MIN_FREE_GIB} GiB floor after cleanup"
        log_info "Largest reclaimable targets usually sit outside the Nix store:"
        log_info "  uv cache          : uv cache prune --force"
        log_info "  codebase-memory   : rm -rf \"${XDG_CACHE_HOME:-$HOME/.cache}/codebase-memory-mcp\""
        log_info "  container VM image: reclaim unused space in OrbStack or Colima"
        log_info "Inspect interactively with: ncdu ~  or  dust -d 1 -r ~"
        if ! confirm "Continue with the rebuild anyway?"; then
            log_info "Update cancelled by user"
            exit 0
        fi
    fi
}

# Main function
main() {
    echo -e "${GREEN}🚀 nix-dotfiles System Update${NC}"
    echo -e "${BLUE}Comprehensive update workflow for Determinate Systems Nix + nix-darwin/NixOS${NC}\n"

    # Pre-flight checks
    check_directory
    cd "$REPO_ROOT"
    local platform
    platform=$(detect_platform)
    log_info "Detected platform: $platform"

    # Ask for confirmation
    if ! confirm "Do you want to proceed with the system update?"; then
        log_info "Update cancelled by user"
        exit 0
    fi

    if [[ "$SKIP_SKILL_SCAN" == true ]]; then
        if ! confirm "Skip the SkillSpector security gate for this update?"; then
            log_info "Update cancelled"
            exit 0
        fi
        log_warning "SkillSpector gate bypassed for this update"
    else
        ensure_skillspector
    fi

    # Execute update workflow
    check_system_health
    ensure_build_headroom
    update_determinate
    update_configuration
    update_homebrew "$platform"
    apply_changes "$platform"
    verify_system_health

    # Optional cleanup
    if confirm "Do you want to clean up old generations?"; then
        cleanup_generations
    fi

    if ((${#FAILED_HOMEBREW_UPGRADES[@]} > 0 || ${#STRANDED_CASK_APPS[@]} > 0)); then
        echo -e "\n${YELLOW}⚠️ System update completed with Homebrew warnings.${NC}"
        echo -e "${BLUE}Your nix-dotfiles configuration is up to date; some Homebrew packages need attention.${NC}"
        if ((${#FAILED_HOMEBREW_UPGRADES[@]} > 0)); then
            log_warning "Homebrew upgrades not completed: ${FAILED_HOMEBREW_UPGRADES[*]}"
        fi
        if ((${#STRANDED_CASK_APPS[@]} > 0)); then
            log_warning "Casks with an unusable app bundle: ${STRANDED_CASK_APPS[*]}"
            log_info "Reinstall each one with: brew reinstall --cask <cask>"
        fi
    else
        echo -e "\n${GREEN}✅ System update completed successfully!${NC}"
        echo -e "${BLUE}Your nix-dotfiles configuration is now up to date.${NC}"
    fi
}

usage() {
    echo "nix-dotfiles System Update Script"
    echo
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  --help, -h       Show this help message"
    echo "  --dry-run        Show what would be done without executing"
    echo "  --cleanup        Clean generations older than \$GC_RETENTION (default 45d, keeping \$GC_KEEP_MIN), run Nix store GC, optimise the store, and prune caches"
    echo "  --upgrade-brew   Explicitly upgrade outdated Homebrew packages declared in the generated Brewfile"
    echo "  --upgrade-auto-update-casks  Include self-updating casks such as Cursor"
    echo "  --prune-brew     Explicitly remove Homebrew packages not declared in the generated Brewfile"
    echo "  --skip-skill-scan  Emergency bypass for the SkillSpector pre-rebuild gate"
    echo
    echo "Environment:"
    echo "  NIX_DARWIN_HOST  Darwin host (default: zoidberg)"
    echo "  NIXOS_HOST       NixOS host (default: architecture-based farnsworth host)"
    echo "  GC_RETENTION     Generation retention for cleanup (default: 45d)"
    echo "  GC_KEEP_MIN      Generations always kept regardless of age (default: 5)"
    echo "  MIN_FREE_GIB     Free-space floor enforced before a rebuild (default: 50)"
    echo
    echo "This script performs a comprehensive system update:"
    echo "0. Verify Nix store headroom, pruning generations first if space is short"
    echo "1. Check system health and evaluate declared host configurations"
    echo "2. Update Determinate Systems Nix"
    echo "3. Update flake inputs, MCP runtime pins, and re-evaluate declared host configurations"
    echo "4. Converge declared Homebrew packages on macOS without upgrading by default"
    echo "5. Apply configuration changes"
    echo "6. Verify system health"
    echo
    echo "Homebrew policy:"
    echo "- Default: install missing declared packages with --no-upgrade"
    echo "- --upgrade-brew: mutable, sequential, declared-only Homebrew upgrades"
    echo "- --upgrade-auto-update-casks: opt into upgrades for casks that update themselves"
    echo "- --prune-brew: destructive cleanup of undeclared Homebrew packages after confirmation"
}

dry_run() {
    echo "DRY RUN: Would perform the following steps:"
    if [[ "$CLEANUP_ONLY" == true ]]; then
        echo "Cleanup: Remove generations older than $GC_RETENTION (keeping at least $GC_KEEP_MIN), run Nix store GC, optimise the store, and prune caches"
        return 0
    fi
    echo "0. Verify Nix store headroom; prune generations before building if below ${MIN_FREE_GIB} GiB"
    echo "1. Check Determinate Systems daemon status and evaluate declared host configurations"
    echo "2. Upgrade Determinate Nix to latest version"
    echo "3. Update flake inputs and MCP runtime pins, then re-evaluate declared host configurations"
    echo "4. Run Homebrew metadata update and brew bundle --no-upgrade for declared packages on macOS"
    if [[ "$UPGRADE_BREW" == true ]]; then
        echo "4a. Explicitly upgrade outdated declared Homebrew packages sequentially"
        if [[ "$UPGRADE_AUTO_UPDATE_CASKS" == true ]]; then
            echo "4a. Include self-updating casks"
        fi
    fi
    if [[ "$PRUNE_BREW" == true ]]; then
        echo "4b. Preview and optionally prune undeclared Homebrew packages"
    fi
    echo "4c. Restore cask app bundles left stranded in the Caskroom by an interrupted install"
    echo "5. Apply configuration changes (darwin-rebuild/nixos-rebuild)"
    echo "6. Verify system health"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            "--help" | "-h")
                usage
                exit 0
                ;;
            "--dry-run")
                DRY_RUN=true
                ;;
            "--cleanup")
                CLEANUP_ONLY=true
                ;;
            "--upgrade-brew")
                UPGRADE_BREW=true
                ;;
            "--upgrade-auto-update-casks")
                UPGRADE_AUTO_UPDATE_CASKS=true
                UPGRADE_BREW=true
                ;;
            "--prune-brew")
                PRUNE_BREW=true
                ;;
            "--skip-skill-scan")
                SKIP_SKILL_SCAN=true
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
        shift
    done
}

parse_args "$@"

if [[ "$DRY_RUN" == true ]]; then
    dry_run
    exit 0
fi

if [[ "$CLEANUP_ONLY" == true ]]; then
    check_directory
    cd "$REPO_ROOT"
    if confirm "Remove old generations and run garbage collection?"; then
        cleanup_generations
    else
        log_info "Cleanup cancelled by user"
    fi
    exit 0
fi

main
