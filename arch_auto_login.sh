#!/bin/bash

# Prompt for the username to auto-login with
read -p "Enter the username to configure for auto-login and startx: " USERNAME

# Check if the entered username exists on the system
if ! id "$USERNAME" &>/dev/null; then
    echo "Error: User '$USERNAME' does not exist. Please create the user first."
    exit 1
fi

# Step 1: Configure systemd to auto-login
echo "Configuring systemd to auto-login for user: $USERNAME"

sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
sudo tee /etc/systemd/system/getty@tty1.service.d/override.conf > /dev/null <<EOF
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin $USERNAME --noclear %I \$TERM
EOF

# Step 2: Configure .bash_profile to start X automatically
BASH_PROFILE="/home/$USERNAME/.bash_profile"

echo "Configuring .bash_profile to start X automatically"

# Check if .bash_profile exists, if not, create it
if [ ! -f "$BASH_PROFILE" ]; then
    touch "$BASH_PROFILE"
fi

# Add startx command to .bash_profile if it's not already there
if ! grep -q 'startx' "$BASH_PROFILE"; then
    echo -e "\n# Start X automatically on tty1" >> "$BASH_PROFILE"
    echo "if [[ -z \$DISPLAY ]] && [[ \$(tty) == /dev/tty1 ]]; then" >> "$BASH_PROFILE"
    echo "    startx" >> "$BASH_PROFILE"
    echo "fi" >> "$BASH_PROFILE"
fi

echo "Auto-login and startx configuration complete."

# Inform the user to reboot the system
echo "Please reboot your system to apply the changes."