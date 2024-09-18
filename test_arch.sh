#!/bin/bash

set -e

# Function to display the banner
function display_banner {
    echo -ne "
    -------------------------------------------------------------------------
                         █████╗ ██████╗  ██████╗██╗  ██╗
                        ██╔══██╗██╔══██╗██╔════╝██║  ██║
                        ███████║██████╔╝██║     ███████║
                        ██╔══██║██╔══██╗██║     ██╔══██║ 
                        ██║  ██║██║  ██║╚██████╗██║  ██║ 
                        ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝ 
    -------------------------------------------------------------------------
                        Automated Arch Linux Installer
    -------------------------------------------------------------------------
    "
}

# Function to clear the screen and display the banner
function clear_with_banner {
    clear
    display_banner
}

# Display the banner at the beginning
clear_with_banner

# Install necessary packages
pacman -Sy --noconfirm --needed pacman-contrib terminus-font
setfont ter-v18b
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

# Run archinstall
archinstall --script

# Automatically chroot and run post-install script
MOUNT_POINT=$(mount | grep 'on / type' | cut -d' ' -f3)
if [ -n "$MOUNT_POINT" ]; then
    echo "Chrooting into the new system..."
    arch-chroot $MOUNT_POINT /bin/bash -c "curl -sSL https://raw.githubusercontent.com/Jaredy899/linux/refs/heads/main/installs/post_install.sh | bash"
else
    echo "Error: Unable to determine the mount point of the new system."
fi