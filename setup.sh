#!/usr/bin/env bash
set -euo pipefail

# Load utilities
DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$DOTFILES_DIR/lib/utils.sh"

info "Starting Dotfiles setup..."

CLEANUP=false
ONLY_MODULES=""
SKIP_MODULES=""
STRICT_CHECKSUM=false
LOCK_DIR="/tmp/dotfiles-setup.lock"
LOCK_ACQUIRED=false
AUTO_SWITCH_SHELL=true

scripts=(
    "zsh.sh"
    "terminal.sh"
    "fnm.sh"
    "uv.sh"
    "rust.sh"
    "sdkman.sh"
    "neovim.sh"
    "zellij.sh"
    "docker.sh"
    "lazydocker.sh"
)

csv_has() {
    local csv="$1"
    local item="$2"
    [[ -n "$csv" && ",$csv," == *",$item,"* ]]
}

validate_modules() {
    local csv="$1"
    local label="$2"

    [[ -z "$csv" ]] && return 0

    IFS=',' read -r -a requested <<< "$csv"
    for module in "${requested[@]}"; do
        if ! [[ "$module" =~ ^[a-zA-Z0-9._-]+$ ]]; then
            error "Invalid module name in $label: $module"
        fi
        module="${module%.sh}"
        if ! csv_has "$AVAILABLE_MODULES" "$module"; then
            error "Unknown module in $label: $module"
        fi
    done
}

normalize_modules_csv() {
    local csv="$1"
    local normalized=""

    [[ -z "$csv" ]] && { echo ""; return 0; }

    IFS=',' read -r -a requested <<< "$csv"
    for module in "${requested[@]}"; do
        module="${module%.sh}"
        if [[ -z "$normalized" ]]; then
            normalized="$module"
        else
            normalized="$normalized,$module"
        fi
    done

    echo "$normalized"
}

for arg in "$@"; do
    case "$arg" in
        --cleanup)
            CLEANUP=true
            ;;
        --strict-checksum)
            STRICT_CHECKSUM=true
            ;;
        --only=*)
            ONLY_MODULES="${arg#*=}"
            ;;
        --skip=*)
            SKIP_MODULES="${arg#*=}"
            ;;
        --no-auto-shell-switch)
            AUTO_SWITCH_SHELL=false
            ;;
        *)
            error "Unknown option: $arg"
            ;;
    esac
done

if [[ "$CLEANUP" == true ]]; then
    info "Cleanup mode enabled: Directory will be removed after installation."
fi

if [[ "$STRICT_CHECKSUM" == true ]]; then
    export DOTFILES_STRICT_CHECKSUM=true
    info "Strict checksum mode enabled."
fi

AVAILABLE_MODULES=""
for script in "${scripts[@]}"; do
    module="${script%.sh}"
    if [[ -z "$AVAILABLE_MODULES" ]]; then
        AVAILABLE_MODULES="$module"
    else
        AVAILABLE_MODULES="$AVAILABLE_MODULES,$module"
    fi
done

validate_modules "$ONLY_MODULES" "--only"
validate_modules "$SKIP_MODULES" "--skip"
ONLY_MODULES=$(normalize_modules_csv "$ONLY_MODULES")
SKIP_MODULES=$(normalize_modules_csv "$SKIP_MODULES")

if mkdir "$LOCK_DIR" 2>/dev/null; then
    LOCK_ACQUIRED=true
else
    error "Another setup process is running (lock: $LOCK_DIR)."
fi

# Keep-alive sudo
sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
SUDO_PID=$!

cleanup() {
    local exit_code=$?

    if [[ $SUDO_PID -ne 0 ]]; then
        kill "$SUDO_PID" 2>/dev/null || true
    fi
    if [[ "$LOCK_ACQUIRED" == true ]]; then
        rm -rf "$LOCK_DIR"
    fi
    if [[ $exit_code -ne 0 ]]; then
        echo -e "${COLOR_ERROR}[ERROR]${COLOR_RESET} Setup failed with exit code $exit_code" >&2
    fi
    trap - EXIT
    exit "$exit_code"
}
trap cleanup EXIT

# Initial system update
info "Updating system repositories..."
sudo apt-get update

# Core dependencies
apt_install curl wget jq git build-essential zip unzip

for script in "${scripts[@]}"; do
    module="${script%.sh}"
    if [[ -n "$ONLY_MODULES" ]] && ! csv_has "$ONLY_MODULES" "$module"; then
        continue
    fi
    if csv_has "$SKIP_MODULES" "$module"; then
        info "Skipping $script (filtered by --skip)."
        continue
    fi

    script_path="$DOTFILES_DIR/installs/$script"
    if [[ -f "$script_path" ]]; then
        info "Executing $script..."
        bash "$script_path"
    else
        warn "Script $script not found, skipping."
    fi
done

info "🎉 All installations completed!"

if [[ "$CLEANUP" == true ]]; then
    if [[ "$(basename "$DOTFILES_DIR")" == ".dotfiles-temp" ]]; then
        info "Cleaning up: Removing $DOTFILES_DIR..."
        cd "$HOME"
        rm -rf "$DOTFILES_DIR"
    else
        warn "Cleanup skipped for safety: refusing to remove non-temporary directory $DOTFILES_DIR"
    fi
fi

if [[ "$AUTO_SWITCH_SHELL" == true ]] && command -v zsh >/dev/null 2>&1; then
    current_shell_name=$(ps -p $$ -o comm= 2>/dev/null | tr -d ' ')
    if [[ "${current_shell_name:-}" != "zsh" ]] && [[ -t 0 ]] && [[ -t 1 ]]; then
        info "Switching current session to zsh..."
        export SHELL
        SHELL="$(command -v zsh)"
        exec zsh -l
    fi
fi
