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

strict_checksum_enabled() {
    [[ "${DOTFILES_STRICT_CHECKSUM:-false}" == "true" ]]
}

# Get System Architecture
get_arch() {
    local arch
    arch=$(uname -m)
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

# Download with retries
download_to_file() {
    local url="$1"
    local output_file="$2"
    curl --fail --silent --show-error --location \
        --retry 3 --retry-delay 2 --retry-connrefused \
        "$url" -o "$output_file"
}

# Download remote installer script and execute it from a temporary file
# Usage: run_remote_script "https://example.com/install.sh" bash --arg
run_remote_script() {
    local url="$1"
    local runner="$2"
    shift 2

    local tmp_script
    tmp_script=$(mktemp)
    if ! download_to_file "$url" "$tmp_script"; then
        rm -f "$tmp_script"
        error "Failed to download installer from $url"
    fi

    if "$runner" "$tmp_script" "$@"; then
        rm -f "$tmp_script"
    else
        local exit_code=$?
        rm -f "$tmp_script"
        return "$exit_code"
    fi
}

# Verify downloaded GitHub release asset against release checksums if available.
# Set DOTFILES_STRICT_CHECKSUM=true to fail when checksums are missing/unusable.
verify_github_asset_checksum() {
    local release_json="$1"
    local asset_name="$2"
    local asset_file="$3"

    local checksum_url
    checksum_url=$(jq -r '
        .assets[]
        | select(.name | ascii_downcase | test("(sha256|checksums?)"))
        | .browser_download_url
    ' <<< "$release_json" | head -n 1)

    if [[ -z "$checksum_url" || "$checksum_url" == "null" ]]; then
        if strict_checksum_enabled; then
            error "No checksum asset found for $asset_name (strict checksum mode)."
        fi
        warn "No checksum asset found for $asset_name. Continuing without checksum verification."
        return 0
    fi

    local checksums_file
    checksums_file=$(mktemp)
    if ! download_to_file "$checksum_url" "$checksums_file"; then
        rm -f "$checksums_file"
        if strict_checksum_enabled; then
            error "Could not download checksum file for $asset_name (strict checksum mode)."
        fi
        warn "Could not download checksum file for $asset_name. Continuing without checksum verification."
        return 0
    fi

    local expected_sha=""
    local normalized_asset_name="${asset_name#./}"
    while IFS= read -r line; do
        if [[ "$line" =~ ^([[:xdigit:]]{64})[[:space:]]+\*?(.+)$ ]]; then
            local listed_name="${BASH_REMATCH[2]#./}"
            if [[ "$listed_name" == "$normalized_asset_name" ]]; then
                expected_sha="${BASH_REMATCH[1],,}"
                break
            fi
        elif [[ "$line" =~ ^SHA256\ \((.+)\)\ =\ ([[:xdigit:]]{64})$ ]]; then
            local listed_name="${BASH_REMATCH[1]#./}"
            if [[ "$listed_name" == "$normalized_asset_name" ]]; then
                expected_sha="${BASH_REMATCH[2],,}"
                break
            fi
        fi
    done < "$checksums_file"
    rm -f "$checksums_file"

    if [[ -z "$expected_sha" ]]; then
        if strict_checksum_enabled; then
            error "Checksum list found, but no entry matched $asset_name (strict checksum mode)."
        fi
        warn "Checksum list found, but no entry matched $asset_name. Continuing without checksum verification."
        return 0
    fi

    local actual_sha
    actual_sha=$(sha256sum "$asset_file" | awk '{print tolower($1)}')
    if [[ "$actual_sha" != "$expected_sha" ]]; then
        error "Checksum mismatch for $asset_name"
    fi

    info "Checksum verified for $asset_name"
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
    local tmp_file
    tmp_file=$(mktemp)
    
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
    local arch
    arch=$(get_arch)
    local os="linux"
    local extension_lower="${extension,,}"
    
    info "Installing $bin_name from $repo..."
    
    # Smarter asset selection:
    # 1. Matches architecture (handles x86_64/amd64/linux64 and aarch64/arm64)
    # 2. Matches OS (linux) - relaxed for AppImages which are inherently Linux
    # 3. Matches extension
    local release_json
    release_json=$(curl --fail --silent --show-error --location \
        --retry 3 --retry-delay 2 --retry-connrefused \
        "https://api.github.com/repos/$repo/releases/latest")

    local asset_tsv
    asset_tsv=$(jq -r --arg arch "$arch" --arg ext "$extension_lower" --arg os "$os" '
        .assets[]
        | .name as $raw_name
        | ($raw_name | ascii_downcase) as $name
        select(
            ($name | endswith($ext)) and
            (
                # Either it contains "linux" or it is an .appimage (which is Linux-only)
                ($ext == ".appimage") or ($name | contains($os))
            ) and
            (
                ($name | contains($arch)) or
                ($arch == "aarch64" and ($name | contains("arm64"))) or
                ($arch == "x86_64" and (($name | contains("amd64")) or ($name | contains("linux64"))))
            )
        )
        | [$raw_name, .browser_download_url]
        | @tsv
    ' <<< "$release_json" | head -n 1)

    if [[ -z "$asset_tsv" || "$asset_tsv" == "null" ]]; then
        error "Could not find download URL for $bin_name ($arch)"
    fi

    local asset_name="${asset_tsv%%$'\t'*}"
    local url="${asset_tsv#*$'\t'}"
    local downloaded_asset
    downloaded_asset=$(mktemp)
    if ! download_to_file "$url" "$downloaded_asset"; then
        rm -f "$downloaded_asset"
        error "Failed to download release asset for $bin_name from $repo"
    fi
    verify_github_asset_checksum "$release_json" "$asset_name" "$downloaded_asset"

    if [[ "$extension" == "tar.gz" ]]; then
        local extract_dir
        extract_dir=$(mktemp -d)
        if ! tar -xzf "$downloaded_asset" -C "$extract_dir" "$bin_name" 2>/dev/null; then
            tar -xzf "$downloaded_asset" -C "$extract_dir"
        fi

        local extracted_bin
        extracted_bin=$(find "$extract_dir" -type f -name "$bin_name" | head -n 1)
        if [[ -z "$extracted_bin" ]]; then
            rm -rf "$extract_dir"
            rm -f "$downloaded_asset"
            error "Could not locate $bin_name in downloaded archive from $repo"
        fi

        sudo install "$extracted_bin" /usr/local/bin/
        rm -rf "$extract_dir"
    elif [[ "$extension" == ".appimage" ]]; then
        sudo install -m 0755 "$downloaded_asset" "/usr/local/bin/$bin_name"
    fi

    rm -f "$downloaded_asset"
}
