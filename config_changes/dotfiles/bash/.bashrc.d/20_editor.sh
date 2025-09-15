#!/usr/bin/env bash
# Editor and pager settings

if command -v nvim &>/dev/null; then
  export EDITOR="nvim"
  export VISUAL="nvim"
  export SUDO_EDITOR="nvim"
  alias vim='nvim'
  alias vi='nvim'
  alias svi='sudo -E nvim'
  alias vis='nvim "+set si"'
else
  export EDITOR="vim"
  export VISUAL="vim"
fi

# less + manpage colors
export LESS_TERMCAP_mb=$'\E[01;31m'
export LESS_TERMCAP_md=$'\E[01;31m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_so=$'\E[01;44;33m'
export LESS_TERMCAP_ue=$'\E[0m'
export LESS_TERMCAP_us=$'\E[01;32m'
