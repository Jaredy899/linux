# Exit early if not interactive
case $- in
*i*) ;;
*) return 0 2>/dev/null || exit 0 ;;
esac

# fastfetch
if command -v fastfetch &>/dev/null; then
  fastfetch
fi

# Source global bashrc
[[ -r /etc/bashrc ]] && . /etc/bashrc

# Bash completion
if [[ -r /usr/share/bash-completion/bash_completion ]]; then
  . /usr/share/bash-completion/bash_completion
elif [[ -r /etc/bash_completion ]]; then
  . /etc/bash_completion
fi

# Readline/terminal behavior
bind "set bell-style visible"
stty -ixon 2>/dev/null || true
bind "set completion-ignore-case on"
bind "set show-all-if-ambiguous On"
