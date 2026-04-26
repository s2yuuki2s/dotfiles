#!/usr/bin/env bash
set -euo pipefail

# 0. Architecture Detection
OS_ARCH="${OS_ARCH:-$(uname -m)}"
case "$OS_ARCH" in
    x86_64)  OS_ARCH="x86_64" ;;
    aarch64|arm64) OS_ARCH="arm64" ;;
    *) echo "Unsupported architecture: $OS_ARCH"; exit 1 ;;
esac

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

# 4. Generate Static Completions for Zsh (Optimization)
if [[ -d "$HOME/.oh-my-zsh" ]]; then
  echo "Generating static completions for Oh My Zsh..."
  ZSH_COMP_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/completions"
  mkdir -p "$ZSH_COMP_DIR"
  zellij setup --generate-completion zsh >"$ZSH_COMP_DIR/_zellij"
fi

echo "✅ Zellij $(zellij --version) installed. Configuration managed via ~/.shell_common"
