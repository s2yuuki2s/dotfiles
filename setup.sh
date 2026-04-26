#!/usr/bin/env bash
set -euo pipefail

# Load utilities
DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$DOTFILES_DIR/lib/utils.sh"

info "Starting Dotfiles setup..."

# Keep-alive sudo
sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# Initial system update
info "Updating system repositories..."
sudo apt-get update

# Core dependencies
apt_install curl wget jq git build-essential

# Run installation scripts
scripts=(
    "zsh.sh"
    "terminal.sh"
    "fnm.sh"
    "uv.sh"
    "rust.sh"
    "neovim.sh"
    "zellij.sh"
    "docker.sh"
    "lazydocker.sh"
)

for script in "${scripts[@]}"; do
    script_path="$DOTFILES_DIR/installs/$script"
    if [[ -f "$script_path" ]]; then
        info "Executing $script..."
        bash "$script_path"
    else
        warn "Script $script not found, skipping."
    fi
done

info "🎉 All installations completed! Please restart your terminal."
