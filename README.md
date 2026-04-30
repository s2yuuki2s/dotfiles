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
- **Safer Latest Installs:** Remote installer scripts are downloaded to temp files before execution; GitHub binaries use checksum verification when release checksums are available.
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

   > `--cleanup` is intended for bootstrap temp installs (`~/.dotfiles-temp`) and is safety-guarded to avoid deleting regular cloned repositories.

3. **Run selected modules only**:

   ```bash
   ./setup.sh --only=zsh,terminal,neovim
   ```
   Available modules: `zsh`, `terminal`, `fnm`, `uv`, `rust`, `sdkman`, `neovim`, `zellij`, `docker`, `lazydocker`.

4. **Skip modules**:

   ```bash
   ./setup.sh --skip=docker,lazydocker
   ```

5. **Strict checksum mode for GitHub assets**:

   ```bash
   ./setup.sh --strict-checksum
   ```

6. **Disable automatic switch to Zsh session after setup**:

   ```bash
   ./setup.sh --no-auto-shell-switch
   ```

   By default, interactive setup sessions auto-switch to `zsh -l` at the end.

## ✅ QA Workflow (Unified)

Use a single entrypoint to check/fix shell scripts:

```bash
# Check syntax, module wiring, and lint
bash ./scripts/qa.sh check

# Auto-format shell scripts, then re-run checks
bash ./scripts/qa.sh fix
```

## 📝 Important Notes

- Supports **x86_64** and **ARM64**.
- Idempotent configuration (safe to run multiple times).
- Requires `sudo` privileges.
- Uses a lock at `/tmp/dotfiles-setup.lock` to prevent concurrent setup runs.
