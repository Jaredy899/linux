#!/usr/bin/env bash
# shellcheck shell=bash

# -------------------------------------------------------------------
# Exit early if not interactive
# -------------------------------------------------------------------
case $- in
  *i*) ;;
  *) return 0 2>/dev/null || exit 0 ;;
esac

# -------------------------------------------------------------------
# Minimal work before prompt
# -------------------------------------------------------------------
if command -v fastfetch &>/dev/null; then
  fastfetch
fi

# Source global bashrc if present
if [[ -r /etc/bashrc ]]; then
  # shellcheck disable=SC1091
  . /etc/bashrc
fi

# Bash-completion
if [[ -r /usr/share/bash-completion/bash_completion ]]; then
  # shellcheck disable=SC1091
  . /usr/share/bash-completion/bash_completion
elif [[ -r /etc/bash_completion ]]; then
  # shellcheck disable=SC1091
  . /etc/bash_completion
fi

# -------------------------------------------------------------------
# Readline/terminal behavior
# -------------------------------------------------------------------
bind "set bell-style visible"
stty -ixon 2>/dev/null || true
bind "set completion-ignore-case on"
bind "set show-all-if-ambiguous On"

# -------------------------------------------------------------------
# Safe PROMPT_COMMAND helper (dedup, normalize)
# -------------------------------------------------------------------
# Normalize existing PROMPT_COMMAND once on load (remove trailing ; and trim)
if [[ -n ${PROMPT_COMMAND:-} ]]; then
  # Strip trailing semicolons and whitespace
  PROMPT_COMMAND="${PROMPT_COMMAND%%+([[:space:]]|\;)}"
fi

pc_add() {
  local add="$1"
  # Trim requested snippet
  add="${add#"${add%%[![:space:]]*}"}"
  add="${add%"${add##*[![:space:]]}"}"
  [[ -z $add ]] && return 0

  # Normalize current PROMPT_COMMAND (remove trailing ;)
  local cur="${PROMPT_COMMAND:-}"
  cur="${cur%%+([[:space:]]|\;)}"

  # Build a semicolon-wrapped version for robust contains check
  local cur_wrapped=";$cur;"
  # Also normalize spaces around semicolons to single semicolons for comparison
  cur_wrapped="${cur_wrapped// ;/;}"
  cur_wrapped="${cur_wrapped//; /;}"
  local add_norm="$add"
  add_norm="${add_norm// ;/;}"
  add_norm="${add_norm//; /;}"
  if [[ -n $cur && $cur_wrapped == *";$add_norm;"* ]]; then
    return 0
  fi

  if [[ -n $cur ]]; then
    PROMPT_COMMAND="$cur;$add"
  else
    PROMPT_COMMAND="$add"
  fi
}

# History and window size
export HISTFILESIZE=10000
export HISTSIZE=500
export HISTTIMEFORMAT="%F %T "
export HISTCONTROL=erasedups:ignoredups:ignorespace
shopt -s histappend
shopt -s checkwinsize
pc_add 'history -a'

# -------------------------------------------------------------------
# XDG and PATH
# -------------------------------------------------------------------
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

export LINUXTOOLBOXDIR="$HOME/linuxtoolbox"

path_add() {
  case ":$PATH:" in
    *":$1:"*) ;;
    *) PATH="${PATH:+"$PATH:"}$1" ;;
  esac
}
path_add "$HOME/.local/bin"
path_add "$HOME/.cargo/bin"
path_add "/var/lib/flatpak/exports/bin"
path_add "$HOME/.local/share/flatpak/exports/bin"
export PATH

# -------------------------------------------------------------------
# Editor and pager
# -------------------------------------------------------------------
if command -v nvim &>/dev/null; then
  export EDITOR="nvim"
  export VISUAL="nvim"
  alias vim='nvim'
  alias vi='nvim'
  alias svi='sudo -E nvim'
  alias vis='nvim "+set si"'
else
  export EDITOR="vim"
  export VISUAL="vim"
fi

# less colors for manpages
export LESS_TERMCAP_mb=$'\E[01;31m'
export LESS_TERMCAP_md=$'\E[01;31m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_so=$'\E[01;44;33m'
export LESS_TERMCAP_ue=$'\E[0m'
export LESS_TERMCAP_us=$'\E[01;32m'

# -------------------------------------------------------------------
# Colors and grep/rg
# -------------------------------------------------------------------
export CLICOLOR=1
export LS_COLORS='no=00:fi=00:di=00;34:ln=01;36:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arj=01;31:*.taz=01;31:*.lzh=01;31:*.zip=01;31:*.z=01;31:*.Z=01;31:*.gz=01;31:*.bz2=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.jpg=01;35:*.jpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.avi=01;35:*.fli=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.ogg=01;35:*.mp3=01;35:*.wav=01;35:*.xml=00;31:'

if command -v rg &>/dev/null; then
  alias grep='rg'
else
  alias grep='grep --color=auto'
fi

# -------------------------------------------------------------------
# Safer core command aliases
# -------------------------------------------------------------------
alias cp='cp -i'
alias mv='mv -i'
if command -v trash &>/dev/null; then
  alias rm='trash -v'
else
  alias rm='rm -i'
fi
alias mkdir='mkdir -p'
alias less='less -R'
alias cls='clear'
alias ps='ps auxf'
alias multitail='multitail --no-repeat -c'
alias freshclam='sudo freshclam'

# apt helpers
alias apt-get='sudo apt-get'
if command -v nala &>/dev/null; then
  apt() { sudo nala "$@"; }
fi

# Docker helpers
alias dup='docker compose up -d --force-recreate'
alias docker-clean='docker container prune -f && docker image prune -f && docker network prune -f && docker volume prune -f'

# Misc shortcuts
alias ff='fastfetch -c all'
alias jc='sh <(curl -fsSL jaredcervantes.com/linux)'
alias nfzf='nano "$(fzf -m --preview="bat --color=always {}")"'
alias update='curl -fsSL https://raw.githubusercontent.com/Jaredy899/linux/refs/heads/main/installs/updater.sh | sh'
alias convert='heif-convert'
alias rebuild='sudo nixos-rebuild switch'
alias web='cd /var/www/html'
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history | tail -n1 | sed -e "s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//")"'
alias ebrc='${EDITOR:-nano} ~/.bashrc'
alias hlp='less ~/.bashrc_help'
alias da='date "+%Y-%m-%d %A %T %Z"'
alias sha1='openssl sha1'
alias clickpaste='sleep 3; xdotool type "$(xclip -o -selection clipboard)"'

# ls family: prefer eza if available; otherwise fall back to GNU ls aliases
if command -v eza &>/dev/null; then
  # Base eza options:
  # -a: show hidden, -h: human sizes, --icons: icons when supported
  alias ls='eza -a --icons --group-directories-first'

  # Common variants mapped to eza
  alias la='eza -Alh --icons --group-directories-first'        # show hidden, long
  alias ll='eza -l --icons --group-directories-first'          # long listing
  alias lla='eza -Al --icons --group-directories-first'        # all + long
  alias las='eza -A --icons --group-directories-first'         # all except . and ..
  alias lw='eza -a1 --icons'                                   # one-per-line, all
  alias lr='eza -lR --icons --group-directories-first'         # recursive long
  alias lt='eza -ltrh --icons --group-directories-first'       # sort by date
  alias lk='eza -lSrh --icons --group-directories-first'       # sort by size
  alias lx='eza -lXBh --icons --group-directories-first'       # sort by extension
  alias lc='eza -ltcrh --icons --group-directories-first'      # sort by change time
  alias lu='eza -lturh --icons --group-directories-first'      # sort by access time
  alias lm='eza -alh --icons | more'                           # pipe through more
  alias labc='eza -lap --icons --group-directories-first'      # alphabetical
  alias lf='eza -l --icons --group-directories-first | egrep -v "^d"'   # files only
  alias ldir='eza -l --icons --group-directories-first | egrep "^d"'    # dirs only

  # Extras: git and tree-style views
  alias lg='eza -l --git --icons --group-directories-first'    # long with git
  alias tree='eza -T --icons --group-directories-first'        # tree view
  alias treed='eza -T -D --icons --group-directories-first'    # tree dirs only
else
  # Fallback to your original ls aliases
  alias ls='ls -aFh --color=always'
  alias la='ls -Alh'
  alias lx='ls -lXBh'
  alias lk='ls -lSrh'
  alias lc='ls -ltcrh'
  alias lu='ls -lturh'
  alias lr='ls -lRh'
  alias lt='ls -ltrh'
  alias lm='ls -alh | more'
  alias lw='ls -xAh'
  alias ll='ls -Fls'
  alias labc='ls -lap'
  alias lf="ls -l | egrep -v '^d'"
  alias ldir="ls -l | egrep '^d'"
  alias lla='ls -Al'
  alias las='ls -A'
  alias lls='ls -l'
  alias tree='tree -CAhF --dirsfirst'
  alias treed='tree -CAFd'
fi

# Remove a directory and all files
alias rmd='/bin/rm  --recursive --force --verbose '

# chmod helpers (optional; remove if risky)
alias mx='sudo chmod a+x'
alias 000='sudo chmod -R 000'
alias 644='sudo chmod -R 644'
alias 666='sudo chmod -R 666'
alias 755='sudo chmod -R 755'
alias 777='sudo chmod -R 777'

# Search helpers
alias h="history | grep -- "
alias p="ps aux | grep -- "
alias topcpu="/bin/ps -eo pcpu,pid,user,args | sort -k1 -r | head -10"
alias f="find . | grep -- "
alias countfiles='for t in files links directories; do echo "$(find . -type ${t:0:1} 2>/dev/null | wc -l)" "$t"; done'

# Networking and disks
alias openports='netstat -nape --inet'
alias rebootsafe='sudo shutdown -r now'
alias rebootforce='sudo shutdown -r -n now'
alias diskspace="du -S | sort -n -r | more"
alias folders='du -h --max-depth=1'
alias folderssort='find . -maxdepth 1 -type d -print0 | xargs -0 du -sk | sort -rn'
alias mountedinfo='df -hT'

# Archives
alias mktar='tar -cvf'
alias mkbz2='tar -cvjf'
alias mkgz='tar -cvzf'
alias untar='tar -xvf'
alias unbz2='tar -xvjf'
alias ungz='tar -xvzf'

# Change directory aliases
alias home='cd ~'
alias cd..='cd ..'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'

# -------------------------------------------------------------------
# Functions
# -------------------------------------------------------------------

# Distribution detection
distribution() {
  local dtype=unknown
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    case "$ID" in
      fedora|rhel|centos) dtype=redhat ;;
      sles|opensuse*) dtype=suse ;;
      ubuntu|debian) dtype=debian ;;
      gentoo) dtype=gentoo ;;
      arch|manjaro) dtype=arch ;;
      slackware) dtype=slackware ;;
      solus) dtype=solus ;;
      nixos) dtype=nixos ;;
      *) ;;
    esac
    if [[ $dtype == unknown && -n ${ID_LIKE:-} ]]; then
      case "$ID_LIKE" in
        *fedora*|*rhel*|*centos*) dtype=redhat ;;
        *sles*|*opensuse*) dtype=suse ;;
        *ubuntu*|*debian*) dtype=debian ;;
        *gentoo*) dtype=gentoo ;;
        *arch*) dtype=arch ;;
        *slackware*) dtype=slackware ;;
        *solus*) dtype=solus ;;
      esac
    fi
  fi
  printf '%s\n' "$dtype"
}
DISTRIBUTION="$(distribution)"

# Prefer bat/batcat for cat if present
if command -v bat &>/dev/null || command -v batcat &>/dev/null; then
  case "$DISTRIBUTION" in
    redhat|arch|solus|nixos|void) alias cat='bat' ;;
    *) alias cat='batcat' ;;
  esac
fi

# OS version info
ver() {
  local dtype
  dtype="$(distribution)"
  case "$dtype" in
    redhat)
      if [[ -s /etc/redhat-release ]]; then
        cat /etc/redhat-release
      else
        cat /etc/issue
      fi
      uname -a
      ;;
    suse) cat /etc/SuSE-release ;;
    debian) command -v lsb_release &>/dev/null && lsb_release -a || cat /etc/os-release ;;
    gentoo) cat /etc/gentoo-release ;;
    arch|solus|nixos) cat /etc/os-release ;;
    slackware) cat /etc/slackware-version ;;
    *)
      if [[ -s /etc/issue ]]; then
        cat /etc/issue
      else
        echo "Error: Unknown distribution"
        return 1
      fi
      ;;
  esac
}

# tscp: SCP any file/folder to a host (fzf host picker if no host given)
tscp() {
    local src="$1"
    local host="$2"
    local dest="${3:-~}"
    local default_user="jared"  # change to your normal remote username

    if [[ -z $src ]]; then
        echo "Usage: tscp <file|dir> [host] [destination-path]"
        echo "Example: tscp myfile.txt myhost"
        echo "         tscp myfile.txt user@myhost /var/www/html"
        echo "         tscp myfile.txt   # pick host via fzf"
        return 1
    fi

    # If host not provided, pick from SSH config or Tailscale list
    if [[ -z $host ]]; then
        if command -v fzf &>/dev/null; then
            local ssh_hosts ts_hosts
            ssh_hosts=$(grep -E '^Host ' ~/.ssh/config 2>/dev/null | awk '{print $2}')
            if command -v tailscale &>/dev/null && command -v jq &>/dev/null; then
                ts_hosts=$(tailscale status --json 2>/dev/null | jq -r '.Peer[]?.DNSName' | sed 's/\.$//')
            fi
            host=$(printf "%s\n%s\n" "$ssh_hosts" "$ts_hosts" | sort -u | fzf --prompt="Select host: ")
        else
            echo "Error: fzf not installed and no host provided."
            return 1
        fi
    fi

    [[ -z $host ]] && { echo "No host selected."; return 1; }

    # If host already contains "@", use it as-is, otherwise prepend default user
    if [[ "$host" == *"@"* ]]; then
        remote="$host"
    else
        remote="${default_user}@${host}"
    fi

    # Decide whether to use -r (only for directories)
    local scp_opts=()
    if [[ -d $src ]]; then
        scp_opts+=(-r)
    fi

    scp "${scp_opts[@]}" -- "$src" "${remote}:$dest"
}

# extract archives
extract() {
  local archive
  for archive in "$@"; do
    if [[ -f $archive ]]; then
      case "$archive" in
        *.tar.bz2|*.tbz2) tar xvjf -- "$archive" ;;
        *.tar.gz|*.tgz) tar xvzf -- "$archive" ;;
        *.bz2) bunzip2 -- "$archive" ;;
        *.rar) unrar x -- "$archive" 2>/dev/null || rar x -- "$archive" ;;
        *.gz) gunzip -- "$archive" ;;
        *.tar) tar xvf -- "$archive" ;;
        *.zip) unzip -- "$archive" ;;
        *.Z) uncompress -- "$archive" ;;
        *.7z) 7z x -- "$archive" ;;
        *.tar.xz|*.txz) tar xvJf -- "$archive" ;;
        *.xz) unxz -- "$archive" ;;
        *) echo "Don't know how to extract '$archive'." ;;
      esac
    else
      echo "'$archive' is not a valid file!"
    fi
  done
}

# grep text recursively in current tree
ftext() {
  [[ -n $1 ]] || { echo "Usage: ftext <pattern>"; return 1; }
  grep -iIHrn --color=always -- "$1" . | less -r
}

# copy with progress (requires strace)
cpp() {
  set -e
  local src="$1" dst="$2"
  [[ -n $src && -n $dst ]] || { echo "Usage: cpp <src> <dst>"; return 1; }
  strace -q -ewrite cp -- "$src" "$dst" 2>&1 |
    awk -v total_size="$(stat -c '%s' "$src")" '
      { count += $NF
        if (count % 10 == 0) {
          percent = (count / total_size) * 100
          if (percent > 100) percent = 100
          printf "%3d%% [", percent
          for (i = 0; i <= percent; i++) printf "="
          printf ">"
          for (i = percent; i < 100; i++) printf " "
          printf "]\r"
        }
      }
      END { print "" }'
}

# copy and go
cpg() {
  local src="$1" dst="$2"
  [[ -n $src && -n $dst ]] || { echo "Usage: cpg <src> <dst-dir|file>"; return 1; }
  if [[ -d $dst ]]; then
    cp -- "$src" "$dst" && cd "$dst" || return
  else
    cp -- "$src" "$dst"
  fi
}

# move and go
mvg() {
  local src="$1" dst="$2"
  [[ -n $src && -n $dst ]] || { echo "Usage: mvg <src> <dst-dir|file>"; return 1; }
  if [[ -d $dst ]]; then
    mv -- "$src" "$dst" && cd "$dst" || return
  else
    mv -- "$src" "$dst"
  fi
}

# mkdir and go
mkdirg() {
  [[ -n $1 ]] || { echo "Usage: mkdirg <dir>"; return 1; }
  mkdir -p -- "$1" && cd -- "$1"
}

# up N directories
up() {
  local limit="${1:-1}" d=
  local i
  for ((i = 1; i <= limit; i++)); do
    d="${d}/.."
  done
  d="${d#/}"
  cd "${d:-..}"
}

# cd wrapper: ls after cd
cd() {
  if [ -n $1 ]; then
    builtin cd "$@" && ls
  else
    builtin cd ~ && ls
  fi
}

# tail of PWD
pwdtail() {
  pwd | awk -F/ '{nlast = NF - 1; print $nlast "/" $NF}'
}

# what is my IP
whatsmyip() {
  local dev
  dev="$(ip route 2>/dev/null | awk '/default/ {print $5; exit}')"
  if [[ -n $dev ]]; then
    echo -n "Internal IP: "
    ip -4 -o addr show dev "$dev" 2>/dev/null | awk '{print $4}' | cut -d/ -f1
  else
    echo -n "Internal IP: "
    ip -4 -o addr show 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -n1
  fi

  echo -n "External IP: "
  curl -fsS ifconfig.me || curl -fsS ipinfo.io/ip || echo "N/A"
}
alias whatismyip='whatsmyip'

# trim leading/trailing whitespace
trim() {
  local var="$*"
  var="${var#"${var%%[![:space:]]*}"}"
  var="${var%"${var##*[![:space:]]}"}"
  printf '%s' "$var"
}

# -------------------------------
# Development Tools
# -------------------------------

alias pd='pnpm dev'
alias cr='cargo run'

# -------------------------------
# Git branch shortcut
# -------------------------------

gb() {
    git branch "$@"
}

# Git pull shortcut
gp() {
    git pull "$@"
}

# Delete a branch
gbd() {
    if [ -z "$1" ]; then
        echo "Usage: gbd <branch>"
        return 1
    fi
    git branch -D "$1"
}

# Git add + commit
gcom() {
    if [ -z "$1" ]; then
        echo "Usage: gcom <message>"
        return 1
    fi
    git add .
    git commit -m "$1"
}

# Git add + commit + push
lazyg() {
    if [ -z "$1" ]; then
        echo "Usage: lazyg <message>"
        return 1
    fi
    git add .
    git commit -m "$1"
    git push
}

# Create new branch + commit + push
newb() {
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo "Usage: newb <branch> <message>"
        return 1
    fi

    git checkout -b "$1" || return
    git add .
    git commit -m "$2" || return
    git push -u origin "$1"
}

# Fuzzy branch picker (requires fzf)
gs() {
    branch=$(git branch --all --color=never \
        | sed 's/^[* ]*//' \
        | sort \
        | fzf --prompt="Switch to branch: ")

    if [ -n "$branch" ]; then
        git switch "$branch"
    fi
}

# -------------------------------------------------------------------
# Keybindings and tools
# -------------------------------------------------------------------
bind '"\C-f":"zi\n"'

# starship prompt (defines starship_precmd)
if command -v starship &>/dev/null; then
  eval "$(starship init bash)"
  if declare -F starship_precmd >/dev/null; then
    pc_add 'starship_precmd'
  fi
fi

[ -f ~/.fzf.bash ] && source ~/.fzf.bash

# Initialize zoxide if installed
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init bash)"
fi

# Auto-start X (dwm) on TTY1 if .xinitrc contains 'exec dwm'
if [[ "$(tty)" == "/dev/tty1" ]] && [[ -f "$HOME/.xinitrc" ]] && grep -q "^exec dwm" "$HOME/.xinitrc"; then
  command -v startx &>/dev/null && startx
fi
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
