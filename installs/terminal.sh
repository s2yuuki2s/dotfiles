#!/usr/bin/env bash
set -euo pipefail

# Load utilities if not already loaded
[[ -z "${DOTFILES_DIR:-}" ]] && DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$DOTFILES_DIR/lib/utils.sh"

info "== Configuring Terminal Environment =="

# 1. Install APT tools
apt_install fzf ripgrep fd-find luarocks zoxide bat eza python3-pip python3-venv direnv fish

# 2. Install GitHub tools
install_from_github "jesseduffield/lazygit" "lazygit" "tar.gz"
install_from_github "ast-grep/ast-grep" "sg" ".zip" "ast-grep"

# 3. Install Starship
if ! command -v starship >/dev/null 2>&1; then
  info "Installing Starship..."
  run_remote_script "https://starship.rs/install.sh" sh --yes
fi

# 4. Symlinks & Theme
mkdir -p "$HOME/.local/bin" "$HOME/.config"
[[ -f /usr/bin/batcat ]] && ln -sf /usr/bin/batcat "$HOME/.local/bin/bat"
[[ -f /usr/bin/fdfind ]] && ln -sf /usr/bin/fdfind "$HOME/.local/bin/fd"

command -v starship >/dev/null && starship preset gruvbox-rainbow -o "$HOME/.config/starship.toml"

# 5. Common Configuration
COMMON_RC="$HOME/.shell_common"
CONFIG_START="# --- TERMINAL TOOLS CONFIG START ---"
CONFIG_END="# --- TERMINAL TOOLS CONFIG END ---"

info "Updating common shell configuration in $COMMON_RC..."

CONTENT=$(
  cat <<EOF
$CONFIG_START
# --- Environment Variables ---
export PATH="\$HOME/.local/bin:\$HOME/.local/share/fnm:\$PATH"
export EDITOR='nvim'
export VISUAL='nvim'
command -v zsh >/dev/null 2>&1 && export SHELL="\$(command -v zsh)"
CURRENT_SHELL="zsh"

# --- Tool Initializations ---
command -v starship >/dev/null 2>&1 && eval "\$(starship init "\$CURRENT_SHELL")"
if command -v zoxide >/dev/null 2>&1; then
    eval "\$(zoxide init "\$CURRENT_SHELL")"
    alias cd="z"
fi
command -v fnm >/dev/null 2>&1 && eval "\$(fnm env --use-on-cd --shell "\$CURRENT_SHELL")"
command -v direnv >/dev/null 2>&1 && eval "\$(direnv hook "\$CURRENT_SHELL")"

if command -v zellij >/dev/null 2>&1; then
    alias zj="zellij"
fi


# --- FZF & FD Keybindings ---
if [[ "\$CURRENT_SHELL" == "zsh" && ! -d "\$HOME/.oh-my-zsh" ]]; then
    [[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]] && source /usr/share/doc/fzf/examples/key-bindings.zsh
    [[ -f /usr/share/doc/fzf/examples/completion.zsh ]] && source /usr/share/doc/fzf/examples/completion.zsh
fi

# --- Aliases ---
if command -v eza >/dev/null 2>&1; then
    alias ls='eza -al --color=always --group-directories-first --icons=always'
    alias la='eza -a --color=always --group-directories-first --icons=always'
    alias ll='eza -l --color=always --group-directories-first --icons=always'
    alias lt='eza -aT --color=always --group-directories-first --icons=always'
    alias l.="eza -a | grep -e '^\.'"
else
    alias ls="ls --color=auto"
    alias ll="ls -l --color=auto"
    alias la="ls -a --color=auto"
fi
$CONFIG_END
EOF
)

add_block_to_file "$COMMON_RC" "$CONFIG_START" "$CONFIG_END" "$CONTENT"

# Ensure sourcing in .zshrc only
if [[ -f "$HOME/.zshrc" ]]; then
  sed -i "/$CONFIG_START/,/$CONFIG_END/d" "$HOME/.zshrc"
  if ! grep -q "source $COMMON_RC" "$HOME/.zshrc"; then
    echo "[ -f $COMMON_RC ] && source $COMMON_RC" >>"$HOME/.zshrc"
  fi
fi
