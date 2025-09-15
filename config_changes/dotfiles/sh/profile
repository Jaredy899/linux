#!/usr/bin/env sh
# -------------------------------------------------------------------
# PATH and Environment
# -------------------------------------------------------------------
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export PAGER=less
umask 022

# -------------------------------------------------------------------
# Prompt Setup
# -------------------------------------------------------------------
# Only set PS1 and interactive-only aliases/functions for interactive shells
case $- in
    *i*)
        # If Starship is installed, use it
        if command -v starship >/dev/null 2>&1; then
            PS1='$(starship prompt --status "$?" --path "$PWD")'
        else
            # Fallback to your existing prompt logic
            if [ -n "$BASH_VERSION" ] || [ -n "$BB_ASH_VERSION" ]; then
                PS1='\h:\w\$ '
            else
                if [ -z "$HOSTNAME" ]; then
                    HOSTNAME=$(hostname)
                fi
                # Changed $PWD to \w so it updates dynamically
                PS1="${HOSTNAME%%.*}:\w"
                if [ "$(id -u)" -eq 0 ]; then
                    PS1="${PS1}# "
                else
                    PS1="${PS1}\$ "
                fi
            fi
        fi

        # Interactive-only aliases
        alias sudo="doas"

        # Interactive-only cd override
        cd() {
            if [ -n "$1" ]; then
                command cd "$@" && ls
            else
                command cd ~ && ls
            fi
        }
        ;;
esac

# -------------------------------------------------------------------
# Source /etc/profile.d scripts
# -------------------------------------------------------------------
for script in /etc/profile.d/*.sh ; do
    # shellcheck disable=SC1090
    [ -r "$script" ] && . "$script"
done
unset script

# -------------------------------------------------------------------
# Sudo/Doas Aliases
# -------------------------------------------------------------------
alias reboot="doas reboot"
alias shutdown="doas poweroff"

# -------------------------------------------------------------------
# Editor/Finder Aliases
# -------------------------------------------------------------------
alias nfzf='nano $(fzf -m --preview="bat --color=always {}")'

# -------------------------------------------------------------------
# Directory Navigation
# -------------------------------------------------------------------
alias home='cd ~'
alias cd..='cd ..'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'

# -------------------------------------------------------------------
# Updater Aliases
# -------------------------------------------------------------------
alias update='curl https://raw.githubusercontent.com/Jaredy899/linux/refs/heads/main/installs/updater.sh | sh'
alias jc='sh <(curl -fsSL jaredcervantes.com/linux)'
alias os='sh <(curl -fsSL jaredcervantes.com/os)'

# -------------------------------------------------------------------
# LS/EZA Family
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
    alias lf='eza -l --icons --group-directories-first | grep -v "^d"'
    alias ldir='eza -l --icons --group-directories-first | grep "^d"'
    alias lg='eza -l --git --icons --group-directories-first'
    alias tree='eza -T --icons --group-directories-first'
    alias treed='eza -T -D --icons --group-directories-first'
else
    alias ls='ls -aFh --color=always'
    alias la='ls -Alh'
    alias ll='ls -Fls'
    alias lla='ls -Al'
    alias las='ls -A'
    alias lw='ls -xAh'
    alias lr='ls -lRh'
    alias lt='ls -ltrh'
    alias lk='ls -lSrh'
    alias lx='ls -lXBh'
    alias lc='ls -ltcrh'
    alias lu='ls -lturh'
    alias lm='ls -alh | more'
    alias labc='ls -lap'
    alias lf="ls -l | grep -v '^d'"
    alias ldir="ls -l | grep '^d'"
    alias lls='ls -l'
    alias tree='tree -CAhF --dirsfirst'
    alias treed='tree -CAFd'
fi

# -------------------------------------------------------------------
# File/Folder Management
# -------------------------------------------------------------------
alias rmd='/bin/rm -rfv'

# -------------------------------------------------------------------
# Chmod Helpers
# -------------------------------------------------------------------
alias mx='doas chmod a+x'
alias 000='doas chmod -R 000'
alias 644='doas chmod -R 644'
alias 666='doas chmod -R 666'
alias 755='doas chmod -R 755'
alias 777='doas chmod -R 777'

# -------------------------------------------------------------------
# Search Helpers
# -------------------------------------------------------------------
alias h="history | grep -- "
alias p="ps aux | grep -- "
alias topcpu="/bin/ps -eo pcpu,pid,user,args | sort -k1 -r | head -10"
alias f="find . | grep -- "
# shellcheck disable=SC2154
alias countfiles='for t in files links directories; do echo "$(find . -type ${t%?} 2>/dev/null | wc -l)" "$t"; done'

# -------------------------------------------------------------------
# Networking and Disk
# -------------------------------------------------------------------
alias openports='netstat -nape --inet'
alias diskspace="du -S | sort -n -r | more"
alias folders='du -h --max-depth=1'
alias folderssort='find . -maxdepth 1 -type d -print0 | xargs -0 du -sk | sort -rn'
alias mountedinfo='df -hT'

# -------------------------------------------------------------------
# Archives
# -------------------------------------------------------------------
alias mktar='tar -cvf'
alias mkbz2='tar -cvjf'
alias mkgz='tar -cvzf'
alias untar='tar -xvf'
alias unbz2='tar -xvjf'
alias ungz='tar -xvzf'

# -------------------------------------------------------------------
# Functions
# -------------------------------------------------------------------

if command -v bat >/dev/null 2>&1; then
    alias cat='bat'
fi

ver() {
    cat /etc/alpine-release
    cat /etc/os-release
    uname -a
}

tscp() {
    src="$1"
    host="$2"
    dest="${3:-~}"
    user="$USER"

    if [ -z "$src" ]; then
        echo "Usage: tscp <file|dir> [host] [destination-path]"
        return 1
    fi

    if [ -z "$host" ]; then
        if command -v fzf >/dev/null 2>&1; then
            ssh_hosts=$(grep -E '^Host ' ~/.ssh/config 2>/dev/null | awk '{print $2}')
            ts_hosts=""
            if command -v tailscale >/dev/null 2>&1; then
                ts_hosts=$(tailscale status --json 2>/dev/null | jq -r '.Peer[]?.DNSName' | sed 's/\.$//')
            fi
            host=$(printf "%s\n%s\n" "$ssh_hosts" "$ts_hosts" | sort -u | fzf --prompt="Select host: ")
        else
            echo "Error: fzf not installed and no host provided."
            return 1
        fi
    fi

    [ -z "$host" ] && { echo "No host selected."; return 1; }

    scp_opts=""
    if [ -d "$src" ]; then
        scp_opts="-r"
    fi

    scp $scp_opts -- "$src" "${user}@${host}:$dest"
}

extract() {
    for archive in "$@"; do
        if [ -f "$archive" ]; then
            case "$archive" in
                *.tar.bz2|*.tbz2) tar xvjf "$archive" ;;
                *.tar.gz|*.tgz) tar xvzf "$archive" ;;
                *.bz2) bunzip2 "$archive" ;;
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

ftext() {
    if [ -z "$1" ]; then
        echo "Usage: ftext <pattern>"
        return 1
    fi
    grep -iIHrn --color=always -- "$1" . | less -R
}

cpp() {
    if ! command -v strace >/dev/null 2>&1; then
        echo "strace required"
        return 1
    fi
    src="$1"
    dst="$2"
    if [ -z "$src" ] || [ -z "$dst" ]; then
        echo "Usage: cpp <src> <dst>"
        return 1
    fi
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

cpg() {
    src="$1"
    dst="$2"
    if [ -z "$src" ] || [ -z "$dst" ]; then
        echo "Usage: cpg <src> <dst-dir|file>"
        return 1
    fi
    if [ -d "$dst" ]; then
        cp -- "$src" "$dst" && cd "$dst" || return
    else
        cp -- "$src" "$dst"
    fi
}

mvg() {
    src="$1"
    dst="$2"
    if [ -z "$src" ] || [ -z "$dst" ]; then
        echo "Usage: mvg <src> <dst-dir|file>"
        return 1
    fi
    if [ -d "$dst" ]; then
        mv -- "$src" "$dst" && cd "$dst" || return
    else
        mv -- "$src" "$dst"
    fi
}

mkdirg() {
    if [ -z "$1" ]; then
        echo "Usage: mkdirg <dir>"
        return 1
    fi
    mkdir -p -- "$1" && cd -- "$1" || return
}

up() {
    limit="${1:-1}"
    d=""
    i=1
    while [ "$i" -le "$limit" ]; do
        d="${d}/.."
        i=$((i + 1))
    done
    d="${d#/}"
    cd "${d:-..}" || return
}

pwdtail() {
    pwd | awk -F/ '{nlast = NF - 1; print $nlast "/" $NF}'
}

whatsmyip() {
    dev=$(ip route 2>/dev/null | awk '/default/ {print $5; exit}')
    if [ -n "$dev" ]; then
        printf "Internal IP: "
        ip -4 -o addr show dev "$dev" 2>/dev/null | awk '{print $4}' | cut -d/ -f1
    else
        printf "Internal IP: "
        ip -4 -o addr show 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -n1
    fi
    printf "External IP: "
    curl -fsS ifconfig.me || curl -fsS ipinfo.io/ip || printf "N/A\n"
}
alias whatismyip='whatsmyip'

trim() {
    var="$*"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    printf '%s' "$var"
}

# Git helpers
gb() { git branch "$@"; }
gp() { git pull "$@"; }
gbd() { [ -z "$1" ] && { echo "Usage: gbd <branch>"; return 1; } && git branch -D "$1"; }
gcom() { [ -z "$1" ] && { echo "Usage: gcom <message>"; return 1; } && git add . && git commit -m "$1"; }
lazyg() { [ -z "$1" ] && { echo "Usage: lazyg <message>"; return 1; } && git add . && git commit -m "$1" && git push; }
newb() { [ -z "$1" ] || [ -z "$2" ] && { echo "Usage: newb <branch> <message>"; return 1; } && git checkout -b "$1" && git add . && git commit -m "$2" && git push -u origin "$1"; }
gs() { branch=$(git branch --all --color=never | sed 's/^[* ]*//' | sort | fzf --prompt="Switch to branch: "); [ -n "$branch" ] && git switch "$branch"; }

# -------------------------------------------------------------------
# Fastfetch and Zoxide
# -------------------------------------------------------------------
if command -v fastfetch >/dev/null 2>&1; then
    fastfetch
fi
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init posix --hook prompt)"
fi

# -------------------------------------------------------------------
# Auto-start X (dwm) on TTY1
# -------------------------------------------------------------------
if [ "$(tty)" = "/dev/tty1" ] && [ -f "$HOME/.xinitrc" ] && grep -q "^exec dwm" "$HOME/.xinitrc"; then
    command -v startx >/dev/null 2>&1 && startx
fi
