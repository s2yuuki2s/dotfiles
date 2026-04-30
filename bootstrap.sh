#!/usr/bin/env bash
set -euo pipefail

# Dotfiles Bootstrap Script
# Usage: curl -sSL https://raw.githubusercontent.com/s2yuuki2s/dotfiles/main/bootstrap.sh | bash

REPO_URL="https://github.com/s2yuuki2s/dotfiles.git"
INSTALL_DIR="$HOME/.dotfiles-temp"

# ANSI Colors
COLOR_RESET="\033[0m"
COLOR_INFO="\033[36m"
COLOR_SUCCESS="\033[32m"
COLOR_ERROR="\033[31m"

echo -e "${COLOR_INFO}ℹ Starting Dotfiles Auto-Installer...${COLOR_RESET}"

# 1. Clone the repository
if [ -d "$INSTALL_DIR" ]; then
    if [[ "$(basename "$INSTALL_DIR")" == ".dotfiles-temp" ]]; then
        rm -rf "$INSTALL_DIR"
    else
        echo -e "${COLOR_ERROR}✖ Refusing to remove unexpected install dir: $INSTALL_DIR${COLOR_RESET}" >&2
        exit 1
    fi
fi

echo -e "${COLOR_INFO}ℹ Cloning repository...${COLOR_RESET}"
git clone "$REPO_URL" "$INSTALL_DIR"

# 2. Run the setup with cleanup flag
cd "$INSTALL_DIR"
chmod +x setup.sh
./setup.sh --cleanup

echo -e "${COLOR_SUCCESS}✓ Installation finished and temporary files removed.${COLOR_RESET}"
echo -e "${COLOR_INFO}ℹ Please restart your terminal or run: exec zsh -l${COLOR_RESET}"
