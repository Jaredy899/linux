#!/usr/bin/env bash
# Functions

distribution() {
  local dtype=unknown
  if [[ -r /etc/os-release ]]; then
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

# Pretty cat with bat if available
catp() {
  if command -v bat &>/dev/null; then
    if [ -t 1 ]; then bat --plain --paging=never "$@"
    else command cat "$@"; fi
  elif command -v batcat &>/dev/null; then
    if [ -t 1 ]; then batcat --plain --paging=never "$@"
    else command cat "$@"; fi
  else
    command cat "$@"
  fi
}

ver() { ... }     # OS version detection (from your config)
tscp() { ... }    # SCP upload function
extract() { ... } # Archive extractor
ftext() { ... }   # Text search
cpp() { ... }     # Copy with live progress
cpg() { ... }     # Copy + cd
mvg() { ... }     # Move + cd
mkdirg() { ... }  # Mkdir + cd
up() { ... }      # "cd .." n times
pwdtail() { pwd | awk -F/ '{nlast=NF-1; print $nlast "/" $NF}' ;}
whatsmyip() { ... } # Internal + external IP function
trim() { local var="$*"; var="${var#"${var%%[![:space:]]*}"}"; var="${var%"${var##*[![:space:]]}"}"; printf '%s' "$var"; }
