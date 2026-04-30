#!/usr/bin/env bash
set -euo pipefail

[[ -z "${DOTFILES_DIR:-}" ]] && DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=lib/utils.sh
source "$DOTFILES_DIR/lib/utils.sh"

info "== Installing Docker Engine =="

if ! command -v docker >/dev/null 2>&1; then
    apt_install ca-certificates curl gnupg

    # Get OS ID (ubuntu, debian, etc.)
    OS_ID=$(grep -E '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')

    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL "https://download.docker.com/linux/$OS_ID/gpg" | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes

    if command -v lsb_release >/dev/null 2>&1; then
        CODENAME=$(lsb_release -cs)
    else
        CODENAME=$(grep -E '^VERSION_CODENAME=' /etc/os-release | cut -d= -f2 | tr -d '"')
    fi

    if [[ -z "${CODENAME:-}" ]]; then
        error "Could not determine distro codename for Docker repository."
    fi

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS_ID $CODENAME stable" |
        sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

    sudo apt-get update
    apt_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # User group setup
    if ! groups "$USER" | grep -q "\bdocker\b"; then
        sudo usermod -aG docker "$USER"
        warn "You may need to log out and back in for docker group changes to take effect."
    else
        info "User $USER is already in the docker group."
    fi
fi

info "✅ Docker setup complete."
