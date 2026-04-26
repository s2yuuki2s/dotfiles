#!/usr/bin/env bash

# Colors for output
export COLOR_RESET="\033[0m"
export COLOR_INFO="\033[32m"
export COLOR_WARN="\033[33m"
export COLOR_ERROR="\033[31m"

# Utility functions
info() { echo -e "${COLOR_INFO}[INFO]${COLOR_RESET} $1"; }
warn() { echo -e "${COLOR_WARN}[WARN]${COLOR_RESET} $1"; }
error() { echo -e "${COLOR_ERROR}[ERROR]${COLOR_RESET} $1"; exit 1; }

# Get System Architecture
get_arch() {
    local arch=$(uname -m)
    case "$arch" in
        x86_64) echo "x86_64" ;;
        aarch64|arm64) echo "arm64" ;;
        *) error "Unsupported architecture: $arch" ;;
    esac
}

# Idempotent apt install
apt_install() {
    info "Installing packages: $*"
    sudo apt-get install -y "$@"
}

# Intelligent shell configuration
# Usage: add_to_common "export EDITOR='nvim'"
add_to_common() {
    local line="$1"
    local common_rc="$HOME/.shell_common"
    touch "$common_rc"
    if ! grep -Fq "$line" "$common_rc"; then
        echo "$line" >> "$common_rc"
    fi
}

# Download and install binary from GitHub
# Usage: install_from_github "jesseduffield/lazygit" "lazygit" "tar.gz"
install_from_github() {
    local repo=$1
    local bin_name=$2
    local extension=$3
    local arch=$(get_arch)
    
    info "Installing $bin_name from $repo..."
    
    local url=$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" | \
        jq -r --arg arch "$arch" --arg ext "$extension" \
        '.assets[] | select(.name | contains($arch) and endswith($ext)) | .browser_download_url' | head -n 1)

    if [[ -z "$url" || "$url" == "null" ]]; then
        error "Could not find download URL for $bin_name ($arch)"
    fi

    if [[ "$extension" == "tar.gz" ]]; then
        curl -fsSL "$url" | tar xz "$bin_name"
        sudo install "$bin_name" /usr/local/bin/
        rm "$bin_name"
    elif [[ "$extension" == ".appimage" ]]; then
        curl -fsSL "$url" -o "$bin_name"
        chmod +x "$bin_name"
        sudo mv "$bin_name" /usr/local/bin/
    fi
}
