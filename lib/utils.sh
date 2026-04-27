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
        aarch64|arm64) echo "aarch64" ;;
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

# Add or update a block of text in a file
# Usage: add_block_to_file "file" "start_marker" "end_marker" "content"
add_block_to_file() {
    local file="$1"
    local start_marker="$2"
    local end_marker="$3"
    local content="$4"
    
    touch "$file"
    
    # Create a temporary file
    local tmp_file=$(mktemp)
    
    if grep -q "$start_marker" "$file"; then
        # Replace existing block
        awk -v start="$start_marker" -v end="$end_marker" -v block="$content" '
            $0 ~ start { print block; skip=1; next }
            $0 ~ end { skip=0; next }
            !skip { print }
        ' "$file" > "$tmp_file"
    else
        # Append new block
        cat "$file" > "$tmp_file"
        echo -e "\n$content" >> "$tmp_file"
    fi
    
    cat "$tmp_file" > "$file"
    rm "$tmp_file"
}

# Install Zsh completion
# Usage: install_zsh_completion "name" "command_to_generate"
install_zsh_completion() {
    local name="$1"
    local gen_cmd="$2"
    
    if [[ -d "$HOME/.oh-my-zsh" ]]; then
        local zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
        local comp_dir="$zsh_custom/completions"
        mkdir -p "$comp_dir"
        eval "$gen_cmd" > "$comp_dir/_$name"
    fi
}

# Download and install binary from GitHub
# Usage: install_from_github "jesseduffield/lazygit" "lazygit" "tar.gz"
install_from_github() {
    local repo=$1
    local bin_name=$2
    local extension=$3
    local arch=$(get_arch)
    local os="linux"
    
    info "Installing $bin_name from $repo..."
    
    # Smarter asset selection:
    # 1. Matches architecture (handles x86_64/amd64/linux64 and aarch64/arm64)
    # 2. Matches OS (linux) - relaxed for AppImages which are inherently Linux
    # 3. Matches extension
    local url=$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" | \
        jq -r --arg arch "$arch" --arg ext "$extension" --arg os "$os" '
        .assets[] | 
        select(
            (.name | ascii_downcase | endswith($ext)) and 
            (
                # Either it contains "linux" or it is an .appimage (which is Linux-only)
                ($ext == ".appimage") or (.name | ascii_downcase | contains($os))
            ) and
            (
                (.name | contains($arch)) or 
                ($arch == "aarch64" and (.name | contains("arm64"))) or
                ($arch == "x86_64" and ((.name | contains("amd64")) or (.name | contains("linux64"))))
            )
        ) | .browser_download_url' | head -n 1)

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
