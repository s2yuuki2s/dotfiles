#!/usr/bin/env bash
set -euo pipefail

[[ -z "${DOTFILES_DIR:-}" ]] && DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=lib/utils.sh
source "$DOTFILES_DIR/lib/utils.sh"

info "Installing Starship Prompt"

if ! command -v starship >/dev/null 2>&1; then
    run_remote_script "https://starship.rs/install.sh" sh --yes
fi

# Apply default preset if config doesn't exist
mkdir -p "$HOME/.config"
if [[ ! -f "$HOME/.config/starship.toml" ]]; then
    starship preset gruvbox-rainbow -o "$HOME/.config/starship.toml"
fi

success "Starship setup complete."
