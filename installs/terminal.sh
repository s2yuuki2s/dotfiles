#!/usr/bin/env bash
set -euo pipefail

echo "== Terminal Tools Installer =="

# 1. Architecture Detection
OS_ARCH="${OS_ARCH:-$(uname -m)}"
case "$OS_ARCH" in
    x86_64)  OS_ARCH="x86_64" ;;
    aarch64|arm64) OS_ARCH="arm64" ;;
    *) echo "Unsupported architecture: $OS_ARCH"; exit 1 ;;
esac
echo "Architecture: $OS_ARCH"

# 2. Core Dependencies & Repositories
echo "Preparing repositories..."

# Fix legacy/broken eza repo if it exists before running update
BROKEN_REPO=$(sudo grep -l "deb.gierrt.me" /etc/apt/sources.list.d/* 2>/dev/null || true)
if [[ -n "$BROKEN_REPO" ]]; then
  echo "Fixing broken eza repository in $BROKEN_REPO..."
  sudo sed -i 's/deb.gierrt.me/deb.gierens.de/g' "$BROKEN_REPO"
fi

sudo apt-get update
sudo apt-get install -y curl wget jq gnupg ca-certificates software-properties-common

# Add Eza Repo (if not already handled or installed)
if ! command -v eza >/dev/null 2>&1 && [[ ! -f /etc/apt/sources.list.d/gierrt-eza.list ]]; then
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor --yes -o /etc/apt/keyrings/gierrt-eza-archive-keyring.gpg
  echo "deb [signed-by=/etc/apt/keyrings/gierrt-eza-archive-keyring.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierrt-eza.list
  sudo apt-get update
fi

# 3. Batch Install via APT
echo "Installing tools via APT..."
sudo apt-get install -y \
  tar unzip build-essential git \
  fzf ripgrep fd-find luarocks zoxide bat eza python3-pip python3-venv

# 4. Fast Install Binaries
# --- Lazygit ---
if ! command -v lazygit >/dev/null 2>&1; then
  echo "Installing Lazygit ($OS_ARCH)..."
  LG_ARCH=$([[ "$OS_ARCH" == "x86_64" ]] && echo "x86_64" || echo "arm64")
  LG_URL=$(curl -fsSL "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | jq -r --arg arch "linux_$LG_ARCH" '.assets[] | select(.name | contains($arch) and endswith(".tar.gz")) | .browser_download_url')

  if [[ -z "$LG_URL" || "$LG_URL" == "null" ]]; then
    echo "❌ Error: Could not find Lazygit download URL for $LG_ARCH"
    exit 1
  fi

  curl -fsSL "$LG_URL" | tar xz lazygit
  sudo install lazygit /usr/local/bin && rm lazygit
fi

# --- Starship ---
if ! command -v starship >/dev/null 2>&1; then
  echo "Installing Starship..."
  curl -fsSL https://starship.rs/install.sh | sh -s -- --yes
fi

# 5. Symlinks & Theme
mkdir -p "$HOME/.local/bin" "$HOME/.config"
[[ -f /usr/bin/batcat ]] && ln -sf /usr/bin/batcat "$HOME/.local/bin/bat"
[[ -f /usr/bin/fdfind ]] && ln -sf /usr/bin/fdfind "$HOME/.local/bin/fd"

command -v starship >/dev/null && starship preset gruvbox-rainbow -o "$HOME/.config/starship.toml"

# 6. Idempotent Shell Configuration
CONFIG_START="# --- TERMINAL TOOLS CONFIG START ---"
CONFIG_END="# --- TERMINAL TOOLS CONFIG END ---"

for RC in "$HOME/.bashrc" "$HOME/.zshrc"; do
  [[ ! -f "$RC" ]] && continue

  SHELL_NAME=$(basename "$RC" | sed 's/rc//; s/^\.//')

  # Clean old config block if exists (to allow updates)
  sed -i "/$CONFIG_START/,/$CONFIG_END/d" "$RC"

  # Oh My Zsh fzf plugin handling (only if not already in plugins)
  if [[ "$SHELL_NAME" == "zsh" && -d "$HOME/.oh-my-zsh" ]]; then
    if ! grep -q "plugins=(.*fzf.*)" "$RC"; then
      echo "Adding fzf plugin to Oh My Zsh..."
      sed -i 's/plugins=(\(.*\))/plugins=(\1 fzf)/' "$RC"
    fi
  fi

  echo "Updating configuration in $RC..."
  cat <<EOF >>"$RC"
$CONFIG_START
export PATH="\$HOME/.local/bin:\$PATH"

# Starship & Zoxide Init
command -v starship >/dev/null && eval "\$(starship init $SHELL_NAME)"
command -v zoxide >/dev/null && eval "\$(zoxide init $SHELL_NAME)" && alias cd="z"

# FZF & FD Keybindings/Completion (for non-OMZ or bash)
if [[ -n "\$BASH_VERSION" ]]; then
    [[ -f /usr/share/doc/fzf/examples/key-bindings.bash ]] && source /usr/share/doc/fzf/examples/key-bindings.bash
    [[ -f /usr/share/doc/fzf/examples/completion.bash ]] && source /usr/share/doc/fzf/examples/completion.bash
elif [[ -n "\$ZSH_VERSION" && ! -d "\$HOME/.oh-my-zsh" ]]; then
    [[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]] && source /usr/share/doc/fzf/examples/key-bindings.zsh
    [[ -f /usr/share/doc/fzf/examples/completion.zsh ]] && source /usr/share/doc/fzf/examples/completion.zsh
fi

# Aliases
if command -v eza >/dev/null 2>&1; then
    alias ls="eza --icons --group-directories-first"
    alias ll="eza -l --icons --group-directories-first"
    alias la="eza -a --icons --group-directories-first"
    alias tree="eza --tree --icons"
fi
$CONFIG_END
EOF
done

echo "✅ Terminal setup complete. Run 'source ~/.bashrc' or 'source ~/.zshrc' to apply."
