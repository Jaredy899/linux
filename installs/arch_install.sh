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
pacman-key --init
pacman -Sy --noconfirm --needed pacman-contrib terminus-font
setfont ter-v18b
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

# Run archinstall
archinstall
