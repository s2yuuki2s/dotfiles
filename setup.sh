#!/usr/bin/env bash
set -euo pipefail

echo "== Dotfiles Auto-Setup =="

# Ensure we are in the script directory
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

# Ensure the script is NOT run as root directly
if [[ $EUID -eq 0 ]]; then
   echo "❌ Error: Please do not run this script as root/sudo."
   echo "The script will ask for sudo password when needed."
   exit 1
fi

# Architecture Detection
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)  export OS_ARCH="x86_64" ;;
    aarch64) export OS_ARCH="arm64" ;;
    *)       echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac
echo "Detected architecture: $OS_ARCH"

# Ask for sudo upfront
echo "Please provide sudo password to start installation:"
sudo -v

# Keep sudo alive and ensure it's killed on exit
while true; do
  sudo -n true
  sleep 60
  kill -0 "$$" || exit
done 2>/dev/null &
SUDO_PID=$!
trap 'kill $SUDO_PID' EXIT

# Export flag for non-interactive installation
export AUTO_YES=true

# Make all scripts executable
chmod +x installs/*.sh

# 1. Base Shell & Tools (Must be first)
./installs/zsh.sh
./installs/terminal.sh

# 2. Virtualization & Infrastructure
./installs/docker.sh
./installs/lazydocker.sh

# 3. Programming Languages & Version Managers
./installs/fnm.sh
./installs/rust.sh
./installs/uv.sh

# 4. Terminal Applications
./installs/neovim.sh
./installs/zellij.sh

echo "=========================================="
echo "   ✅ All installations complete!"
echo ""
echo "   To start using everything immediately, run:"
echo "   exec zsh -l"
echo "=========================================="

# Auto-delete logic
if [[ "${1:-}" == "--cleanup" ]]; then
    echo "Cleaning up installer files..."
    cd "$HOME"
    rm -rf "$DIR"
    echo "Installer files deleted."
fi
