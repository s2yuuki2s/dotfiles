#!/usr/bin/env bash
set -euo pipefail

[[ -z "${DOTFILES_DIR:-}" ]] && DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=lib/utils.sh
source "$DOTFILES_DIR/lib/utils.sh"

info "Installing Zsh & Oh My Zsh"

# 1. Install Zsh
apt_install zsh

# 2. Install Oh My Zsh (Unattended)
OMZ_DIR="$HOME/.oh-my-zsh"
if [[ ! -d "$OMZ_DIR" ]]; then
    info "Installing Oh My Zsh..."
    run_remote_script "https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh" sh --unattended
fi

# 3. Install Plugins
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
plugins=(
    "zsh-autosuggestions:https://github.com/zsh-users/zsh-autosuggestions"
    "zsh-syntax-highlighting:https://github.com/zsh-users/zsh-syntax-highlighting"
)

for plugin_data in "${plugins[@]}"; do
    name="${plugin_data%%:*}"
    url="${plugin_data#*:}"
    if [[ ! -d "$ZSH_CUSTOM/plugins/$name" ]]; then
        info "Installing plugin: $name..."
        git clone --depth=1 "$url" "$ZSH_CUSTOM/plugins/$name"
    fi
done

# 4. Configure .zshrc plugins and completions
if [[ -f "$HOME/.zshrc" ]]; then
    info "Configuring plugins and completions in .zshrc..."

    # Ensure plugins are set correctly
    required_plugins=("git" "zsh-autosuggestions" "zsh-syntax-highlighting" "fzf")
    current_plugins=$(grep -E "^plugins=\(" "$HOME/.zshrc" | sed -E 's/plugins=\((.*)\)/\1/')

    # shellcheck disable=SC2206
    updated_plugins=($current_plugins)
    for p in "${required_plugins[@]}"; do
        if [[ ! " ${updated_plugins[*]} " == *" $p "* ]]; then
            updated_plugins+=("$p")
        fi
    done

    plugins_string="${updated_plugins[*]}"
    sed -i "s/^plugins=(.*/plugins=($plugins_string)/" "$HOME/.zshrc"

    # Custom completions block
    ZSH_COMP_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/completions"
    mkdir -p "$ZSH_COMP_DIR"

    START_MARKER="# --- ZSH CUSTOM START ---"
    END_MARKER="# --- ZSH CUSTOM END ---"
    ZSH_CUSTOM_CONTENT=$(
        cat <<EOF
$START_MARKER
# Add custom completions to fpath
fpath=(\${ZSH_CUSTOM:-\$HOME/.oh-my-zsh/custom}/completions \$fpath)
$END_MARKER
EOF
    )

    # Insert custom completions before OMZ is sourced
    if ! grep -q "$START_MARKER" "$HOME/.zshrc"; then
        sed -i "/source \$ZSH\/oh-my-zsh.sh/i $START_MARKER\n$END_MARKER\n" "$HOME/.zshrc"
    fi
    add_block_to_file "$HOME/.zshrc" "$START_MARKER" "$END_MARKER" "$ZSH_CUSTOM_CONTENT"
fi

# 5. Change default shell to Zsh
zsh_path="$(command -v zsh)"
current_login_shell="$(getent passwd "$USER" | cut -d: -f7)"
if [[ "$current_login_shell" != "$zsh_path" ]]; then
    info "Changing default shell to Zsh..."
    sudo chsh -s "$zsh_path" "$USER"
fi

success "Zsh setup complete."
