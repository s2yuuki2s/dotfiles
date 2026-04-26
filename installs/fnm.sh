#!/usr/bin/env bash
set -euo pipefail

[[ -z "${DOTFILES_DIR:-}" ]] && DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$DOTFILES_DIR/lib/utils.sh"

info "== Installing FNM (Fast Node Manager) =="

if ! command -v fnm >/dev/null 2>&1; then
    curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
fi

# Static completions for Zsh
if [[ -d "$HOME/.oh-my-zsh" ]]; then
    ZSH_COMP_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/completions"
    mkdir -p "$ZSH_COMP_DIR"
    export PATH="$HOME/.local/share/fnm:$PATH"
    fnm completions --shell zsh >"$ZSH_COMP_DIR/_fnm"
fi

info "✅ FNM setup complete."
