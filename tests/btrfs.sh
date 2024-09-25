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

# Add entries to /etc/fstab
echo "Adding subvolume entries to /etc/fstab..."

# Get the UUID of the BTRFS filesystem
UUID=$(blkid -s UUID -o value $(findmnt -no SOURCE "$MOUNT_POINT"))

# Append entries to /etc/fstab
echo "UUID=$UUID  /          btrfs   subvol=@,defaults,noatime  0  1" >> /etc/fstab
echo "UUID=$UUID  /home      btrfs   subvol=@home,defaults,noatime  0  2" >> /etc/fstab

echo "Entries added to /etc/fstab successfully."
