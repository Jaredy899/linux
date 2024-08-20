#!/bin/bash

# Check if zsh is being used
if [ -n "$ZSH_VERSION" ]; then
  echo "Detected zsh. Using zsh for script execution."
  exec zsh "$0" "$@"
  exit
fi

# Variables
SSH_DIR="$HOME/.ssh"
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"

# Ensure the .ssh directory exists
if [ ! -d "$SSH_DIR" ]; then
  mkdir -p "$SSH_DIR"
  chmod 700 "$SSH_DIR"
  echo "Created $SSH_DIR and set permissions to 700."
else
  echo "$SSH_DIR already exists."
fi

# Ensure the authorized_keys file exists
if [ ! -f "$AUTHORIZED_KEYS" ]; then
  touch "$AUTHORIZED_KEYS"
  chmod 600 "$AUTHORIZED_KEYS"
  echo "Created $AUTHORIZED_KEYS and set permissions to 600."
else
  echo "$AUTHORIZED_KEYS already exists."
fi

# Add the public key to the authorized_keys file if not already added
read -p "Enter the public key to add: " PUBLIC_KEY

if grep -q "$PUBLIC_KEY" "$AUTHORIZED_KEYS"; then
  echo "Public key already exists in $AUTHORIZED_KEYS."
else
  echo "$PUBLIC_KEY" >> "$AUTHORIZED_KEYS"
  echo "Public key added to $AUTHORIZED_KEYS."
fi

echo "Done."
