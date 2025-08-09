# -------------------------------------------------------------------
# Minimal work before prompt
# -------------------------------------------------------------------
if command -v fastfetch >/dev/null 2>&1; then
  fastfetch
fi

# -------------------------------------------------------------------
# Zsh plugin manager (zinit)
# -------------------------------------------------------------------
if [[ ! -f ~/.zinit/bin/zinit.zsh ]]; then
  mkdir -p ~/.zinit
  git clone https://github.com/zdharma-continuum/zinit.git ~/.zinit/bin
fi
source ~/.zinit/bin/zinit.zsh

# -------------------------------------------------------------------
# Plugins
# -------------------------------------------------------------------
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-autosuggestions
zinit light zsh-users/zsh-history-substring-search

# -------------------------------------------------------------------
# Completion system
# -------------------------------------------------------------------
autoload -Uz compinit && compinit
setopt NO_FLOW_CONTROL
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
setopt COMPLETE_IN_WORD
setopt LIST_AMBIGUOUS
zstyle ':completion:*:descriptions' format '%F{yellow}-- %d --%f'
zstyle ':completion:*:messages' format '%F{purple}-- %d --%f'
zstyle ':completion:*:warnings' format '%F{red}-- no match for: %d --%f'
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}

# -------------------------------------------------------------------
# History
# -------------------------------------------------------------------
HISTFILE="$HOME/.zsh_history"
HISTSIZE=500
SAVEHIST=10000
setopt APPEND_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_FIND_NO_DUPS
HIST_STAMPS="yyyy-mm-dd"

# Run before each prompt
precmd() { history -a }

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
if command -v nvim >/dev/null 2>&1; then
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

if command -v rg >/dev/null 2>&1; then
  alias grep='rg'
else
  alias grep='grep --color=auto'
fi

# -------------------------------------------------------------------
# Safer core command aliases
# -------------------------------------------------------------------
alias cp='cp -i'
alias mv='mv -i'
if command -v trash >/dev/null 2>&1; then
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
alias ff='fastfetch -c all'
alias jc='sh <(curl -fsSL jaredcervantes.com/linux)'
alias nfzf='nano "$(fzf -m --preview="bat --color=always {}")"'
alias update='curl -fsSL https://raw.githubusercontent.com/Jaredy899/linux/refs/heads/main/installs/updater.sh | sh'
alias convert='heif-convert'
alias rebuild='sudo nixos-rebuild switch'
alias web='cd /var/www/html'
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history | tail -n1 | sed -e "s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//")"'
alias ebrc='${EDITOR:-nano} ~/.zshrc'
alias hlp='less ~/.bashrc_help'
alias da='date "+%Y-%m-%d %A %T %Z"'
alias sha1='openssl sha1'
alias clickpaste='sleep 3; xdotool type "$(xclip -o -selection clipboard)"'

# -------------------------------------------------------------------
# ls family: prefer eza if available
# -------------------------------------------------------------------
if command -v eza >/dev/null 2>&1; then
  alias ls='eza -a --icons --group-directories-first'
  alias la='eza -Alh --icons --group-directories-first'
  alias ll='eza -l --icons --group-directories-first'
  alias lla='eza -Al --icons --group-directories-first'
  alias las='eza -A --icons --group-directories-first'
  alias lw='eza -a1 --icons'
  alias lr='eza -lR --icons --group-directories-first'
  alias lt='eza -ltrh --icons --group-directories-first'
  alias lk='eza -lSrh --icons --group-directories-first'
  alias lx='eza -lXBh --icons --group-directories-first'
  alias lc='eza -ltcrh --icons --group-directories-first'
  alias lu='eza -lturh --icons --group-directories-first'
  alias lm='eza -alh --icons | more'
  alias labc='eza -lap --icons --group-directories-first'
  alias lf='eza -l --icons --group-directories-first | egrep -v "^d"'
  alias ldir='eza -l --icons --group-directories-first | egrep "^d"'
  alias lg='eza -l --git --icons --group-directories-first'
  alias tree='eza -T --icons --group-directories-first'
  alias treed='eza -T -D --icons --group-directories-first'
else
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

# -------------------------------------------------------------------
# Functions (all from your Bash version, unchanged except PROMPT_COMMAND logic)
# -------------------------------------------------------------------
distribution() {
  local dtype=unknown
  if [ -r /etc/os-release ]; then
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
    esac
  fi
  printf '%s\n' "$dtype"
}

# Prefer bat/batcat for cat if present
if command -v bat >/dev/null 2>&1 || command -v batcat >/dev/null 2>&1; then
  case "$(distribution)" in
    redhat|arch|solus|nixos|void) alias cat='bat' ;;
    *) alias cat='batcat' ;;
  esac
fi

ver() {
  case "$(distribution)" in
    redhat) cat /etc/redhat-release ;;
    suse) cat /etc/SuSE-release ;;
    debian) lsb_release -a 2>/dev/null || cat /etc/os-release ;;
    arch|solus|nixos) cat /etc/os-release ;;
    *) cat /etc/issue ;;
  esac
}

tscp() {
  local src="$1" host="$2" dest="${3:-~}" default_user="jared"
  if [ -z "$src" ]; then
    echo "Usage: tscp <file|dir> [host] [destination-path]"
    return 1
  fi
  if [ -z "$host" ] && command -v fzf >/dev/null 2>&1; then
    local ssh_hosts ts_hosts
    ssh_hosts=$(grep -E '^Host ' ~/.ssh/config 2>/dev/null | awk '{print $2}')
    if command -v tailscale >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
      ts_hosts=$(tailscale status --json | jq -r '.Peer[]?.DNSName' | sed 's/\.$//')
    fi
    host=$(printf "%s\n%s\n" "$ssh_hosts" "$ts_hosts" | sort -u | fzf --prompt="Select host: ")
  fi
  [ -z "$host" ] && { echo "No host selected."; return 1; }
  [[ "$host" == *"@"* ]] && remote="$host" || remote="${default_user}@${host}"
  local scp_opts=()
  [ -d "$src" ] && scp_opts+=(-r)
  scp "${scp_opts[@]}" -- "$src" "${remote}:$dest"
}

extract() {
  for archive in "$@"; do
    if [ -f "$archive" ]; then
      case "$archive" in
        *.tar.bz2|*.tbz2) tar xvjf "$archive" ;;
        *.tar.gz|*.tgz) tar xvzf "$archive" ;;
        *.bz2) bunzip2 "$archive" ;;
        *.rar) unrar x "$archive" 2>/dev/null || rar x "$archive" ;;
        *.gz) gunzip "$archive" ;;
        *.tar) tar xvf "$archive" ;;
        *.zip) unzip "$archive" ;;
        *.Z) uncompress "$archive" ;;
        *.7z) 7z x "$archive" ;;
        *.tar.xz|*.txz) tar xvJf "$archive" ;;
        *.xz) unxz "$archive" ;;
        *) echo "Don't know how to extract '$archive'." ;;
      esac
    else
      echo "'$archive' is not a valid file!"
    fi
  done
}

ftext() { [ -n "$1" ] || { echo "Usage: ftext <pattern>"; return 1; }; grep -iIHrn --color=always -- "$1" . | less -r; }
cpp() { set -e; local src="$1" dst="$2"; [ -n "$src" ] && [ -n "$dst" ] || { echo "Usage: cpp <src> <dst>"; return 1; }; strace -q -ewrite cp -- "$src" "$dst" 2>&1 | awk -v total_size="$(stat -c '%s' "$src")" '{ count += $NF; if (count % 10 == 0) { percent = (count / total_size) * 100; if (percent > 100) percent = 100; printf "%3d%% [", percent; for (i = 0; i <= percent; i++) printf "="; printf ">"; for (i = percent; i < 100; i++) printf " "; printf "]\r" } } END { print "" }'; }
cpg() { cp -- "$1" "$2" && [ -d "$2" ] && cd "$2"; }
mvg() { mv -- "$1" "$2" && [ -d "$2" ] && cd "$2"; }
mkdirg() { mkdir -p -- "$1" && cd "$1"; }
up() { cd $(printf "%0.s../" $(seq 1 ${1:-1})); }
pwdtail() { pwd | awk -F/ '{nlast = NF - 1; print $nlast "/" $NF}'; }
whatsmyip() { local dev; dev="$(ip route 2>/dev/null | awk '/default/ {print $5; exit}')"; echo -n "Internal IP: "; if [ -n "$dev" ]; then ip -4 -o addr show dev "$dev" | awk '{print $4}' | cut -d/ -f1; else ip -4 -o addr show | awk '{print $4}' | cut -d/ -f1 | head -n1; fi; echo -n "External IP: "; curl -fsS ifconfig.me || curl -fsS ipinfo.io/ip || echo "N/A"; }
alias whatismyip='whatsmyip'
trim() { printf '%s' "${*#"${*%%[![:space:]]*}"}" | sed 's/[[:space:]]*$//'; }

# Git helpers
gb() { git branch "$@"; }
gp() { git pull "$@"; }
gbd() { git branch -D "$1"; }
gcom() { git add . && git commit -m "$1"; }
lazyg() { git add . && git commit -m "$1" && git push; }
newb() { git checkout -b "$1" && git add . && git commit -m "$2" && git push -u origin "$1"; }
gs() { git branch --all | sed 's/^[* ]*//' | sort | fzf --prompt="Switch to branch: " | xargs git switch; }

# -------------------------------------------------------------------
# Keybindings
# -------------------------------------------------------------------
bindkey '^ ' autosuggest-accept          # Ctrl+Space accepts suggestion
bindkey '^[[A' history-substring-search-up   # Up arrow
bindkey '^[[B' history-substring-search-down # Down arrow
bindkey '^R' fzf-history-widget           # Ctrl+R for FZF history
bindkey '^T' fzf-file-widget              # Ctrl+T for FZF file search
bindkey '^G' fzf-cd-widget                # Ctrl+G for FZF cd

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# -------------------------------------------------------------------
# Starship prompt
# -------------------------------------------------------------------
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

# Initialize zoxide if installed
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi.
