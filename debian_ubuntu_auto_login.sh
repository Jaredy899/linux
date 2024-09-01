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
ExecStart=-/sbin/agetty --autologin $USERNAME --noclear %I \$TERM
Type=simple
Restart=always
EOF

# Reload systemd to apply changes
sudo systemctl daemon-reload

# Enable getty@tty1 service to ensure it starts at boot
sudo systemctl enable getty@tty1.service

# Step 2: Configure .bash_profile or .profile to start X automatically
BASH_PROFILE="/home/$USERNAME/.bash_profile"
PROFILE="/home/$USERNAME/.profile"

echo "Configuring $BASH_PROFILE or $PROFILE to start X automatically"

# Choose .bash_profile if it exists, otherwise use .profile
if [ ! -f "$BASH_PROFILE" ] && [ -f "$PROFILE" ]; then
    BASH_PROFILE=$PROFILE
elif [ ! -f "$BASH_PROFILE" ]; then
    sudo -u "$USERNAME" touch "$BASH_PROFILE"
fi

# Add startx command to .bash_profile or .profile if it's not already there
if ! sudo -u "$USERNAME" grep -q 'startx' "$BASH_PROFILE"; then
    sudo -u "$USERNAME" bash -c "echo -e '\n# Start X automatically on tty1' >> $BASH_PROFILE"
    sudo -u "$USERNAME" bash -c "echo 'if [[ -z \$DISPLAY ]] && [[ \$(tty) == /dev/tty1 ]]; then' >> $BASH_PROFILE"
    sudo -u "$USERNAME" bash -c "echo '    startx' >> $BASH_PROFILE"
    sudo -u "$USERNAME" bash -c "echo 'fi' >> $BASH_PROFILE"
fi

# Ensure the correct ownership and permissions are set
sudo chown "$USERNAME:$USERNAME" "$BASH_PROFILE"

echo "Auto-login and startx configuration complete."

# Inform the user to reboot the system
echo "Please reboot your system to apply the changes."