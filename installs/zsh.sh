#!/usr/bin/env bash
set -euo pipefail

[[ -z "${DOTFILES_DIR:-}" ]] && DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$DOTFILES_DIR/lib/utils.sh"

info "== Installing Zsh & Oh My Zsh =="

# 1. Install Zsh
apt_install zsh

# 2. Install Oh My Zsh (Unattended)
OMZ_DIR="$HOME/.oh-my-zsh"
if [[ ! -d "$OMZ_DIR" ]]; then
  info "Installing Oh My Zsh..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
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
    for plugin in git zsh-autosuggestions zsh-syntax-highlighting fzf; do
        if ! grep -qE "^plugins=\(.*$plugin.*\)" "$HOME/.zshrc"; then
            # Try to add it to the plugins list
            sed -i "/^plugins=(/ s/)/ $plugin)/" "$HOME/.zshrc"
        fi
    done

    # Custom completions block
    ZSH_COMP_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/completions"
    mkdir -p "$ZSH_COMP_DIR"
    
    START_MARKER="# --- ZSH CUSTOM START ---"
    END_MARKER="# --- ZSH CUSTOM END ---"
    ZSH_CUSTOM_CONTENT=$(cat <<EOF
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

# 5. Change Default Shell
if [[ "$SHELL" != *"zsh"* ]]; then
    info "Changing default shell to Zsh..."
    sudo chsh -s "$(which zsh)" "$USER"
fi

info "✅ Zsh setup complete."
