#!/usr/bin/env bash
# Prompt hooks and auto-ls

__pcd_prev_pwd=""

list_if_cd() {
  if [[ "$PWD" != "$__pcd_prev_pwd" ]]; then
    __pcd_prev_pwd="$PWD"
    ls
  fi
}

pc_add 'list_if_cd'
