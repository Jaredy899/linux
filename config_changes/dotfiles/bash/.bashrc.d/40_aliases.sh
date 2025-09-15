#!/usr/bin/env bash
# All command aliases

# Safer core commands
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

# ls family
if command -v eza &>/dev/null; then
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

# Remove a directory and all files
alias rmd='sudo /bin/rm --recursive --force --verbose '

# chmod helpers
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
# shellcheck disable=SC2154
alias countfiles='for t in files links directories; do echo "$(find . -type ${t:0:1} 2>/dev/null | wc -l)" "$t"; done'

# Networking & disks
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

# cd shortcuts
alias home='cd ~'
alias cd..='cd ..'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias whatismyip='whatsmyip'
