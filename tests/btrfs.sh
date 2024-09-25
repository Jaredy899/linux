#!/bin/bash

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root or with sudo."
    exit 1
fi

# Define the mount point where the BTRFS filesystem is mounted
MOUNT_POINT="/mnt"

# Create the root subvolume
btrfs subvolume create "$MOUNT_POINT/@"
echo "Created root subvolume: @"

# Create the home subvolume
btrfs subvolume create "$MOUNT_POINT/@home"
echo "Created home subvolume: @home"

echo "BTRFS subvolumes created successfully."
