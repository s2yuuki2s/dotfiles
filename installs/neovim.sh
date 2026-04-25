#!/usr/bin/env bash
set -euo pipefail

echo "== Neovim Installer ($OS_ARCH) =="

# 1. Install dependencies
echo "Checking dependencies..."
for pkg in curl tar build-essential unzip; do
  if ! dpkg -s "$pkg" >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y curl tar build-essential unzip
    break
  fi
done

# 2. Version Check (Avoid redundant downloads)
export PATH="$HOME/.local/bin:$PATH"
if command -v nvim >/dev/null 2>&1; then
    CURRENT_VERSION=$(nvim --version | head -n 1 | awk '{print $2}')
    echo "Current Neovim version: $CURRENT_VERSION"
fi

# 3. Download and Install
echo "Installing/Updating Neovim to Latest Stable..."
sudo rm -rf /opt/nvim
sudo mkdir -p /opt/nvim

# Select correct binary based on architecture
if [[ "$OS_ARCH" == "x86_64" ]]; then
    NVIM_URL="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz"
else
    NVIM_URL="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-arm64.tar.gz"
fi

curl -fsSL "$NVIM_URL" | sudo tar -C /opt/nvim --strip-components=1 -xzf -

# 4. Create symlinks
sudo ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim
mkdir -p "$HOME/.local/bin"
ln -sf /opt/nvim/bin/nvim "$HOME/.local/bin/nvim"

# 6. Ensure ~/.local/bin is in PATH for future use (Idempotent)
CONFIG_START="# --- USER LOCAL BIN CONFIG START ---"
CONFIG_END="# --- USER LOCAL BIN CONFIG END ---"

for RC in "$HOME/.bashrc" "$HOME/.zshrc"; do
  [[ ! -f "$RC" ]] && continue
  
  sed -i "/$CONFIG_START/,/$CONFIG_END/d" "$RC"
  
  echo "Updating local bin configuration in $RC..."
  cat <<EOF >> "$RC"
$CONFIG_START
export PATH="\$HOME/.local/bin:\$PATH"
$CONFIG_END
EOF
done

# 7. Final verification
if command -v nvim >/dev/null 2>&1 || [ -f "/usr/local/bin/nvim" ]; then
  INSTALLED_VER=$(/usr/local/bin/nvim --version | head -n 1)
  echo "✅ $INSTALLED_VER installed successfully!"
else
  echo "❌ Error: Neovim installation failed."
  exit 1
fi

echo "Neovim setup complete. Run 'nvim' to start."
