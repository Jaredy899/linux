#!/bin/bash

# Function to check if a package is installed
check_package() {
    if ! dpkg -l | grep -q "$1"; then
        echo "$1 is not installed. Installing $1..."
        sudo apt-get update
        sudo apt-get install -y "$1"
    else
        echo "$1 is already installed."
    fi
}

# Ensure cifs-utils is installed
check_package cifs-utils

# Prompt the user for the remote mount location
read -p "Enter the remote mount location (e.g., //192.168.1.1/Files): " remote_mount

# Ask if the user wants to use the default mount directory
read -p "Do you want to use the default local mount directory (/srv/remotemount)? (y/n): " use_default

if [[ "$use_default" =~ ^[Yy]$ ]]; then
    # Prompt for the mount name
    read -p "Enter the name for the mount directory (e.g., nas): " mount_name
    local_mount="/srv/remotemount/$mount_name"
else
    # Prompt for the full custom local mount directory
    read -p "Enter the full path for the local mount directory: " local_mount
fi

# Prompt the user for the username
read -p "Enter the username for the remote mount: " username

# Prompt the user for the password (input will be hidden)
read -s -p "Enter the password for the remote mount: " password
echo # To move to the next line after password input

# Create a credentials file in a secure location
credentials_file="/etc/cifs-credentials-$mount_name"

# Write the credentials to the file
echo "username=$username" | sudo tee "$credentials_file" > /dev/null
echo "password=$password" | sudo tee -a "$credentials_file" > /dev/null

# Set permissions to restrict access to the credentials file
sudo chmod 600 "$credentials_file"

# Construct the new entry using the credentials file
new_entry="$remote_mount $local_mount cifs credentials=$credentials_file 0 0"

# Check if the mount directory exists, and create it if it doesn't
if [ ! -d "$local_mount" ]; then
    sudo mkdir -p "$local_mount"
    echo "Created mount directory $local_mount"
fi

# Check if the line already exists in /etc/fstab
if grep -Fxq "$new_entry" /etc/fstab
then
    echo "The entry already exists in /etc/fstab"
else
    # Add the new entry to the end of /etc/fstab
    echo "$new_entry" | sudo tee -a /etc/fstab > /dev/null
    echo "The entry has been added to /etc/fstab"
fi

# Reload the systemd daemon to recognize the changes in /etc/fstab
sudo systemctl daemon-reload
echo "Systemd daemon reloaded"

# Attempt to mount all filesystems mentioned in /etc/fstab
if sudo mount -a; then
    echo "Mount command executed successfully"
else
    echo "Mount command failed. Check dmesg for more information."
fi
