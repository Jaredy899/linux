#!/bin/sh -e

. "$(dirname "$0")/../common_script.sh"

# Check environment
checkEnv

installCifsUtils() {
    if ! command_exists mount.cifs; then
        printf "%b\n" "${YELLOW}Installing CIFS utils...${RC}"
        case "$PACKAGER" in
            pacman)
                "$ESCALATION_TOOL" "$PACKAGER" -S --needed --noconfirm cifs-utils
                ;;
            *)
                "$ESCALATION_TOOL" "$PACKAGER" install -y cifs-utils
                ;;
        esac
    else
        printf "%b\n" "${GREEN}CIFS utils are already installed.${RC}"
    fi
}

installNfsUtils() {
    if ! command_exists mount.nfs; then
        printf "%b\n" "${YELLOW}Installing NFS utils...${RC}"
        case "$PACKAGER" in
            pacman)
                "$ESCALATION_TOOL" "$PACKAGER" -S --needed --noconfirm nfs-utils
                ;;
            *)
                "$ESCALATION_TOOL" "$PACKAGER" install -y nfs-utils
                ;;
        esac
    else
        printf "%b\n" "${GREEN}NFS utils are already installed.${RC}"
    fi
}

# Ask if the user wants to mount a CIFS (Samba) or NFS drive
printf "Do you want to mount a CIFS (Samba) or NFS drive? (cifs/nfs): "
read mount_type

if [ "$mount_type" = "cifs" ]; then
    installCifsUtils

    # Prompt the user for the remote mount location
    printf "Enter the remote CIFS (Samba) mount location (e.g., //192.168.1.1/Files): "
    read remote_mount

    # Prompt the user for the username
    printf "Enter the username for the remote CIFS (Samba) mount: "
    read username

    # Prompt the user for the password (input will be hidden)
    stty -echo
    printf "Enter the password for the remote CIFS (Samba) mount: "
    read password
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

elif [ "$mount_type" = "nfs" ]; then
    installNfsUtils

    # Prompt the user for the remote mount location
    printf "Enter the remote NFS mount location (e.g., 192.168.1.1:/path/to/share): "
    read remote_mount

    # NFS doesn't require a credentials file, so set mount options accordingly
    mount_options="defaults"
    fs_type="nfs"

else
    printf "%b\n" "${RED}Invalid option. Please specify 'cifs' or 'nfs'.${RC}"
    exit 1
fi

# Ask if the user wants to use the default mount directory
printf "Do you want to use the default local mount directory (/srv/remotemount)? (y/n): "
read use_default

if [ "$use_default" = "y" ] || [ "$use_default" = "Y" ]; then
    # Prompt for the mount name
    printf "Enter the name for the mount directory (e.g., nas): "
    read mount_name
    local_mount="/srv/remotemount/$mount_name"
else
    # Prompt for the full custom local mount directory
    printf "Enter the full path for the local mount directory: "
    read local_mount
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

# Attempt to mount all filesystems mentioned in /etc/fstab
if "$ESCALATION_TOOL" mount -a; then
    printf "%b\n" "${GREEN}Mount command executed successfully${RC}"
else
    printf "%b\n" "${RED}Mount command failed. Check dmesg for more information.${RC}"
fi
