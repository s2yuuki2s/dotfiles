#!/usr/bin/env bash
set -euo pipefail

[[ -z "${DOTFILES_DIR:-}" ]] && DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$DOTFILES_DIR/lib/utils.sh"

info "== Installing UV (Python Package Manager) =="

if ! command -v uv >/dev/null 2>&1; then
    curl -LsSf https://astral.sh/uv/install.sh | INSTALLER_NO_MODIFY_PATH=1 sh
fi

# Static completions for Zsh
if [[ -d "$HOME/.oh-my-zsh" ]]; then
    ZSH_COMP_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/completions"
    mkdir -p "$ZSH_COMP_DIR"
    export PATH="$HOME/.local/bin:$PATH"
    uv generate-shell-completion zsh >"$ZSH_COMP_DIR/_uv"
    uvx --generate-shell-completion zsh >"$ZSH_COMP_DIR/_uvx"
fi

info "✅ UV setup complete."
