#!/usr/bin/env bash
set -euo pipefail

echo "== FNM Installer =="

# 1. Install/Update FNM
if ! command -v fnm >/dev/null 2>&1; then
  echo "Installing FNM..."
  curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
else
  echo "FNM is already installed. (Version: $(fnm --version))"
  # Optional: If you want to force update, you can uncomment the next line
  # curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
fi

# 2. Setup Environment Variables
# We need fnm in current path to run 'fnm env'
export PATH="$HOME/.local/share/fnm:$PATH"

# 3. Generate Static Completions for Zsh (Optimization)
if [[ -d "$HOME/.oh-my-zsh" ]]; then
  echo "Generating static completions for Oh My Zsh..."
  ZSH_COMP_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/completions"
  mkdir -p "$ZSH_COMP_DIR"
  fnm completions --shell zsh >"$ZSH_COMP_DIR/_fnm"
fi

echo "✅ FNM setup complete. Configuration managed via ~/.shell_common"
