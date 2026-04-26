#!/usr/bin/env bash
set -euo pipefail

[[ -z "${DOTFILES_DIR:-}" ]] && DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$DOTFILES_DIR/lib/utils.sh"

info "== Installing Zellij (Terminal Workspace) =="

install_from_github "zellij-org/zellij" "zellij" "tar.gz"

# Static completions for Zsh
if [[ -d "$HOME/.oh-my-zsh" ]]; then
    ZSH_COMP_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/completions"
    mkdir -p "$ZSH_COMP_DIR"
    zellij setup --generate-completion zsh >"$ZSH_COMP_DIR/_zellij"
fi

info "✅ Zellij setup complete."
