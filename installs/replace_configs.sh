#!/bin/sh -e

# Source the common script directly from GitHub
. <(curl -s https://raw.githubusercontent.com/Jaredy899/linux/refs/heads/main/common_script.sh)

# Run the environment check
checkEnv || exit 1

BASE_URL="https://raw.githubusercontent.com/Jaredy899/linux/main/config_changes"
MYBASH_DIR="$HOME/.local/share/mybash"
DWM_TITUS_DIR="$HOME/dwm-titus"

# Function to download and replace configurations
replace_configs() {
    printf "%b\n" "${YELLOW}Downloading and replacing configurations...${RC}"

    # Create directories and download files for mybash
    mkdir -p "$MYBASH_DIR"
    mkdir -p "$HOME/.config/fastfetch"
    mkdir -p "$HOME/.config"
    curl -sSfL -o "$MYBASH_DIR/.bashrc" "$BASE_URL/.bashrc"
    curl -sSfL -o "$HOME/.config/fastfetch/config.jsonc" "$BASE_URL/config.jsonc"
    curl -sSfL -o "$HOME/.config/starship.toml" "$BASE_URL/starship.toml"

    # Create directory and download file for dwm-titus
    mkdir -p "$DWM_TITUS_DIR"
    curl -sSfL -o "$DWM_TITUS_DIR/config.h" "$BASE_URL/config.h"

    printf "%b\n" "${GREEN}Configurations downloaded and replaced successfully.${RC}"
}

# First check if dwm-titus directory exists
if [ ! -d "$DWM_TITUS_DIR" ]; then
    printf "%b\n" "${YELLOW}dwm-titus directory not found. Skipping DWM and slstatus compilation.${RC}"
    exit 0  # or exit 0 depending on how this script is used
fi

# Function to compile and install dwm-titus
compile_install_dwm_titus() {
    printf "%b\n" "${YELLOW}Compiling and installing dwm-titus...${RC}"
    cd "$DWM_TITUS_DIR" || exit 1
    "$ESCALATION_TOOL" make clean install
    cd - || exit 1
    printf "%b\n" "${GREEN}dwm-titus compiled and installed successfully.${RC}"
}

# Function to compile and install slstatus
compile_install_slstatus() {
    SLSTATUS_DIR="$DWM_TITUS_DIR/slstatus"
    if [ -d "$SLSTATUS_DIR" ]; then
        printf "%b\n" "${YELLOW}Compiling and installing slstatus...${RC}"
        cd "$SLSTATUS_DIR" || exit 1
        "$ESCALATION_TOOL" make clean install
        cd - || exit 1
        printf "%b\n" "${GREEN}slstatus compiled and installed successfully.${RC}"
    else
        printf "%b\n" "${YELLOW}slstatus directory not found. Skipping compilation.${RC}"
    fi
}

# Main script
replace_configs
compile_install_dwm_titus
compile_install_slstatus

printf "%b\n" "${GREEN}Configuration replacement and compilation completed successfully.${RC}"
