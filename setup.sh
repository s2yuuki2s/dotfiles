#!/usr/bin/env bash
set -euo pipefail

[[ -z "${DOTFILES_DIR:-}" ]] && DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/utils.sh
source "$DOTFILES_DIR/lib/utils.sh"

info "Starting Dotfiles Setup"

CLEANUP=false
ONLY_MODULES=""
SKIP_MODULES=""
STRICT_CHECKSUM=false
LOCK_DIR="/tmp/dotfiles-setup.lock"
LOCK_ACQUIRED=false
AUTO_SWITCH_SHELL=true

# Helper functions
csv_has() {
    local csv="$1"
    local item="$2"
    [[ -n "$csv" && ",$csv," == *",$item,"* ]]
}

validate_modules() {
    local csv="$1"
    local label="$2"
    local available="$3"

    [[ -z "$csv" ]] && return 0

    IFS=',' read -r -a requested <<<"$csv"
    for module in "${requested[@]}"; do
        if ! [[ "$module" =~ ^[a-zA-Z0-9._-]+$ ]]; then
            error "Invalid module name in $label: $module"
        fi
        module="${module%.sh}"
        if ! csv_has "$available" "$module"; then
            error "Unknown module in $label: $module (Available: $available)"
        fi
    done
}

normalize_modules_csv() {
    local csv="$1"
    local normalized=""

    [[ -z "$csv" ]] && {
        echo ""
        return 0
    }

    IFS=',' read -r -a requested <<<"$csv"
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

# Auto-discover installation scripts
PREFERRED_ORDER=("zsh.sh" "terminal.sh" "starship.sh")
scripts=()

# First, add preferred scripts if they exist
for pref in "${PREFERRED_ORDER[@]}"; do
    if [[ -f "$DOTFILES_DIR/installs/$pref" ]]; then
        scripts+=("$pref")
    fi
done

# Then, add the rest alphabetically
while IFS= read -r script; do
    is_pref=false
    for pref in "${PREFERRED_ORDER[@]}"; do
        [[ "$script" == "$pref" ]] && is_pref=true && break
    done
    [[ "$is_pref" == false ]] && scripts+=("$script")
done < <(find "$DOTFILES_DIR/installs" -maxdepth 1 -type f -name "*.sh" -printf "%f\n" | sort)

AVAILABLE_MODULES=""
for script in "${scripts[@]}"; do
    module="${script%.sh}"
    if [[ -z "$AVAILABLE_MODULES" ]]; then
        AVAILABLE_MODULES="$module"
    else
        AVAILABLE_MODULES="$AVAILABLE_MODULES,$module"
    fi
done

# Argument parsing
for arg in "$@"; do
    case "$arg" in
        --cleanup) CLEANUP=true ;;
        --strict-checksum) STRICT_CHECKSUM=true ;;
        --only=*) ONLY_MODULES="${arg#*=}" ;;
        --skip=*) SKIP_MODULES="${arg#*=}" ;;
        --no-auto-shell-switch) AUTO_SWITCH_SHELL=false ;;
        *) error "Unknown option: $arg" ;;
    esac
done

if [[ "$CLEANUP" == true ]]; then
    info "Cleanup mode enabled: Directory will be removed after installation."
fi

if [[ "$STRICT_CHECKSUM" == true ]]; then
    export DOTFILES_STRICT_CHECKSUM=true
    info "Strict checksum mode enabled."
fi

validate_modules "$ONLY_MODULES" "--only" "$AVAILABLE_MODULES"
validate_modules "$SKIP_MODULES" "--skip" "$AVAILABLE_MODULES"
ONLY_MODULES=$(normalize_modules_csv "$ONLY_MODULES")
SKIP_MODULES=$(normalize_modules_csv "$SKIP_MODULES")

if mkdir "$LOCK_DIR" 2>/dev/null; then
    LOCK_ACQUIRED=true
else
    error "Another setup process is running (lock: $LOCK_DIR)."
fi

# Keep-alive sudo
sudo -v
while true; do
    sudo -n true
    sleep 60
    kill -0 "$$" || exit
done 2>/dev/null &
SUDO_PID=$!

cleanup() {
    local exit_code=$?
    [[ $SUDO_PID -ne 0 ]] && kill "$SUDO_PID" 2>/dev/null || true
    [[ "$LOCK_ACQUIRED" == true ]] && rm -rf "$LOCK_DIR"
    if [[ $exit_code -ne 0 ]]; then
        echo -e "${COLOR_ERROR}✖ Setup failed with exit code $exit_code${COLOR_RESET}" >&2
    fi
    trap - EXIT
    exit "$exit_code"
}
trap cleanup EXIT

# Initial system update
info "Updating System Repositories"
sudo apt-get update

# Core dependencies
apt_install curl wget jq git build-essential zip unzip

# Module tracking
success_modules=()
failed_modules=()
skipped_modules=()

for script in "${scripts[@]}"; do
    module="${script%.sh}"
    if [[ -n "$ONLY_MODULES" ]] && ! csv_has "$ONLY_MODULES" "$module"; then
        continue
    fi
    if csv_has "$SKIP_MODULES" "$module"; then
        skipped_modules+=("$module")
        continue
    fi

    script_path="$DOTFILES_DIR/installs/$script"
    if [[ -f "$script_path" ]]; then
        info "Executing $module..."
        if bash "$script_path"; then
            success_modules+=("$module")
        else
            failed_modules+=("$module")
            warn "Module $module failed."
        fi
    else
        warn "Script $script not found, skipping."
    fi
done

# Print Summary
echo ""
info "Installation Summary"
echo "----------------------------------------"
for mod in "${success_modules[@]:-}"; do
    [[ -n "$mod" ]] && success " ${mod}"
done
for mod in "${skipped_modules[@]:-}"; do
    [[ -n "$mod" ]] && warn " ${mod} (skipped)"
done
for mod in "${failed_modules[@]:-}"; do
    [[ -n "$mod" ]] && echo -e "${COLOR_ERROR}✖  ${mod} (failed)${COLOR_RESET}"
done
echo "----------------------------------------"

if [[ ${#failed_modules[@]} -gt 0 ]]; then
    warn "Some modules failed to install."
else
    success "All Installations Completed Successfully!"
fi
echo ""

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
