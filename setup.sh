#!/usr/bin/env bash
set -euo pipefail

# Load utilities
DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$DOTFILES_DIR/lib/utils.sh"

info "Starting Dotfiles setup..."

CLEANUP=false
if [[ "${1:-}" == "--cleanup" ]]; then
    CLEANUP=true
    info "Cleanup mode enabled: Directory will be removed after installation."
fi

# Keep-alive sudo
sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
SUDO_PID=$!

cleanup() {
    local exit_code=$?
    if [[ $SUDO_PID -ne 0 ]]; then
        kill "$SUDO_PID" 2>/dev/null || true
    fi
    if [[ $exit_code -ne 0 ]]; then
        error "Setup failed with exit code $exit_code"
    fi
}
trap cleanup EXIT ERR

# Initial system update
info "Updating system repositories..."
sudo apt-get update

# Core dependencies
apt_install curl wget jq git build-essential zip unzip

# Run installation scripts
scripts=(
    "zsh.sh"
    "terminal.sh"
    "fnm.sh"
    "uv.sh"
    "rust.sh"
    "sdkman.sh"
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

if [[ "$CLEANUP" == true ]]; then
    info "Cleaning up: Removing $DOTFILES_DIR..."
    rm -rf "$DOTFILES_DIR"
fi
