#!/usr/bin/env bash
set -euo pipefail

echo "== Rust (rustup) Installer =="

# 1. Install dependencies
# Rust needs curl to download and build-essential (gcc) to link binaries
echo "Checking dependencies..."
for pkg in curl build-essential; do
  if ! dpkg -s "$pkg" >/dev/null 2>&1; then
    echo "Installing $pkg..."
    sudo apt-get update
    sudo apt-get install -y curl build-essential
    break
  fi
done

# 2. Install or Update Rust
# Try to source environment first in case it's already installed but not in PATH
# shellcheck source=/dev/null
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"

if ! command -v rustup >/dev/null 2>&1; then
  echo "Installing Rust via rustup..."
  # Use --no-modify-path because we handle it manually in step 4
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
else
  echo "Rust is already installed ($(rustc --version | awk '{print $2}'))"
  if [[ "${AUTO_YES:-false}" == "true" ]]; then
    rustup update
  else
    read -r -p "Update Rust now? (y/N): " c
    [[ "$c" =~ ^[Yy]$ ]] && rustup update
  fi
fi

# 3. Source environment for the current script session
# This allows 'rustc' to be used immediately in the next step
# shellcheck source=/dev/null
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"

# 4. Configure Shells (Idempotent block)
CONFIG_START="# --- RUST CONFIG START ---"
CONFIG_END="# --- RUST CONFIG END ---"

for RC in "$HOME/.bashrc" "$HOME/.zshrc"; do
  [[ ! -f "$RC" ]] && continue

  sed -i "/$CONFIG_START/,/$CONFIG_END/d" "$RC"

  echo "Updating Rust configuration in $RC..."
  cat <<EOF >>"$RC"
$CONFIG_START
if [ -f "\$HOME/.cargo/env" ]; then
    source "\$HOME/.cargo/env"
fi
$CONFIG_END
EOF
done

# 5. Final Verification
if command -v rustc >/dev/null 2>&1; then
  echo "✅ Rust $(rustc --version | awk '{print $2}') installed successfully!"
else
  echo "❌ Error: Rust installation could not be verified."
  exit 1
fi

echo "Rust setup complete. Open a new terminal or run: source ~/.cargo/env"
