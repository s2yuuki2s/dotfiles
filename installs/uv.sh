#!/usr/bin/env bash
set -euo pipefail

echo "== UV Installer (Perfect Edition) =="

# 1. Install dependencies
if ! command -v curl >/dev/null 2>&1; then
  echo "Installing curl..."
  sudo apt-get update && sudo apt-get install -y curl
fi

# 2. Install/Update UV
# Ensure ~/.local/bin exists so the installer prefers it
mkdir -p "$HOME/.local/bin"

if ! command -v uv >/dev/null 2>&1; then
    echo "Installing uv..."
    # INSTALLER_NO_MODIFY_PATH=1 prevents the script from touching shell profiles
    # so we can manage it cleanly ourselves in step 4.
    curl -LsSf https://astral.sh/uv/install.sh | INSTALLER_NO_MODIFY_PATH=1 sh
else
    echo "uv is already installed. ($(uv --version))"
fi

# 3. Setup Environment for the current session
export PATH="$HOME/.local/bin:$PATH"

# 4. Configure Shells (Idempotent & Managed block)
CONFIG_START="# --- UV CONFIG START ---"
CONFIG_END="# --- UV CONFIG END ---"

for RC in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [[ ! -f "$RC" ]] && continue
    
    # Get shell name (bash or zsh)
    SHELL_NAME=$(basename "$RC" | sed 's/rc//; s/^\.//')
    
    # Clean old block to avoid duplicates and allow updates
    sed -i "/$CONFIG_START/,/$CONFIG_END/d" "$RC"
    
    echo "Updating uv configuration in $RC..."
    cat <<EOF >> "$RC"
$CONFIG_START
# Add uv to PATH
export PATH="\$HOME/.local/bin:\$PATH"

# uv shell completion (auto-generated)
if command -v uv >/dev/null 2>&1; then
    eval "\$(uv generate-shell-completion $SHELL_NAME)"
    eval "\$(uvx --generate-shell-completion $SHELL_NAME)"
fi
$CONFIG_END
EOF
done

echo "✅ uv setup complete. Run 'uv --version' to verify."
