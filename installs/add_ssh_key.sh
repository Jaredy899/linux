#!/bin/sh -e

# Source the common script directly from GitHub
. <(curl -s https://raw.githubusercontent.com/Jaredy899/linux/refs/heads/main/common_script.sh)
. <(curl -s https://raw.githubusercontent.com/Jaredy899/linux/refs/heads/main/common_service_script.sh)
# Run the environment check
checkEnv || exit 1

# Variables
SSH_DIR="$HOME/.ssh"
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"

# Function to ensure directory and file exist with correct permissions
ensure_ssh_setup() {
    if [ ! -d "$SSH_DIR" ]; then
        mkdir -p "$SSH_DIR"
        chmod 700 "$SSH_DIR"
        printf "%b\n" "${GREEN}Created $SSH_DIR and set permissions to 700.${RC}"
    else
        printf "%b\n" "${YELLOW}$SSH_DIR already exists.${RC}"
    fi

    if [ ! -f "$AUTHORIZED_KEYS" ]; then
        touch "$AUTHORIZED_KEYS"
        chmod 600 "$AUTHORIZED_KEYS"
        printf "%b\n" "${GREEN}Created $AUTHORIZED_KEYS and set permissions to 600.${RC}"
    else
        printf "%b\n" "${YELLOW}$AUTHORIZED_KEYS already exists.${RC}"
    fi
}

# Function to import SSH keys from GitHub
import_ssh_keys() {
    printf "%b" "${CYAN}Enter the GitHub username: ${RC}"
    read -r github_user

    ssh_keys_url="https://github.com/$github_user.keys"
    keys=$(curl -s "$ssh_keys_url")

    if [ -z "$keys" ]; then
        printf "%b\n" "${RED}No SSH keys found for GitHub user: $github_user${RC}"
    else
        printf "%b\n" "${GREEN}SSH keys found for $github_user:${RC}"
        printf "%s\n" "$keys"
        printf "%b" "${CYAN}Do you want to import these keys? [Y/n]: ${RC}"
        read -r confirm

        case "$confirm" in
            [Nn]*)
                printf "%b\n" "${YELLOW}SSH key import cancelled.${RC}"
                ;;
            *)
                printf "%s\n" "$keys" >> "$AUTHORIZED_KEYS"
                chmod 600 "$AUTHORIZED_KEYS"
                printf "%b\n" "${GREEN}SSH keys imported successfully!${RC}"
                ;;
        esac
    fi
}

# Function to add a manually entered public key
add_manual_key() {
    printf "%b" "${CYAN}Enter the public key to add: ${RC}"
    read -r PUBLIC_KEY

    if grep -q "$PUBLIC_KEY" "$AUTHORIZED_KEYS"; then
        printf "%b\n" "${YELLOW}Public key already exists in $AUTHORIZED_KEYS.${RC}"
    else
        printf "%s\n" "$PUBLIC_KEY" >> "$AUTHORIZED_KEYS"
        chmod 600 "$AUTHORIZED_KEYS"
        printf "%b\n" "${GREEN}Public key added to $AUTHORIZED_KEYS.${RC}"
    fi
}

# Main script
ensure_ssh_setup

printf "%b\n" "${CYAN}Do you want to import SSH keys from GitHub or enter your own?${RC}"
printf "%b\n" "${CYAN}1) Import from GitHub${RC}"
printf "%b\n" "${CYAN}2) Enter your own public key${RC}"
printf "%b" "${CYAN}Choose an option [1/2]: ${RC}"
read -r choice

case "$choice" in
    1)
        import_ssh_keys
        ;;
    2)
        add_manual_key
        ;;
    *)
        printf "%b\n" "${RED}Invalid option. Exiting.${RC}"
        exit 1
        ;;
esac

printf "%b\n" "${GREEN}Done.${RC}"
