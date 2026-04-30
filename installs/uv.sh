#!/usr/bin/env bash
set -euo pipefail

[[ -z "${DOTFILES_DIR:-}" ]] && DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=lib/utils.sh
source "$DOTFILES_DIR/lib/utils.sh"

info "Installing UV (Python Package Manager)"

if ! command -v uv >/dev/null 2>&1; then
    INSTALLER_NO_MODIFY_PATH=1 run_remote_script "https://astral.sh/uv/install.sh" sh
fi

# Static completions for Zsh
export PATH="$HOME/.local/bin:$PATH"
install_zsh_completion "uv" "uv generate-shell-completion zsh"
install_zsh_completion "uvx" "uvx --generate-shell-completion zsh"

success "UV setup complete."
