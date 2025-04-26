#!/bin/sh -e

eval "$(curl -s https://raw.githubusercontent.com/Jaredy899/linux/refs/heads/main/common_script.sh)"
eval "$(curl -s https://raw.githubusercontent.com/Jaredy899/linux/refs/heads/main/common_service_script.sh)"

checkEnv || exit 1

BASE_URL="https://raw.githubusercontent.com/Jaredy899/linux/main/config_changes"
MYBASH_DIR="$HOME/.local/share/mybash"

replace_configs() {
    printf "%b\n" "${YELLOW}Downloading and replacing configurations...${RC}"

    mkdir -p "$MYBASH_DIR"
    mkdir -p "$HOME/.config/fastfetch"
    mkdir -p "$HOME/.config"

    if [ -f /etc/alpine-release ]; then
        "$ESCALATION_TOOL" curl -sSfL -o "/etc/profile" "$BASE_URL/profile"
        "$ESCALATION_TOOL" apk add zoxide
    elif [ "$DTYPE" = "solus" ]; then
        # Download Solus-specific .profile configuration
        curl -sSfL -o "$HOME/.profile" "$BASE_URL/.profile"
        curl -sSfL -o "$MYBASH_DIR/.bashrc" "$BASE_URL/.bashrc"
    else
        curl -sSfL -o "$MYBASH_DIR/.bashrc" "$BASE_URL/.bashrc"
    fi

    curl -sSfL -o "$HOME/.config/fastfetch/config.jsonc" "$BASE_URL/config.jsonc"
    curl -sSfL -o "$HOME/.config/starship.toml" "$BASE_URL/starship.toml"

    printf "%b\n" "${GREEN}Configurations downloaded and replaced successfully.${RC}"
}


replace_configs

printf "%b\n" "${GREEN}Configuration replacement completed successfully.${RC}"
