#!/usr/bin/env bash
# History + general environment

# History settings
export HISTFILESIZE=10000
export HISTSIZE=500
export HISTTIMEFORMAT="%F %T "
export HISTCONTROL=erasedups:ignoredups:ignorespace
shopt -s histappend
shopt -s checkwinsize

# Prompt command helper
pc_add() {
  local add="$1"
  add="${add#"${add%%[![:space:]]*}"}"
  add="${add%"${add##*[![:space:]]}"}"
  [[ -z $add ]] && return 0
  local cur="${PROMPT_COMMAND:-}"
  cur="${cur%%+([[:space:]]|\;)}"
  local cur_wrapped=";$cur;"
  cur_wrapped="${cur_wrapped// ;/;}"
  cur_wrapped="${cur_wrapped//; /;}"
  local add_norm="$add"
  add_norm="${add_norm// ;/;}"
  add_norm="${add_norm//; /;}"
  if [[ -n $cur && $cur_wrapped == *";$add_norm;"* ]]; then return 0; fi
  if [[ -n $cur ]]; then PROMPT_COMMAND="$cur;$add"; else PROMPT_COMMAND="$add"; fi
}

# History sync across sessions
pc_add 'history -a'
pc_add 'history -n'

# XDG base directories
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
