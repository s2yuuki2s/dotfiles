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

# 3. Configure Shells (Idempotent block)
CONFIG_START="# --- FNM CONFIG START ---"
CONFIG_END="# --- FNM CONFIG END ---"

for RC in "$HOME/.bashrc" "$HOME/.zshrc"; do
  [[ ! -f "$RC" ]] && continue

  sed -i "/$CONFIG_START/,/$CONFIG_END/d" "$RC"

  echo "Updating FNM config in $RC..."
  cat <<EOF >> "$RC"
$CONFIG_START
export PATH="\$HOME/.local/share/fnm:\$PATH"
if command -v fnm >/dev/null; then
  eval "\$(fnm env --use-on-cd)"
fi
$CONFIG_END
EOF
done

echo "FNM setup complete. Please restart your terminal or run: source ~/.bashrc"
