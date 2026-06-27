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
PRUNE_BREW=false
DRY_RUN=false

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

confirm() {
    local prompt=$1

    read -p "$prompt (y/N): " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
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
    if [[ ! -f "flake.nix" ]]; then
        log_error "Must be run from the nix-dotfiles directory (where flake.nix exists)"
        exit 1
    fi
}

# Step 1: Check System Health
check_system_health() {
    log_step "Step 1: Checking System Health"

    log_info "Checking Determinate Systems daemon status..."
    daemon_status=$(sudo determinate-nixd status 2>&1)
    if echo "$daemon_status" | grep -q "invalid-token"; then
        log_warning "Authentication token expired (non-critical - only affects FlakeHub access)"
        log_info "To restore FlakeHub access, run: determinate-nixd login"
    elif ! echo "$daemon_status" | grep -q "Authentication:"; then
        log_error "Determinate Systems daemon is not healthy"
        log_info "Try restarting with: sudo launchctl kickstart -k system/org.nixos.nix-daemon"
        exit 1
    else
        log_success "Determinate Systems daemon is healthy"
    fi

    log_info "Validating current configuration..."
    if ! ./scripts/check-config.sh; then
        log_error "Configuration validation failed"
        log_info "Fix configuration errors before proceeding"
        exit 1
    fi

    log_success "System health check passed"
}

# Step 2: Update Determinate Systems
update_determinate() {
    log_step "Step 2: Updating Determinate Systems"

    log_info "Checking current Determinate Nix version..."
    current_version=$(determinate-nixd version 2>/dev/null || echo "unknown")
    log_info "Current version: $current_version"

    log_info "Upgrading Determinate Nix to latest version..."
    if sudo determinate-nixd upgrade; then
        log_success "Determinate Systems upgraded successfully"

        # Check new version
        new_version=$(determinate-nixd version 2>/dev/null || echo "unknown")
        log_info "New version: $new_version"

        # Verify upgrade
        log_info "Verifying upgrade completed successfully..."
        if sudo determinate-nixd status; then
            log_success "Determinate Systems is healthy after upgrade"
        else
            log_error "Determinate Systems daemon issues after upgrade"
            exit 1
        fi
    else
        log_warning "Determinate Systems upgrade failed or not needed"
        # Continue anyway as this might not be critical
    fi
}

# Step 3: Update Configuration
update_configuration() {
    log_step "Step 3: Updating Configuration"

    log_info "Updating flake inputs to latest versions..."
    if nix flake update; then
        log_success "Flake inputs updated successfully"
    else
        log_error "Failed to update flake inputs"
        exit 1
    fi

    log_info "Validating updated configuration..."
    if ./scripts/check-config.sh; then
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
    if ! nix eval --raw .#darwinConfigurations.zoidberg.config.homebrew.brewfile >"$brewfile"; then
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
            outdated_args=(--cask --greedy)
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

    if ! HOMEBREW_NO_AUTO_UPDATE=1 brew bundle list --file="$brewfile" "${declared_args[@]}" >"$declared_file"; then
        rm -f "$declared_file" "$outdated_file"
        log_error "Failed to list declared Homebrew $label"
        return 1
    fi

    if ! brew outdated "${outdated_args[@]}" >"$outdated_file"; then
        rm -f "$declared_file" "$outdated_file"
        return 0
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

    list_declared_outdated_homebrew "$brewfile" formula >"$formulae_file"
    list_declared_outdated_homebrew "$brewfile" cask >"$casks_file"

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
    local failed_name=""
    while IFS= read -r name; do
        [[ -n "$name" ]] || continue
        log_info "Upgrading Homebrew formula: $name"
        if ! HOMEBREW_NO_AUTO_UPDATE=1 brew upgrade "$name"; then
            failed_name=$name
            break
        fi
    done <"$formulae_file"

    if [[ -n "$failed_name" ]]; then
        rm -f "$formulae_file" "$casks_file"
        log_error "Homebrew formula upgrade failed: $failed_name"
        return 1
    fi

    while IFS= read -r name; do
        [[ -n "$name" ]] || continue
        log_info "Upgrading Homebrew cask: $name"
        if ! HOMEBREW_NO_AUTO_UPDATE=1 brew upgrade --cask "$name"; then
            failed_name=$name
            break
        fi
    done <"$casks_file"

    if [[ -n "$failed_name" ]]; then
        rm -f "$formulae_file" "$casks_file"
        log_error "Homebrew cask upgrade failed: $failed_name"
        return 1
    fi

    rm -f "$formulae_file" "$casks_file"
    log_success "Declared Homebrew upgrades completed"
}

prune_homebrew() {
    local brewfile=$1

    log_warning "Homebrew prune requested explicitly"
    log_info "Previewing Homebrew dependencies not declared in the generated Brewfile..."
    if HOMEBREW_NO_AUTO_UPDATE=1 brew bundle cleanup --file="$brewfile" --all; then
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

# Step 4: Converge Homebrew declarations
update_homebrew() {
    local platform=$1

    if [[ "$platform" != "darwin" ]]; then
        return 0
    fi

    log_step "Step 4: Converging Homebrew declarations"

    if ! command -v brew >/dev/null 2>&1; then
        log_warning "Homebrew is not installed; skipping Homebrew update"
        return 0
    fi

    local brewfile
    brewfile=$(mktemp -t nix-dotfiles-Brewfile.XXXXXX)

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

    rm -f "$brewfile"
}

# Step 5: Apply Changes
apply_changes() {
    local platform=$1
    log_step "Step 5: Applying Changes"

    case $platform in
        "darwin")
            log_info "Applying macOS configuration changes..."
            if sudo darwin-rebuild switch --flake ~/.config/nix-dotfiles/ --show-trace 2>&1 | tee /tmp/darwin-rebuild.log; then
                log_success "macOS configuration applied successfully"
            else
                # Check if failure was due to Hammerspoon reload (non-critical)
                if grep -q "reloadHammerspoon" /tmp/darwin-rebuild.log && grep -q "Killed: 9" /tmp/darwin-rebuild.log; then
                    log_warning "Hammerspoon reload failed (non-critical)"
                    log_info "Manually reloading Hammerspoon..."
                    killall Hammerspoon 2>/dev/null || true
                    sleep 1
                    open -a Hammerspoon 2>/dev/null || true
                    log_success "macOS configuration applied (with manual Hammerspoon reload)"
                else
                    log_error "Failed to apply macOS configuration"
                    log_info "You can rollback with: sudo nix-env --rollback --profile /nix/var/nix/profiles/system"
                    exit 1
                fi
            fi
            ;;
        "linux")
            log_info "Applying Linux configuration changes..."
            if sudo nixos-rebuild switch --flake ~/.config/nix-dotfiles/ --show-trace; then
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
    daemon_status=$(sudo determinate-nixd status 2>&1)
    if echo "$daemon_status" | grep -q "invalid-token"; then
        log_success "Determinate Systems daemon is running (FlakeHub token expired)"
        log_info "This is non-critical. To restore FlakeHub access: determinate-nixd login"
    elif echo "$daemon_status" | grep -q "Authentication:"; then
        log_success "Determinate Systems is healthy"
    else
        log_warning "Determinate Systems status check failed"
        log_info "System may still be functional, but check daemon logs"
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

    log_info "Scanning dead Nix store paths for macOS app access-control metadata..."
    if ! nix-store --gc --print-dead >"$dead_paths_file"; then
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
            if xattr -p com.apple.macl "$app_path" >/dev/null 2>&1; then
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
        done < <(find "$dead_path" -type d -name "*.app" -prune -print0 2>/dev/null)
    done <"$dead_paths_file"

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

# Prune uv's cache only when no uv-managed process is actively using it.
prune_uv_cache() {
    if ! command -v uv >/dev/null 2>&1; then
        log_info "uv is not installed; skipping uv cache prune"
        return 0
    fi

    local active_uv_processes
    active_uv_processes=$(
        ps -axo pid=,command= |
            awk '
                /(^|\/| )uv( |$)|\/\.cache\/uv\// &&
                $0 !~ /uv cache prune/ &&
                $0 !~ /awk / {
                    print
                    count++
                }
                END { exit(count > 0 ? 0 : 1) }
            '
    ) || true

    if [[ -n "$active_uv_processes" ]]; then
        log_warning "uv cache is currently in use; skipping uv cache prune"
        echo "$active_uv_processes" | sed -n '1,10p'
        return 0
    fi

    log_info "Pruning uv cache..."
    if uv cache prune; then
        log_success "uv cache pruned"
    else
        log_warning "uv cache prune failed (non-critical)"
    fi
}

# Cleanup old generations
cleanup_generations() {
    log_step "Cleanup: Removing Old Generations"

    local retention="180d"
    local user_profile="/nix/var/nix/profiles/per-user/$USER/profile"

    log_info "Cleaning up old generations (keeping last $retention)..."

    if command -v nh >/dev/null 2>&1; then
        log_info "Removing old generations with nh..."
        if ! nh clean all --keep-since "$retention" --elevation-strategy auto --no-gc; then
            log_warning "nh generation cleanup failed (non-critical)"
        fi

        scrub_macl_from_dead_apps

        log_info "Running Nix store garbage collection and optimisation with nh..."
        if nh clean all --keep-since "$retention" --elevation-strategy auto --optimise; then
            log_success "Old generations cleaned up, unreachable store paths deleted, and store optimised"
        else
            log_warning "nh store garbage collection failed (non-critical)"
        fi

        prune_uv_cache

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
}

# Main function
main() {
    echo -e "${GREEN}🚀 nix-dotfiles System Update${NC}"
    echo -e "${BLUE}Comprehensive update workflow for Determinate Systems Nix + nix-darwin/NixOS${NC}\n"

    # Pre-flight checks
    check_directory
    local platform
    platform=$(detect_platform)
    log_info "Detected platform: $platform"

    # Ask for confirmation
    if ! confirm "Do you want to proceed with the system update?"; then
        log_info "Update cancelled by user"
        exit 0
    fi

    # Execute update workflow
    check_system_health
    update_determinate
    update_configuration
    update_homebrew "$platform"
    apply_changes "$platform"
    verify_system_health

    # Optional cleanup
    if confirm "Do you want to clean up old generations?"; then
        cleanup_generations
    fi

    echo -e "\n${GREEN}✅ System update completed successfully!${NC}"
    echo -e "${BLUE}Your nix-dotfiles configuration is now up to date.${NC}"
}

usage() {
        echo "nix-dotfiles System Update Script"
        echo
        echo "Usage: $0 [OPTIONS]"
        echo
        echo "Options:"
        echo "  --help, -h       Show this help message"
        echo "  --dry-run        Show what would be done without executing"
        echo "  --cleanup        Clean generations older than 180 days, run Nix store GC, optimise the store, and prune caches"
        echo "  --upgrade-brew   Explicitly upgrade outdated Homebrew packages declared in the generated Brewfile"
        echo "  --prune-brew     Explicitly remove Homebrew packages not declared in the generated Brewfile"
        echo
        echo "This script performs a comprehensive system update:"
        echo "1. Check system health and evaluate declared host configurations"
        echo "2. Update Determinate Systems Nix"
        echo "3. Update flake inputs and re-evaluate declared host configurations"
        echo "4. Converge declared Homebrew packages on macOS without upgrading by default"
        echo "5. Apply configuration changes"
        echo "6. Verify system health"
        echo
        echo "Homebrew policy:"
        echo "- Default: install missing declared packages with --no-upgrade"
        echo "- --upgrade-brew: mutable, sequential, declared-only Homebrew upgrades"
        echo "- --prune-brew: destructive cleanup of undeclared Homebrew packages after confirmation"
}

dry_run() {
        echo "DRY RUN: Would perform the following steps:"
        echo "1. Check Determinate Systems daemon status and evaluate declared host configurations"
        echo "2. Upgrade Determinate Nix to latest version"
        echo "3. Update flake inputs (nix flake update) and re-evaluate declared host configurations"
        echo "4. Run Homebrew metadata update and brew bundle --no-upgrade for declared packages on macOS"
        if [[ "$UPGRADE_BREW" == true ]]; then
            echo "4a. Explicitly upgrade outdated declared Homebrew packages sequentially"
        fi
        if [[ "$PRUNE_BREW" == true ]]; then
            echo "4b. Preview and optionally prune undeclared Homebrew packages"
        fi
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
                check_directory
                cleanup_generations
                exit 0
                ;;
            "--upgrade-brew")
                UPGRADE_BREW=true
                ;;
            "--prune-brew")
                PRUNE_BREW=true
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

main
