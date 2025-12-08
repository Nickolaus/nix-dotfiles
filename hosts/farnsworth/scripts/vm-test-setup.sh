#!/usr/bin/env bash

# Farnsworth VM Test Setup Script
# Automates downloading NixOS ISO and preparing for UTM testing

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step() { echo -e "${BLUE}==>${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }

# Detect architecture
ARCH="$(uname -m)"
if [ "$ARCH" = "arm64" ]; then
    ARCH="aarch64"
fi

print_step "Detected architecture: $ARCH"

# Check if UTM is installed
check_utm() {
    if [ -d "/Applications/UTM.app" ]; then
        print_success "UTM is installed"
        return 0
    else
        print_warning "UTM is not installed"
        echo ""
        echo "Install UTM using one of these methods:"
        echo "  1. Homebrew: brew install --cask utm"
        echo "  2. Direct: https://mac.getutm.app/"
        echo "  3. App Store: https://apps.apple.com/app/utm-virtual-machines/id1538878817"
        echo ""
        read -p "Open UTM download page in browser? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            open "https://mac.getutm.app/"
        fi
        return 1
    fi
}

# Download NixOS ISO
download_iso() {
    local arch="$1"
    local download_dir="${2:-$HOME/Downloads}"
    
    mkdir -p "$download_dir"
    
    if [ "$arch" = "aarch64" ]; then
        ISO_URL="https://channels.nixos.org/nixos-unstable/latest-nixos-minimal-aarch64-linux.iso"
        ISO_NAME="nixos-minimal-aarch64-linux.iso"
    else
        ISO_URL="https://channels.nixos.org/nixos-unstable/latest-nixos-minimal-x86_64-linux.iso"
        ISO_NAME="nixos-minimal-x86_64-linux.iso"
    fi
    
    ISO_PATH="$download_dir/$ISO_NAME"
    
    if [ -f "$ISO_PATH" ]; then
        print_success "ISO already exists: $ISO_PATH"
        local size=$(du -h "$ISO_PATH" | cut -f1)
        echo "  Size: $size"
        echo ""
        read -p "Re-download? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 0
        fi
    fi
    
    print_step "Downloading NixOS ISO for $arch..."
    echo "  URL: $ISO_URL"
    echo "  Destination: $ISO_PATH"
    echo ""
    
    if command -v curl &> /dev/null; then
        curl -# -L -o "$ISO_PATH" "$ISO_URL"
    elif command -v wget &> /dev/null; then
        wget --show-progress -O "$ISO_PATH" "$ISO_URL"
    else
        print_error "Neither curl nor wget found!"
        exit 1
    fi
    
    print_success "Downloaded: $ISO_PATH"
    local size=$(du -h "$ISO_PATH" | cut -f1)
    echo "  Size: $size"
}

# Create disko config for VM testing
create_vm_disko_config() {
    local config_dir="$1"
    local vm_disko="$config_dir/hosts/farnsworth/disko-vm.nix"
    
    if [ -f "$vm_disko" ]; then
        print_warning "VM disko config already exists: $vm_disko"
        return 0
    fi
    
    print_step "Creating VM-specific disko config..."
    
    cat > "$vm_disko" << 'EOF'
# VM-specific disko configuration
# Uses /dev/vda which is standard for QEMU/UTM VMs
# This overrides the main disko.nix for testing

{ config, lib, pkgs, ... }:

{
  imports = [ ./disko.nix ];
  
  # Override disk device for VM
  disko.devices.disk.main.device = lib.mkForce "/dev/vda";
}
EOF
    
    print_success "Created VM disko config: $vm_disko"
    echo "  This uses /dev/vda (standard for UTM/QEMU VMs)"
}

# Print next steps
print_next_steps() {
    local iso_path="$1"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_success "Setup complete! Next steps:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "1. Open UTM and create a new VM:"
    echo "   • Click 'Create a New Virtual Machine'"
    echo "   • Choose 'Virtualize' (faster on Apple Silicon)"
    echo "   • Select 'Linux'"
    echo "   • Use ISO: $iso_path"
    echo "   • Memory: 8 GB, CPU: 4 cores, Storage: 64 GB"
    echo ""
    echo "2. Boot the VM and follow the installation guide:"
    echo "   • Read: FARNSWORTH_VM_TESTING.md"
    echo "   • Use disko config: hosts/farnsworth/disko-vm.nix"
    echo ""
    echo "3. Quick start commands in VM:"
    echo "   loadkeys de"
    echo "   mkdir -p ~/.config/nix"
    echo "   echo 'experimental-features = nix-command flakes' > ~/.config/nix/nix.conf"
    echo "   nix-shell -p git"
    echo "   git clone YOUR_REPO /tmp/nix-dotfiles"
    echo ""
    echo "4. Full guide: cat FARNSWORTH_VM_TESTING.md"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Main
main() {
    echo "╔══════════════════════════════════════════════════╗"
    echo "║  Farnsworth VM Testing Setup                    ║"
    echo "║  Prepares NixOS ISO and configs for UTM testing ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo ""
    
    # Check prerequisites
    if ! check_utm; then
        print_error "Please install UTM first, then re-run this script."
        exit 1
    fi
    
    # Determine architecture to download
    echo ""
    print_step "Which architecture do you want to test?"
    echo "  1. ARM (aarch64) - Recommended for Apple Silicon (faster)"
    echo "  2. x86_64 - For testing x86_64 variant (slower, emulated)"
    echo "  3. Both"
    echo ""
    read -p "Choice (1/2/3, default: 1): " choice
    choice="${choice:-1}"
    
    case "$choice" in
        1)
            download_iso "aarch64"
            ISO_PATH="$HOME/Downloads/nixos-minimal-aarch64-linux.iso"
            ;;
        2)
            download_iso "x86_64"
            ISO_PATH="$HOME/Downloads/nixos-minimal-x86_64-linux.iso"
            ;;
        3)
            download_iso "aarch64"
            download_iso "x86_64"
            ISO_PATH="$HOME/Downloads/nixos-minimal-aarch64-linux.iso (and x86_64)"
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac
    
    # Create VM-specific disko config
    echo ""
    DOTFILES_DIR="${1:-$(pwd)}"
    if [ -d "$DOTFILES_DIR/hosts/farnsworth" ]; then
        create_vm_disko_config "$DOTFILES_DIR"
    else
        print_warning "Not in nix-dotfiles directory, skipping disko config creation"
    fi
    
    # Print next steps
    print_next_steps "$ISO_PATH"
}

# Run main with optional directory argument
main "$@"

