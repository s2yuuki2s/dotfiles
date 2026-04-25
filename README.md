# 🚀 Ultimate Dotfiles Auto-Installer

Professional environment setup for Ubuntu/Debian (x86_64 & ARM64).

## ⚡ Quick Install (One-liner)

Run this command to set up everything and auto-delete installer files after
completion:

```bash
curl -sSL \
  https://raw.githubusercontent.com/s2yuuki2s/dotfiles/main/bootstrap.sh \
  | bash
```

## ✨ Features

- **Smart Detection:** Automatically detects Intel/AMD or Apple Silicon/ARM.
- **Zero-Touch:** Auto-sudo keep-alive during installation.
- **Self-Cleaning:** Automatically removes temporary files after success.
- **Modern Stack:** Zsh, Neovim (Latest), Docker, Zellij, Starship, Fnm, Rust,
  Uv.

## 📂 Directory Structure

- `setup.sh`: Main orchestrator with architecture detection.
- `bootstrap.sh`: Entry point for one-liner installation.
- `installs/`: Modular installation scripts.
  - `zsh.sh`: Zsh, Oh My Zsh & Plugins.
  - `terminal.sh`: Modern CLI tools (eza, fzf, starship, etc.).
  - `neovim.sh`: Latest Neovim with architecture support.
  - `docker.sh`: Docker Engine & Compose.
  - `fnm.sh`, `rust.sh`, `uv.sh`: Language runtimes.

## 🛠 Manual Usage

1. **Clone & Run**:

   ```bash
   git clone https://github.com/s2yuuki2s/dotfiles.git
   cd dotfiles
   chmod +x setup.sh
   ./setup.sh
   ```

2. **Run with Auto-Cleanup**:

   ```bash
   ./setup.sh --cleanup
   ```

## 📝 Important Notes

- Supports **x86_64** and **ARM64**.
- Idempotent configuration (safe to run multiple times).
- Requires `sudo` privileges.
