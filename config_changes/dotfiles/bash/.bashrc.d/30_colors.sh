#!/usr/bin/env bash
# Colors and grep defaults

export CLICOLOR=1
export LS_COLORS='no=00:fi=00:di=00;34:ln=01;36:pi=40;33:so=01;35:...'

if command -v rg &>/dev/null; then
  alias grep='rg'
else
  alias grep='grep --color=auto'
fi
