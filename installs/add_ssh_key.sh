#!/bin/sh -e

# Fetch and source the common_script.sh from GitHub
eval "$(curl -fsSL https://raw.githubusercontent.com/Jaredy899/linux/refs/heads/dev/common_script.sh)"

# Check environment
checkEnv

# Variables
SSH_DIR="$HOME/.ssh"
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"

ensure_ssh_directory() {
    if [ ! -d "$SSH_DIR" ]; then
        mkdir -p "$SSH_DIR"
        chmod 700 "$SSH_DIR"
        printf "%b\n" "${GREEN}Created $SSH_DIR and set permissions to 700.${RC}"
    else
        printf "%b\n" "${CYAN}$SSH_DIR already exists.${RC}"
    fi
}

ensure_authorized_keys() {
    if [ ! -f "$AUTHORIZED_KEYS" ]; then
        touch "$AUTHORIZED_KEYS"
        chmod 600 "$AUTHORIZED_KEYS"
        printf "%b\n" "${GREEN}Created $AUTHORIZED_KEYS and set permissions to 600.${RC}"
    else
        printf "%b\n" "${CYAN}$AUTHORIZED_KEYS already exists.${RC}"
    fi
}

import_ssh_keys() {
    printf "Enter the GitHub username: "
    read github_user

    # Fetch the SSH keys from the GitHub user's profile
    ssh_keys_url="https://github.com/$github_user.keys"
    keys=$(curl -s "$ssh_keys_url")

    if [ -z "$keys" ]; then
        printf "%b\n" "${RED}No SSH keys found for GitHub user: $github_user${RC}"
    else
        printf "%b\n" "${GREEN}SSH keys found! Appending to $AUTHORIZED_KEYS.${RC}"

        # Append the keys to the authorized_keys file
        printf "%s\n" "$keys" >> "$AUTHORIZED_KEYS"
        chmod 600 "$AUTHORIZED_KEYS"

        printf "%b\n" "${GREEN}SSH keys imported successfully!${RC}"
    fi
}

add_public_key() {
    printf "Enter the public key to add: "
    read PUBLIC_KEY

    if grep -q "$PUBLIC_KEY" "$AUTHORIZED_KEYS"; then
        printf "%b\n" "${YELLOW}Public key already exists in $AUTHORIZED_KEYS.${RC}"
    else
        printf "%s\n" "$PUBLIC_KEY" >> "$AUTHORIZED_KEYS"
        chmod 600 "$AUTHORIZED_KEYS"
        printf "%b\n" "${GREEN}Public key added to $AUTHORIZED_KEYS.${RC}"
    fi
}

# Main script
ensure_ssh_directory
ensure_authorized_keys

printf "Do you want to import SSH keys from GitHub or enter your own?\n"
printf "1) Import from GitHub\n"
printf "2) Enter your own public key\n"
printf "Choose an option [1/2]: "
read choice

case "$choice" in
    1)
        import_ssh_keys
        ;;
    2)
        add_public_key
        ;;
    *)
        printf "%b\n" "${RED}Invalid option. Exiting.${RC}"
        exit 1
        ;;
esac

printf "%b\n" "${GREEN}Done.${RC}"
