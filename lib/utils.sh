#!/usr/bin/env bash

# Colors for output
export COLOR_RESET="\033[0m"
export COLOR_INFO="\033[36m"
export COLOR_SUCCESS="\033[32m"
export COLOR_WARN="\033[33m"
export COLOR_ERROR="\033[31m"

# Utility functions
info() { echo -e "${COLOR_INFO}ℹ $1${COLOR_RESET}"; }
success() { echo -e "${COLOR_SUCCESS}✓ $1${COLOR_RESET}"; }
warn() { echo -e "${COLOR_WARN}⚠ $1${COLOR_RESET}"; }
error() {
    echo -e "${COLOR_ERROR}✖ $1${COLOR_RESET}"
    exit 1
}

# Error without exiting (for summary table)
error_no_exit() { echo -e "${COLOR_ERROR}✖ $1${COLOR_RESET}"; }

strict_checksum_enabled() {
    [[ "${DOTFILES_STRICT_CHECKSUM:-false}" == "true" ]]
}

# Get System Architecture
get_arch() {
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64) echo "x86_64" ;;
        aarch64 | arm64) echo "aarch64" ;;
        *) error "Unsupported architecture: $arch" ;;
    esac
}

# Idempotent apt install with retry for dpkg locks
apt_install() {
    info "Installing packages: $*"
    local retries=5
    local wait_time=5
    local count=0

    while [ $count -lt $retries ]; do
        if sudo apt-get install -y "$@"; then
            return 0
        fi
        count=$((count + 1))
        warn "apt-get failed (possibly locked). Retrying in $wait_time seconds... ($count/$retries)"
        sleep $wait_time
    done
    error "Failed to install packages: $*. Please check your network connection and package repository state."
}

# Download with retries
download_to_file() {
    local url="$1"
    local output_file="$2"
    if ! curl --fail --silent --show-error --location \
        --retry 3 --retry-delay 2 --retry-connrefused \
        "$url" -o "$output_file"; then
        return 1
    fi
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
        error "Failed to download installer from $url. Please check your internet connection."
    fi

    if "$runner" "$tmp_script" "$@"; then
        rm -f "$tmp_script"
    else
        local exit_code=$?
        rm -f "$tmp_script"
        warn "Remote script from $url failed with exit code $exit_code."
        return "$exit_code"
    fi
}

# Verify downloaded GitHub release asset against release checksums if available.
# Set DOTFILES_STRICT_CHECKSUM=true to fail when checksums are missing/unusable.
verify_github_asset_checksum() {
    local release_json="$1"
    local asset_name="$2"
    local asset_file="$3"

    # Wrap in a function-level check to allow easy skipping
    if [[ "${DOTFILES_SKIP_CHECKSUM:-false}" == "true" ]]; then
        warn "Checksum verification skipped by user."
        return 0
    fi

    # Strip common extensions for better matching (e.g., myapp.tar.gz -> myapp)
    local asset_base
    asset_base=$(echo "$asset_name" | sed -E 's/\.(tar\.gz|zip|tgz|appimage|tar\.xz)$//i')

    # Identify checksum file.
    # Prioritize a checksum file that matches the asset base name.
    local checksum_url
    checksum_url=$(jq -r --arg asset_base "$asset_base" '
        .assets[]
        | .name as $n
        | ($n | ascii_downcase) as $ln
        | select($ln | test("(sha256|checksums?|sums)"))
        | {
            url: .browser_download_url,
            score: (
                if ($ln | contains($asset_base | ascii_downcase)) then 10
                elif ($ln | contains("sha256")) then 5
                else 1
                end
            )
        }
    ' <<<"$release_json" | jq -s 'sort_by(.score) | reverse | .[0].url' | tr -d '"')

    if [[ -z "$checksum_url" || "$checksum_url" == "null" ]]; then
        if strict_checksum_enabled; then
            error "CRITICAL: No checksum asset found for $asset_name in strict checksum mode."
        fi
        warn "Verification skipped: No checksum asset found for $asset_name."
        return 0
    fi

    info "Verifying $asset_name with $(basename "$checksum_url")..."

    # We use a subshell ( ( ... ) ) to ensure that any 'set -e' trigger inside
    # the verification logic doesnt kill the main script.
    (
        set -e
        local checksums_file
        checksums_file=$(mktemp)

        if ! curl --fail --silent --location "$checksum_url" -o "$checksums_file"; then
            rm -f "$checksums_file"
            exit 2 # Special exit code for download failure
        fi

        local expected_sha=""
        local normalized_asset_name="${asset_name#./}"
        local exact_match=false

        # 1. Look for the exact filename
        expected_sha=$(grep -i "$normalized_asset_name" "$checksums_file" | awk '{print $1}' | tr '[:upper:]' '[:lower:]' | head -n 1 || echo "")
        [[ -n "$expected_sha" ]] && exact_match=true

        # 2. Aggressive search for small files
        if [[ -z "$expected_sha" ]]; then
            if [[ $(wc -l <"$checksums_file") -le 3 ]]; then
                expected_sha=$(grep -oE "[[:xdigit:]]{64}" "$checksums_file" | head -n 1 | tr '[:upper:]' '[:lower:]' || echo "")
            fi
        fi

        # 3. Liberal match (look for the filename in any column)
        if [[ -z "$expected_sha" ]]; then
            expected_sha=$(awk -v f="$normalized_asset_name" '$0 ~ f {print $1}' "$checksums_file" | head -n 1 | tr '[:upper:]' '[:lower:]' || echo "")
        fi

        rm -f "$checksums_file"

        if [[ -z "$expected_sha" || ! "$expected_sha" =~ ^[[:xdigit:]]{64}$ ]]; then
            exit 3 # Special exit code for "checksum not found"
        fi

        local actual_sha
        actual_sha=$(sha256sum "$asset_file" | awk '{print tolower($1)}')
        if [[ "$actual_sha" != "$expected_sha" ]]; then
            # If we had an exact match and it failed, it's a security alert
            if [[ "$exact_match" == "true" ]]; then
                echo -e "EXPECTED:$expected_sha\nACTUAL:$actual_sha" >&2
                exit 4 # Confirmed mismatch
            else
                # If it was an aggressive/liberal match, it might be for a file INSIDE the archive
                exit 5 # Ambiguous mismatch
            fi
        fi
    ) 2> >(
        read -r err_data
        echo "$err_data" >&2
    ) && local verify_status=0 || local verify_status=$?

    case $verify_status in
        0) info "Checksum verified for $asset_name." ;;
        2) warn "Verification skipped: Could not download checksum file." ;;
        3)
            if strict_checksum_enabled; then error "CRITICAL: Checksum not found (strict mode)."; fi
            warn "Verification skipped: No valid SHA256 found in checksum file."
            ;;
        4)
            # This is a real security issue, we SHOULD fail here
            error_no_exit "SECURITY ALERT: Checksum mismatch for $asset_name!"
            return 1
            ;;
        5)
            warn "Verification skipped: Found hash in $(basename "$checksum_url") but it doesn't match $asset_name. It may be intended for the binary inside the archive."
            ;;
        *) warn "Verification skipped: Internal verification error (code $verify_status)." ;;
    esac

    return 0
}

# Intelligent shell configuration
# Usage: add_to_common "export EDITOR='nvim'"
add_to_common() {
    local line="$1"
    local common_rc="$HOME/.shell_common"
    touch "$common_rc"
    if ! grep -Fq "$line" "$common_rc"; then
        echo "$line" >>"$common_rc"
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
        ' "$file" >"$tmp_file"
    else
        # Append new block
        cat "$file" >"$tmp_file"
        echo -e "\n$content" >>"$tmp_file"
    fi

    cat "$tmp_file" >"$file"
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
        eval "$gen_cmd" >"$comp_dir/_$name"
    fi
}

# Download and install one or more binaries from a GitHub release asset
# Usage: install_from_github "ast-grep/ast-grep" "sg" ".zip" "ast-grep"
install_from_github() {
    local repo=$1
    local bin_name=$2
    local extension=$3
    shift 3
    local bins=("$bin_name" "$@")
    local arch
    arch=$(get_arch)
    local os="linux"
    local extension_lower="${extension,,}"

    info "Installing $bin_name from $repo..."

    # Smarter asset selection:
    # 1. Matches architecture (handles x86_64/amd64/linux64 and aarch64/arm64)
    # 2. Matches OS (linux) - relaxed for AppImages which are inherently Linux
    # 3. Matches extension
    # 4. Scoring system to prioritize "standard" builds
    local release_json
    release_json=$(curl --fail --silent --show-error --location \
        --retry 3 --retry-delay 2 --retry-connrefused \
        "https://api.github.com/repos/$repo/releases/latest")

    local asset_tsv
    asset_tsv=$(jq -r --arg arch "$arch" --arg ext "$extension_lower" --arg os "$os" '
        [
            .assets[]
            | .name as $raw_name
            | ($raw_name | ascii_downcase) as $name
            | select(
                ($name | endswith($ext)) and
                (($ext == ".appimage") or ($name | contains($os))) and
                (
                    ($name | contains($arch)) or
                    ($arch == "aarch64" and ($name | contains("arm64"))) or
                    ($arch == "x86_64" and (($name | contains("amd64")) or ($name | contains("linux64"))))
                )
            )
            | {
                name: $raw_name,
                url: .browser_download_url,
                score: (
                    100 
                    - (if ($name | contains("no-web")) then 50 else 0 end)
                    - (if ($name | contains("musl")) then 20 else 0 end)
                    - (if ($name | contains("static")) then 10 else 0 end)
                    - ($name | length)
                )
            }
        ] | sort_by(.score) | reverse | .[0] | [.name, .url] | @tsv
    ' <<<"$release_json")

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

    if ! verify_github_asset_checksum "$release_json" "$asset_name" "$downloaded_asset"; then
        rm -f "$downloaded_asset"
        return 1
    fi

    if [[ "$extension" == ".appimage" ]]; then
        if [[ ${#bins[@]} -ne 1 ]]; then
            rm -f "$downloaded_asset"
            error "AppImage install supports only one binary name."
        fi
        sudo install -m 0755 "$downloaded_asset" "/usr/local/bin/$bin_name"
        rm -f "$downloaded_asset"
        return
    fi

    local extract_dir
    extract_dir=$(mktemp -d)
    if [[ "$extension" == "tar.gz" ]]; then
        if ! tar -xzf "$downloaded_asset" -C "$extract_dir" "$bin_name" 2>/dev/null; then
            tar -xzf "$downloaded_asset" -C "$extract_dir"
        fi
    elif [[ "$extension" == ".zip" ]]; then
        unzip -q "$downloaded_asset" -d "$extract_dir"
    else
        rm -rf "$extract_dir"
        rm -f "$downloaded_asset"
        error "Unsupported extension for install_from_github: $extension"
    fi

    local requested_bin
    local extracted_bin
    for requested_bin in "${bins[@]}"; do
        extracted_bin=$(find "$extract_dir" -type f -name "$requested_bin" | head -n 1)
        if [[ -z "$extracted_bin" ]]; then
            rm -rf "$extract_dir"
            rm -f "$downloaded_asset"
            error "Could not locate $requested_bin in downloaded archive from $repo"
        fi
        sudo install "$extracted_bin" /usr/local/bin/
    done

    rm -rf "$extract_dir"
    rm -f "$downloaded_asset"
    info "Successfully installed $bin_name."
}
