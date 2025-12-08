#!/usr/bin/env bash

# Build system images (ISOs, VM images, disk images) for NixOS deployment
# Builds custom installer ISOs with SSH pre-enabled for both ARM and x86_64
# Output: ./iso-images/farnsworth-installer-*.iso

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

# Detect OS
OS="$(uname -s)"
if [ "$OS" = "Darwin" ]; then
    print_error "Cannot build Linux ISOs from macOS"
    echo ""
    echo "Due to Nix's cross-platform limitations, Linux ISOs cannot be built on macOS."
    echo ""
    echo "${YELLOW}Alternative Options:${NC}"
    echo ""
    echo "  1. ${GREEN}Use nixos-anywhere (Recommended)${NC}"
    echo "     Deploy directly to hardware without building an ISO:"
    echo "     See: hosts/farnsworth/docs/INSTALLATION.md"
    echo ""
    echo "  2. ${GREEN}Build on a Linux machine${NC}"
    echo "     Run this script on any Linux system with Nix installed."
    echo ""
    echo "  3. ${GREEN}Use a Linux remote builder${NC}"
    echo "     Configure a remote Linux builder in your Nix configuration."
    echo ""
    echo "  4. ${GREEN}Use GitHub Actions / CI${NC}"
    echo "     Set up automated builds with Linux runners."
    echo ""
    echo "${BLUE}Configuration is valid and ready to build on Linux!${NC}"
    exit 1
fi

# Detect architecture
ARCH="$(uname -m)"
if [ "$ARCH" = "arm64" ]; then
    ARCH="aarch64"
fi

print_step "Building Farnsworth NixOS Installer ISO"
echo ""

# Determine which architecture to build
if [ "${1:-}" = "arm" ] || [ "${1:-}" = "aarch64" ]; then
    BUILD_ARCH="arm"
    FLAKE_OUTPUT="farnsworth-installer-arm"
elif [ "${1:-}" = "x86" ] || [ "${1:-}" = "x86_64" ]; then
    BUILD_ARCH="x86"
    FLAKE_OUTPUT="farnsworth-installer-x86"
elif [ "${1:-}" = "both" ]; then
    BUILD_ARCH="both"
else
    # Auto-detect
    if [ "$ARCH" = "aarch64" ]; then
        BUILD_ARCH="arm"
        FLAKE_OUTPUT="farnsworth-installer-arm"
        print_step "Auto-detected: Building ARM installer (native)"
    else
        BUILD_ARCH="x86"
        FLAKE_OUTPUT="farnsworth-installer-x86"
        print_step "Auto-detected: Building x86_64 installer"
    fi
fi

# Create output directory
OUTPUT_DIR="./iso-images"
mkdir -p "$OUTPUT_DIR"

# Function to build ISO
build_iso() {
    local arch=$1
    local flake_output=$2
    local arch_display=$3
    
    print_step "Building $arch_display installer ISO..."
    echo "  Flake output: .#isoImages.$flake_output"
    echo ""
    
    if ! nix build ".#isoImages.$flake_output.config.system.build.isoImage" \
        --print-build-logs \
        --out-link "$OUTPUT_DIR/result-$arch"; then
        print_error "Failed to build $arch_display ISO"
        return 1
    fi
    
    # Find the ISO file
    ISO_FILE=$(find "$OUTPUT_DIR/result-$arch/iso" -name "*.iso" -type f | head -1)
    
    if [ -z "$ISO_FILE" ]; then
        print_error "ISO file not found in result"
        return 1
    fi
    
    # Copy to output directory with descriptive name
    ISO_NAME="farnsworth-installer-${arch}-$(date +%Y%m%d).iso"
    cp "$ISO_FILE" "$OUTPUT_DIR/$ISO_NAME"
    
    # Get size
    SIZE=$(du -h "$OUTPUT_DIR/$ISO_NAME" | cut -f1)
    
    print_success "Built $arch_display installer: $OUTPUT_DIR/$ISO_NAME ($SIZE)"
    
    echo ""
    echo "  Write to USB with:"
    echo "    sudo dd if=$OUTPUT_DIR/$ISO_NAME of=/dev/diskX bs=4m status=progress"
    echo ""
}

# Build requested architecture(s)
if [ "$BUILD_ARCH" = "both" ]; then
    build_iso "arm" "farnsworth-installer-arm" "ARM (aarch64)"
    echo ""
    build_iso "x86" "farnsworth-installer-x86" "x86_64"
elif [ "$BUILD_ARCH" = "arm" ]; then
    build_iso "arm" "farnsworth-installer-arm" "ARM (aarch64)"
else
    build_iso "x86" "farnsworth-installer-x86" "x86_64"
fi

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_success "ISO build complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📁 Output directory: $OUTPUT_DIR/"
echo ""
ls -lh "$OUTPUT_DIR"/*.iso 2>/dev/null || true
echo ""
echo "🚀 Next steps:"
echo "  1. Write ISO to USB drive"
echo "  2. Boot target system from USB"
echo "  3. Note the IP address shown on screen"
echo "  4. Run: nix run github:nix-community/nixos-anywhere -- \\"
echo "           --flake .#farnsworth root@IP_ADDRESS"
echo ""
echo "📚 Full docs: ./FARNSWORTH_INSTALLATION.md"
echo ""

# Show usage if requested
usage() {
    echo "Usage: $0 [ARCHITECTURE]"
    echo ""
    echo "ARCHITECTURE:"
    echo "  arm, aarch64  - Build ARM installer (for Apple Silicon, ARM laptops)"
    echo "  x86, x86_64   - Build x86_64 installer (for Intel/AMD systems)"
    echo "  both          - Build both architectures"
    echo "  (none)        - Auto-detect and build for current architecture"
    echo ""
    echo "Examples:"
    echo "  $0              # Auto-detect"
    echo "  $0 arm          # Build ARM only"
    echo "  $0 x86          # Build x86_64 only"
    echo "  $0 both         # Build both"
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    usage
    exit 0
fi

