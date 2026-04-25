#!/usr/bin/env bash
set -euo pipefail

echo "== Lazydocker Installer =="

# 1. Check dependencies
if ! command -v curl >/dev/null 2>&1; then
  echo "Error: curl is required. Please run terminal.sh first."
  exit 1
fi

# Temporarily add local bin to PATH for this script session
# This ensures 'command -v' can see lazydocker right after install
export PATH="$HOME/.local/bin:$PATH"

# 2. Install Lazydocker if not present
if ! command -v lazydocker >/dev/null 2>&1; then
  echo "Installing Lazydocker..."
  mkdir -p "$HOME/.local/bin"
  curl -fsSL https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash
else
  echo "Lazydocker is already installed ($(lazydocker --version | head -n 1))"
fi

# 3. Ensure ~/.local/bin is in PATH (Using exact match to avoid /usr/local/bin conflict)
CONFIG_START="# --- USER LOCAL BIN CONFIG START ---"
CONFIG_END="# --- USER LOCAL BIN CONFIG END ---"

for RC in "$HOME/.bashrc" "$HOME/.zshrc"; do
  [[ ! -f "$RC" ]] && continue

  sed -i "/$CONFIG_START/,/$CONFIG_END/d" "$RC"

  echo "Updating local bin configuration in $RC..."
  cat <<EOF >>"$RC"
$CONFIG_START
export PATH="\$HOME/.local/bin:\$PATH"
$CONFIG_END
EOF
done

echo "✅ Lazydocker setup complete."
