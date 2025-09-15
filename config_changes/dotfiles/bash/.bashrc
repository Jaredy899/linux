#!/usr/bin/env bash
# ~/.bashrc -- bootstrapper for modular dotfiles

# Source system-wide bashrc if available
# shellcheck disable=SC1091
[[ -r /etc/bashrc ]] && . /etc/bashrc

# Path to dotfiles repo
DOTFILES="$HOME/dotfiles"

# Load modular bashrc fragments
if [[ -d "$DOTFILES/bash/.bashrc.d" ]]; then
  for rc in "$DOTFILES/bash/.bashrc.d/"*.sh; do
    # shellcheck disable=SC1090
    [ -r "$rc" ] && . "$rc"
  done
  unset rc
fi