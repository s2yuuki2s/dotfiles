#!/usr/bin/env bash
set -euo pipefail

echo "== Zsh & Oh My Zsh Installer (Perfect Edition) =="

# 1. Install Dependencies
echo "Installing Zsh and core tools..."
sudo apt-get update
sudo apt-get install -y zsh curl git

# 2. Install Oh My Zsh (Unattended)
# --unattended: prevents the installer from switching to zsh immediately
# so the script can continue executing.
OMZ_DIR="$HOME/.oh-my-zsh"
if [[ ! -d "$OMZ_DIR" ]]; then
  echo "Installing Oh My Zsh..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
  echo "Oh My Zsh is already installed."
fi

# 3. Install High-Quality Plugins
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# Function to clone plugins if not exists
install_plugin() {
  local name=$1
  local url=$2
  if [[ ! -d "$ZSH_CUSTOM/plugins/$name" ]]; then
    echo "Installing plugin: $name..."
    git clone --depth=1 "$url" "$ZSH_CUSTOM/plugins/$name"
  fi
}

install_plugin "zsh-autosuggestions" "https://github.com/zsh-users/zsh-autosuggestions"
install_plugin "zsh-syntax-highlighting" "https://github.com/zsh-users/zsh-syntax-highlighting"

# 4. Configure Oh My Zsh (Idempotent plugin setup)
if [[ -f "$HOME/.zshrc" ]]; then
  echo "Configuring plugins in .zshrc..."
  # Ensure base plugins are present without removing existing ones like fzf
  for plugin in git zsh-autosuggestions zsh-syntax-highlighting; do
    if ! grep -q "plugins=(.*$plugin.*)" "$HOME/.zshrc"; then
      sed -i "s/plugins=(\(.*\))/plugins=(\1 $plugin)/" "$HOME/.zshrc"
    fi
  done
fi

# 5. Change Default Shell to Zsh
if [[ "$SHELL" != *"zsh"* ]]; then
  echo "Changing your default shell to Zsh..."
  # Use sudo chsh to avoid password prompt if possible, or just chsh
  sudo chsh -s "$(which zsh)" "$USER"
fi

echo "✅ Zsh setup complete. Your terminal will be Zsh next time you log in."
echo "Note: Starship configuration is handled by terminal.sh"
