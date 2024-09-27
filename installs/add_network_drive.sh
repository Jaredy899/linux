#!/bin/sh -e

# Source the common script
. "$(dirname "$0")/../common_script.sh"

# Run the environment check
checkEnv || exit 1

# Function to install a package
install_package() {
    package_name="$1"
    if ! command_exists "$package_name"; then
        printf "%b\n" "${YELLOW}Installing $package_name...${RC}"
        case "$PACKAGER" in
            pacman)
                "$ESCALATION_TOOL" "$PACKAGER" -S --needed --noconfirm "$package_name"
                ;;
            *)
                "$ESCALATION_TOOL" "$PACKAGER" install -y "$package_name"
                ;;
        esac
    else
        printf "%b\n" "${GREEN}$package_name is already installed.${RC}"
    fi
}

# Ask if the user wants to mount a CIFS (Samba) or NFS drive
printf "%b" "${CYAN}Do you want to mount a CIFS (Samba) or NFS drive? (cifs/nfs): ${RC}"
read -r mount_type

case "$mount_type" in
    cifs)
        # Ensure cifs-utils is installed
        install_package "cifs-utils"

        # Prompt the user for the remote mount location
        printf "%b" "${CYAN}Enter the remote CIFS (Samba) mount location (e.g., //192.168.1.1/Files): ${RC}"
        read -r remote_mount

        # Prompt the user for the username
        printf "%b" "${CYAN}Enter the username for the remote CIFS (Samba) mount: ${RC}"
        read -r username

        # Prompt the user for the password (input will be hidden)
        printf "%b" "${CYAN}Enter the password for the remote CIFS (Samba) mount: ${RC}"
        stty -echo
        read -r password
        stty echo
        printf "\n"

        # Create a credentials file in a secure location
        credentials_file="/etc/cifs-credentials-$username"

        # Write the credentials to the file
        printf "username=%s\n" "$username" | "$ESCALATION_TOOL" tee "$credentials_file" > /dev/null
        printf "password=%s\n" "$password" | "$ESCALATION_TOOL" tee -a "$credentials_file" > /dev/null

        # Set permissions to restrict access to the credentials file
        "$ESCALATION_TOOL" chmod 600 "$credentials_file"

        # Construct the new entry using the credentials file
        mount_options="credentials=$credentials_file"
        fs_type="cifs"
        ;;
    nfs)
        # Ensure nfs-utils is installed
        install_package "nfs-utils"

        # Prompt the user for the remote mount location
        printf "%b" "${CYAN}Enter the remote NFS mount location (e.g., 192.168.1.1:/path/to/share): ${RC}"
        read -r remote_mount

        # NFS doesn't require a credentials file, so set mount options accordingly
        mount_options="defaults"
        fs_type="nfs"
        ;;
    *)
        printf "%b\n" "${RED}Invalid option. Please specify 'cifs' or 'nfs'.${RC}"
        exit 1
        ;;
esac

# Ask if the user wants to use the default mount directory
printf "%b" "${CYAN}Do you want to use the default local mount directory (/srv/remotemount)? (y/n): ${RC}"
read -r use_default

if [ "$use_default" = "y" ] || [ "$use_default" = "Y" ]; then
    # Prompt for the mount name
    printf "%b" "${CYAN}Enter the name for the mount directory (e.g., nas): ${RC}"
    read -r mount_name
    local_mount="/srv/remotemount/$mount_name"
else
    # Prompt for the full custom local mount directory
    printf "%b" "${CYAN}Enter the full path for the local mount directory: ${RC}"
    read -r local_mount
fi

# Check if the mount directory exists, and create it if it doesn't
if [ ! -d "$local_mount" ]; then
    "$ESCALATION_TOOL" mkdir -p "$local_mount"
    printf "%b\n" "${GREEN}Created mount directory $local_mount${RC}"
fi

# Construct the new entry for /etc/fstab
new_entry="$remote_mount $local_mount $fs_type $mount_options 0 0"

# Check if the line already exists in /etc/fstab
if grep -Fxq "$new_entry" /etc/fstab; then
    printf "%b\n" "${YELLOW}The entry already exists in /etc/fstab${RC}"
else
    # Add the new entry to the end of /etc/fstab
    printf "%s\n" "$new_entry" | "$ESCALATION_TOOL" tee -a /etc/fstab > /dev/null
    printf "%b\n" "${GREEN}The entry has been added to /etc/fstab${RC}"
fi

# Reload the systemd daemon to recognize the changes in /etc/fstab
"$ESCALATION_TOOL" systemctl daemon-reload
printf "%b\n" "${GREEN}Systemd daemon reloaded${RC}"

# Attempt to mount the new filesystem
if "$ESCALATION_TOOL" mount "$local_mount"; then
    printf "%b\n" "${GREEN}Mount command executed successfully${RC}"
else
    printf "%b\n" "${RED}Mount command failed. Check dmesg for more information.${RC}"
fi

# Verify the mount
if mountpoint -q "$local_mount"; then
    printf "%b\n" "${GREEN}The network drive has been successfully mounted at $local_mount${RC}"
else
    printf "%b\n" "${RED}Failed to mount the network drive. Please check your settings and try again.${RC}"
fi