#!/usr/bin/env bash
# PATH management

path_add() {
  case ":$PATH:" in
  *":$1:"*) ;; # already present
  *) PATH="${PATH:+"$PATH:"}$1" ;;
  esac
}

path_add "$HOME/.local/bin"
path_add "$HOME/.cargo/bin"
path_add "/var/lib/flatpak/exports/bin"
path_add "$HOME/.local/share/flatpak/exports/bin"

export PATH
