#!/bin/bash

set -euo pipefail

BASE_URL="https://raw.githubusercontent.com/Jaredy899/linux/main/config_changes"
MYBASH_DIR="$HOME/.local/share/mybash"
DWM_TITUS_DIR="$HOME/dwm-titus"

# Create directories and download files for mybash
mkdir -p "$MYBASH_DIR"
curl -sSfL -o "$MYBASH_DIR/.bashrc" "$BASE_URL/.bashrc"
curl -sSfL -o "$HOME/.config/fastfetch/config.jsonc" "$BASE_URL/config.jsonc"
curl -sSfL -o "$MYBASH_DIR/starship.toml" "$BASE_URL/starship.toml"

# Create directory and download file for dwm-titus
mkdir -p "$DWM_TITUS_DIR"
curl -sSfL -o "$DWM_TITUS_DIR/config.h" "$BASE_URL/config.h"

# Compile and install dwm-titus if directory exists
if [ -d "$DWM_TITUS_DIR" ]; then
    cd "$DWM_TITUS_DIR" || exit 1
    sudo make clean install
    cd - || exit 1
fi

# Compile and install slstatus if directory exists
SLSTATUS_DIR="$DWM_TITUS_DIR/slstatus"
if [ -d "$SLSTATUS_DIR" ]; then
    cd "$SLSTATUS_DIR" || exit 1
    sudo make clean install
    cd - || exit 1
fi

echo "Configuration replacement completed successfully."