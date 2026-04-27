#!/usr/bin/env bash
set -euo pipefail

# Dotfiles Bootstrap Script
# Usage: curl -sSL https://raw.githubusercontent.com/s2yuuki2s/dotfiles/main/bootstrap.sh | bash

REPO_URL="https://github.com/s2yuuki2s/dotfiles.git"
INSTALL_DIR="$HOME/.dotfiles-temp"

echo "🚀 Starting Dotfiles Auto-Installer..."

# 1. Clone the repository
if [ -d "$INSTALL_DIR" ]; then
    if [[ "$(basename "$INSTALL_DIR")" == ".dotfiles-temp" ]]; then
        rm -rf "$INSTALL_DIR"
    else
        echo "❌ Refusing to remove unexpected install dir: $INSTALL_DIR" >&2
        exit 1
    fi
fi

echo "Cloning repository..."
git clone "$REPO_URL" "$INSTALL_DIR"

# 2. Run the setup with cleanup flag
cd "$INSTALL_DIR"
chmod +x setup.sh
./setup.sh --cleanup

echo "✅ Installation finished and temporary files removed."
echo "Please restart your terminal or run: exec zsh -l"
