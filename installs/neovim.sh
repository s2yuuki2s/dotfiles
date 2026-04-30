#!/usr/bin/env bash
set -euo pipefail

[[ -z "${DOTFILES_DIR:-}" ]] && DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=lib/utils.sh
source "$DOTFILES_DIR/lib/utils.sh"

info "== Installing Neovim (Latest) =="

# 1. Install Neovim via GitHub AppImage
install_from_github "neovim/neovim" "nvim" ".appimage"

# 2. Setup LazyVim (Optional starter)
if [[ ! -d "$HOME/.config/nvim" ]]; then
    info "Cloning LazyVim starter..."
    git clone https://github.com/LazyVim/starter "$HOME/.config/nvim"
    rm -rf "$HOME/.config/nvim/.git"
fi

info "✅ Neovim setup complete."
