#!/usr/bin/env bash
# Exit early if not interactive
case $- in
*i*) ;;
*) # shellcheck disable=SC2317
   return 0 2>/dev/null || exit 0 ;;
esac

# fastfetch
if command -v fastfetch &>/dev/null; then
  fastfetch
fi

# Source global bashrc
# shellcheck disable=SC1091
[[ -r /etc/bashrc ]] && . /etc/bashrc

# Bash completion
if [[ -r /usr/share/bash-completion/bash_completion ]]; then
  # shellcheck disable=SC1091
  . /usr/share/bash-completion/bash_completion
elif [[ -r /etc/bash_completion ]]; then
  # shellcheck disable=SC1091
  . /etc/bash_completion
fi

# Readline/terminal behavior
bind "set bell-style visible"
stty -ixon 2>/dev/null || true
bind "set completion-ignore-case on"
bind "set show-all-if-ambiguous On"
