#!/usr/bin/env bash
set -euo pipefail

[[ -z "${DOTFILES_DIR:-}" ]] && DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=lib/utils.sh
source "$DOTFILES_DIR/lib/utils.sh"

info "== Installing Zellij (Terminal Workspace) =="

install_from_github "zellij-org/zellij" "zellij" "tar.gz"

# Static completions for Zsh
install_zsh_completion "zellij" "zellij setup --generate-completion zsh"

info "✅ Zellij setup complete."
