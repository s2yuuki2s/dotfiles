#!/usr/bin/env bash
set -euo pipefail

# Dotfiles Bootstrap Script
# Usage: curl -sSL https://raw.githubusercontent.com/username/dotfiles/main/bootstrap.sh | bash

REPO_URL="https://github.com/s2yuuki2s/dotfiles.git" # User should update this
INSTALL_DIR="$HOME/.dotfiles-temp"

echo "🚀 Starting Dotfiles Auto-Installer..."

# 1. Clone the repository
if [ -d "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"
fi

echo "Cloning repository..."
git clone "$REPO_URL" "$INSTALL_DIR"

# 2. Run the setup with cleanup flag
cd "$INSTALL_DIR"
chmod +x setup.sh
./setup.sh --cleanup

echo "✅ Installation finished and temporary files removed."
echo "Please restart your terminal or run: exec zsh -l"
