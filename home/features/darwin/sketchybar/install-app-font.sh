#!/bin/bash

# Install sketchybar-app-font in reproducible way for Nix configuration
# Based on: https://github.com/kvndrsslr/sketchybar-app-font

set -euo pipefail

# Ensure system tools are available (including git)
export PATH="/opt/homebrew/bin:/usr/bin:/bin:$PATH"

FONT_REPO_DIR="$HOME/.local/share/sketchybar-app-font"
FONT_FILE="$HOME/Library/Fonts/sketchybar-app-font.ttf"
ICON_MAP_FILE="$HOME/.config/sketchybar/helpers/icon_map.sh"

echo "🎨 Installing sketchybar-app-font..."

# Ensure we have pnpm available
if ! command -v pnpm >/dev/null 2>&1; then
    echo "❌ pnpm not found. Make sure Homebrew configuration is applied first."
    exit 1
fi

# Ensure required directories exist
mkdir -p "$(dirname "$FONT_FILE")"
mkdir -p "$(dirname "$ICON_MAP_FILE")"
mkdir -p "$HOME/.local/share"

# Clone or update the repository
if [ -d "$FONT_REPO_DIR" ]; then
    echo "🔄 Updating existing sketchybar-app-font repository..."
    cd "$FONT_REPO_DIR"
    git pull origin main
else
    echo "📦 Cloning sketchybar-app-font repository..."
    git clone https://github.com/kvndrsslr/sketchybar-app-font.git "$FONT_REPO_DIR"
    cd "$FONT_REPO_DIR"
fi

# Install dependencies and build font
echo "🔨 Building font and installing..."
pnpm install
pnpm run build || {
    echo "❌ pnpm build failed, trying manual installation..."
    
    # Manual fallback installation
    if [ -f "dist/sketchybar-app-font.ttf" ] && [ -f "dist/icon_map.sh" ]; then
        echo "📦 Installing files manually..."
        cp "dist/sketchybar-app-font.ttf" "$FONT_FILE"
        cp "dist/icon_map.sh" "$ICON_MAP_FILE"
        chmod +x "$ICON_MAP_FILE"
        echo "✅ Manual installation completed"
    else
        echo "❌ Required files not found in dist/"
        exit 1
    fi
}

# Try the official install command, with fallback to manual
if ! pnpm run build:install 2>/dev/null; then
    echo "⚠️  Official installer failed, using manual approach..."
    
    # Ensure build outputs exist
    if [ ! -f "dist/sketchybar-app-font.ttf" ]; then
        echo "❌ Font file not generated. Running build first..."
        pnpm run build
    fi
    
    # Manual installation
    if [ -f "dist/sketchybar-app-font.ttf" ]; then
        cp "dist/sketchybar-app-font.ttf" "$FONT_FILE"
        echo "✅ Font copied to: $FONT_FILE"
    fi
    
    if [ -f "dist/icon_map.sh" ]; then
        cp "dist/icon_map.sh" "$ICON_MAP_FILE"
        chmod +x "$ICON_MAP_FILE"
        echo "✅ Icon map copied to: $ICON_MAP_FILE"
    fi
fi

# Verify installation
if [ -f "$FONT_FILE" ]; then
    echo "✅ Font installed successfully: $FONT_FILE"
else
    echo "❌ Font installation failed"
    exit 1
fi

if [ -f "$ICON_MAP_FILE" ]; then
    echo "✅ Icon map installed successfully: $ICON_MAP_FILE"
else
    echo "❌ Icon map installation failed"
    exit 1
fi

echo "🎉 sketchybar-app-font installation complete!"
echo "📝 You can now use app-specific icons like :cursor:, :chrome:, :slack: in SketchyBar"
echo "🔧 Professional app icons are now integrated into the front_app plugin"
