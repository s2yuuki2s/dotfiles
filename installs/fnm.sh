#!/usr/bin/env bash
set -euo pipefail

[[ -z "${DOTFILES_DIR:-}" ]] && DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=lib/utils.sh
source "$DOTFILES_DIR/lib/utils.sh"

info "Installing FNM (Fast Node Manager)"

if ! command -v fnm >/dev/null 2>&1; then
    arch=$(get_arch)
    if [[ "$arch" == "x86_64" ]]; then
        asset_name="fnm-linux.zip"
    else
        asset_name="fnm-arm64.zip"
    fi

    info "Downloading fnm from GitHub..."
    release_json=$(curl --fail --silent --show-error --location "https://api.github.com/repos/Schniz/fnm/releases/latest")
    url=$(echo "$release_json" | jq -r --arg name "$asset_name" '.assets[] | select(.name == $name) | .browser_download_url')

    if [[ -z "$url" || "$url" == "null" ]]; then
        error "Could not find download URL for $asset_name"
    fi

    tmp_zip=$(mktemp)
    download_to_file "$url" "$tmp_zip"
    if ! verify_github_asset_checksum "$release_json" "$asset_name" "$tmp_zip"; then
        rm -f "$tmp_zip"
        error "Checksum verification failed for FNM. Installation aborted."
    fi

    mkdir -p "$HOME/.local/bin"
    unzip -oj "$tmp_zip" "fnm" -d "$HOME/.local/bin"
    chmod +x "$HOME/.local/bin/fnm"
    rm -f "$tmp_zip"
fi

# Ensure fnm is in PATH for the rest of the script
export PATH="$HOME/.local/bin:$PATH"

# Generate static completion for Oh My Zsh users.
if [[ -d "$HOME/.oh-my-zsh" ]]; then
    install_zsh_completion "fnm" "fnm completions --shell zsh"
else
    warn "Oh My Zsh not found, skipping fnm zsh completion."
fi

# Install Node.js if not already installed
if ! fnm current >/dev/null 2>&1; then
    info "No Node.js version detected. Installing LTS..."
    fnm install --lts
    # 'lts' is a remote alias, after install fnm creates a local 'lts-latest' alias
    fnm default lts-latest
fi

success "FNM setup complete."
