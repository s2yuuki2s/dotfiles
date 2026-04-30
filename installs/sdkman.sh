#!/usr/bin/env bash
set -euo pipefail

[[ -z "${DOTFILES_DIR:-}" ]] && DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=lib/utils.sh
source "$DOTFILES_DIR/lib/utils.sh"

info "== Installing SDKMAN! =="

# SDKMAN requires zip and unzip, which are installed in setup.sh core dependencies
if [[ ! -d "$HOME/.sdkman" ]]; then
    # Disable rc update since we handle it via add_to_common
    run_remote_script "https://get.sdkman.io?rcupdate=false" bash
else
    info "SDKMAN! is already installed."
fi

# Add to common shell config
# shellcheck disable=SC2016
add_to_common 'export SDKMAN_DIR="$HOME/.sdkman"'
# shellcheck disable=SC2016
add_to_common '[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"'

info "✅ SDKMAN! setup complete."
