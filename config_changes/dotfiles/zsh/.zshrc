#!/usr/bin/env zsh
# ~/.zshrc -- bootstrapper for modular dotfiles (macOS)

DOTFILES="$HOME/dotfiles"

# Load shared modular bashrc.d scripts (aliases, functions, tools)
if [[ -d "$DOTFILES/bash/.bashrc.d" ]]; then
  for rc in "$DOTFILES/bash/.bashrc.d/"*.sh; do
    [[ -r "$rc" ]] && source "$rc"
  done
  unset rc
fi

# ──────────────────────────────
# macOS-specific / Zsh-specific config

# PATH (Homebrew first)
path=(
  /opt/homebrew/bin
  /opt/homebrew/sbin
  $path
)
typeset -U path PATH

# Zsh completion system
autoload -Uz compinit
compinit -d "${ZDOTDIR:-$HOME}/.zcompdump"

# Plugins (installed via brew maybe?)
if [[ -r /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
  source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi
if [[ -r /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
  source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# macOS-specific aliases
alias ezrc='nano ~/.zshrc'
alias flushdns='sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder'

# macOS-specific updater
updatebrew() {
  echo "🔄 Updating Homebrew..."
  brew update
  brew upgrade
  brew upgrade --cask --greedy
  brew cleanup --prune=all
  brew autoremove
}

alias apps='updatebrew'

# mac-specific IP helper
whatsmyip() {
  echo "Internal IP:"
  ipconfig getifaddr en0 2>/dev/null | sed 's/^/  /'
  ipconfig getifaddr en1 2>/dev/null | sed 's/^/  /'
  echo "External IP:"
  curl -sS https://ifconfig.me || curl -sS https://api.ipify.org
  echo
}
alias whatismyip='whatsmyip'

# Shared history between zsh sessions
setopt SHARE_HISTORY HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE HIST_SAVE_NO_DUPS

# Preferred keybindings
bindkey -e   # Emacs-style bindings (use `bindkey -v` for vi-style)

# Starship for zsh (if installed)
if command -v starship &>/dev/null; then
  eval "$(starship init zsh)"
fi

# Mise runtime manager (if installed)
if command -v mise &>/dev/null; then
  eval "$(mise activate zsh)"
fi