#!/usr/bin/env bash
set -euo pipefail

echo "== Zellij Installer ($OS_ARCH) =="

# 1. Install dependencies
for cmd in curl tar; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Installing $cmd..."
    sudo apt-get update && sudo apt-get install -y "$cmd"
  fi
done

# 2. Download and Install
echo "Downloading and installing Zellij (Latest Stable)..."

if [[ "$OS_ARCH" == "x86_64" ]]; then
  ZELLIJ_URL="https://github.com/zellij-org/zellij/releases/latest/download/zellij-x86_64-unknown-linux-musl.tar.gz"
else
  ZELLIJ_URL="https://github.com/zellij-org/zellij/releases/latest/download/zellij-aarch64-unknown-linux-musl.tar.gz"
fi

curl -fsSL "$ZELLIJ_URL" | tar -xz zellij
sudo install zellij /usr/local/bin/zellij
rm zellij

# 4. Configure Shells (Idempotent block)
CONFIG_START="# --- ZELLIJ CONFIG START ---"
CONFIG_END="# --- ZELLIJ CONFIG END ---"

for RC in "$HOME/.bashrc" "$HOME/.zshrc"; do
  [[ ! -f "$RC" ]] && continue

  SHELL_NAME=$(basename "$RC" | sed 's/rc//; s/^\.//')

  # Clean old block to avoid duplicates
  sed -i "/$CONFIG_START/,/$CONFIG_END/d" "$RC"

  echo "Updating Zellij configuration in $RC..."
  if [[ "$SHELL_NAME" == "zsh" ]]; then
    ZSH_COMP_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/completions"
    mkdir -p "$ZSH_COMP_DIR"
    zellij setup --generate-completion zsh >"$ZSH_COMP_DIR/_zellij"

    cat <<EOF >>"$RC"
$CONFIG_START
# Zellij alias
alias zj="zellij"
$CONFIG_END
EOF
  else
    cat <<EOF >>"$RC"
$CONFIG_START
# Zellij shell completion
if command -v zellij >/dev/null 2>&1; then
    eval "\$(zellij setup --generate-completion $SHELL_NAME)"
    # Alias for easy access
    alias zj="zellij"
fi
$CONFIG_END
EOF
  fi
done

echo "✅ Zellij $(zellij --version) installed successfully!"
echo "Run 'zj' or 'zellij' to start."
