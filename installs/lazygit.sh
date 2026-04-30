#!/usr/bin/env bash
set -euo pipefail

[[ -z "${DOTFILES_DIR:-}" ]] && DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=lib/utils.sh
source "$DOTFILES_DIR/lib/utils.sh"

info "Installing Lazygit"

install_from_github "jesseduffield/lazygit" "lazygit" "tar.gz"

success "Lazygit setup complete."
