#!/usr/bin/env bash
# Extra dev tools and integrations

alias bd='bun dev'
alias cr='cargo run'

# Fzf bindings
# shellcheck disable=SC1090
[ -f ~/.fzf.bash ] && source ~/.fzf.bash

# Zoxide
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init bash)"
fi

# Starship prompt
if command -v starship &>/dev/null; then
  eval "$(starship init bash)"
fi

if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate bash)"
fi

# Auto-start X if TTY1 and dwm config found
if [[ "$(tty)" == "/dev/tty1" ]] && [[ -f "$HOME/.xinitrc" ]] && grep -q "^exec dwm" "$HOME/.xinitrc"; then
  command -v startx &>/dev/null && startx
fi

# Cargo environment
# shellcheck disable=SC1091
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
