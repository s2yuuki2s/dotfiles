#!/usr/bin/env bash
set -euo pipefail

[[ -z "${DOTFILES_DIR:-}" ]] && DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=lib/utils.sh
source "$DOTFILES_DIR/lib/utils.sh"

info "Installing Rust & Cargo"

if ! command -v cargo >/dev/null 2>&1; then
    run_remote_script "https://sh.rustup.rs" sh -y --no-modify-path
fi

# Add to common shell config
# shellcheck disable=SC2016
add_to_common 'source "$HOME/.cargo/env"'

success "Rust setup complete."
