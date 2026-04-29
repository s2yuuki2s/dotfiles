#!/usr/bin/env bash
set -euo pipefail

[[ -z "${DOTFILES_DIR:-}" ]] && DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$DOTFILES_DIR/lib/utils.sh"

info "== Installing FNM (Fast Node Manager) =="

if ! command -v fnm >/dev/null 2>&1; then
    run_remote_script "https://fnm.vercel.app/install" bash --skip-shell
fi

# This PATH export is only for this installer process so `fnm` is immediately
# available after installation. Persistent shell PATH is managed in terminal.sh.
FNM_BIN_DIR="$HOME/.local/share/fnm"
export PATH="$FNM_BIN_DIR:$PATH"

# Generate static completion for Oh My Zsh users.
if [[ -d "$HOME/.oh-my-zsh" ]]; then
    install_zsh_completion "fnm" "fnm completions --shell zsh"
else
    warn "Oh My Zsh not found, skipping fnm zsh completion."
fi

info "✅ FNM setup complete."
