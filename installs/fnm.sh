#!/usr/bin/env bash
set -euo pipefail

[[ -z "${DOTFILES_DIR:-}" ]] && DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$DOTFILES_DIR/lib/utils.sh"

info "== Installing FNM (Fast Node Manager) =="

if ! command -v fnm >/dev/null 2>&1; then
    curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
fi

# Static completions for Zsh
export PATH="$HOME/.local/share/fnm:$PATH"
install_zsh_completion "fnm" "fnm completions --shell zsh"

info "✅ FNM setup complete."
