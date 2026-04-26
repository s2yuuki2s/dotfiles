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

# 4. Configure .zshrc plugins
if [[ -f "$HOME/.zshrc" ]]; then
    info "Configuring plugins in .zshrc..."
    for plugin in git zsh-autosuggestions zsh-syntax-highlighting fzf; do
        if ! grep -q "plugins=(.*$plugin.*)" "$HOME/.zshrc"; then
            sed -i "s/plugins=(\(.*\))/plugins=(\1 $plugin)/" "$HOME/.zshrc"
        fi
    done
fi

# 5. Change Default Shell
if [[ "$SHELL" != *"zsh"* ]]; then
    info "Changing default shell to Zsh..."
    sudo chsh -s "$(which zsh)" "$USER"
fi

info "✅ Zsh setup complete."
