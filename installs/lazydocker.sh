#!/usr/bin/env bash
set -euo pipefail

[[ -z "${DOTFILES_DIR:-}" ]] && DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=lib/utils.sh
source "$DOTFILES_DIR/lib/utils.sh"

info "== Installing Lazydocker =="

install_from_github "jesseduffield/lazydocker" "lazydocker" "tar.gz"

info "✅ Lazydocker setup complete."
