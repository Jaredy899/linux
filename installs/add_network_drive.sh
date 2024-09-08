#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to determine the package manager and install a package
install_package() {
    package_name="$1"
    distro="$2"

    case "$distro" in
        ubuntu|debian)
            if ! dpkg -l | grep -q "$package_name"; then
                echo "$package_name is not installed. Installing $package_name..."
                sudo apt-get update -y
                sudo apt-get install -y "$package_name"
            else
                echo "$package_name is already installed."
            fi
            ;;
        fedora|centos|rhel|rocky|alma)
            if ! rpm -qa | grep -q "$package_name"; then
                echo "$package_name is not installed. Installing $package_name..."
                sudo dnf install -y "$package_name"
            else
                echo "$package_name is already installed."
            fi
            ;;
        arch)
            if ! pacman -Qi "$package_name" > /dev/null; then
                echo "$package_name is not installed. Installing $package_name..."
                sudo pacman -Sy --noconfirm "$package_name"
            else
                echo "$package_name is already installed."
            fi
            ;;
        opensuse|suse)
            if ! rpm -qa | grep -q "$package_name"; then
                echo "$package_name is not installed. Installing $package_name..."
                sudo zypper install -y "$package_name"
            else
                echo "$package_name is already installed."
            fi
            ;;
        *)
            echo "Unsupported distribution: $distro. Please install $package_name manually."
            exit 1
            ;;
    esac
}

# Function to detect Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

# Detect the Linux distribution
distro=$(detect_distro)
if [ "$distro" = "unknown" ]; then
    echo "Unable to detect Linux distribution. Exiting."
    exit 1
fi

# Ask if the user wants to mount a CIFS (Samba) or NFS drive
read -p "Do you want to mount a CIFS (Samba) or NFS drive? (cifs/nfs): " mount_type

if [[ "$mount_type" == "cifs" ]]; then
    # Ensure cifs-utils is installed
    install_package "cifs-utils" "$distro"

    # Prompt the user for the remote mount location
    read -p "Enter the remote CIFS (Samba) mount location (e.g., //192.168.1.1/Files): " remote_mount

    # Prompt the user for the username
    read -p "Enter the username for the remote CIFS (Samba) mount: " username

    # Prompt the user for the password (input will be hidden)
    read -s -p "Enter the password for the remote CIFS (Samba) mount: " password
    echo # To move to the next line after password input

    # Create a credentials file in a secure location
    credentials_file="/etc/cifs-credentials-$username"

    # Write the credentials to the file
    echo "username=$username" | sudo tee "$credentials_file" > /dev/null
    echo "password=$password" | sudo tee -a "$credentials_file" > /dev/null

    # Set permissions to restrict access to the credentials file
    sudo chmod 600 "$credentials_file"

    # Construct the new entry using the credentials file
    mount_options="credentials=$credentials_file"
    fs_type="cifs"

elif [[ "$mount_type" == "nfs" ]]; then
    # Ensure nfs-utils is installed
    install_package "nfs-utils" "$distro"

    # Prompt the user for the remote mount location
    read -p "Enter the remote NFS mount location (e.g., 192.168.1.1:/path/to/share): " remote_mount

    # NFS doesn't require a credentials file, so set mount options accordingly
    mount_options="defaults"
    fs_type="nfs"

else
    echo "Invalid option. Please specify 'cifs' or 'nfs'."
    exit 1
fi

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

# Check if the mount directory exists, and create it if it doesn't
if [ ! -d "$local_mount" ]; then
    sudo mkdir -p "$local_mount"
    echo "Created mount directory $local_mount"
fi

# Construct the new entry for /etc/fstab
new_entry="$remote_mount $local_mount $fs_type $mount_options 0 0"

# Check if the line already exists in /etc/fstab
if grep -Fxq "$new_entry" /etc/fstab; then
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
