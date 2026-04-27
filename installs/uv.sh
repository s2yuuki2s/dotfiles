#!/usr/bin/env bash
set -euo pipefail

[[ -z "${DOTFILES_DIR:-}" ]] && DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$DOTFILES_DIR/lib/utils.sh"

info "== Installing UV (Python Package Manager) =="

if ! command -v uv >/dev/null 2>&1; then
    tmp_uv_installer=$(mktemp)
    download_to_file "https://astral.sh/uv/install.sh" "$tmp_uv_installer"
    if ! INSTALLER_NO_MODIFY_PATH=1 sh "$tmp_uv_installer"; then
        rm -f "$tmp_uv_installer"
        error "UV installer failed"
    fi
    rm -f "$tmp_uv_installer"
fi

# Static completions for Zsh
export PATH="$HOME/.local/bin:$PATH"
install_zsh_completion "uv" "uv generate-shell-completion zsh"
install_zsh_completion "uvx" "uvx --generate-shell-completion zsh"


info "✅ UV setup complete."
