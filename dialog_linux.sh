#!/bin/bash

# Ensure dialog is installed
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Jaredy899/linux/main/install.dialog.sh)"

# Ensure git is installed
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Jaredy899/linux/main/install.git.sh)"

# Check if the system is Ubuntu and add the PPA if it is
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [ "$ID" = "ubuntu" ]; then
        sudo add-apt-repository ppa:zhangsongcui3371/fastfetch -y >/dev/null 2>&1
    fi
fi

# Main menu
while true; do
    CHOICE=$(dialog --title "Setup Script" --menu "Choose an option:" 15 60 7 \
    1 "Start ChrisTitusTech script" \
    2 "Fix bashrc" \
    3 "Install Cockpit" \
    4 "Install Network Drive" \
    5 "Install qemu-guest-agent" \
    6 "Install Docker and Portainer" \
    7 "Exit" 3>&1 1>&2 2>&3)
    
    case $CHOICE in
        1)
            bash -c "$(curl -fsSL https://christitus.com/linux)"
            dialog --msgbox "ChrisTitusTech script completed." 8 40 --title "Info"
            ;;
        2)
            bash -c "$(curl -fsSL https://raw.githubusercontent.com/Jaredy899/linux/main/fix_bashrc.sh)"
            dialog --msgbox ".bashrc fixed." 8 40 --title "Info"
            ;;
        3)
            bash -c "$(curl -fsSL https://raw.githubusercontent.com/Jaredy899/linux/main/cockpit.sh)"
            dialog --msgbox "Cockpit installed." 8 40 --title "Info"
            ;;
        4)
            bash -c "$(curl -fsSL https://raw.githubusercontent.com/Jaredy899/linux/main/add_network_drive.sh)"
            dialog --msgbox "Network drive installed." 8 40 --title "Info"
            ;;
        5)
            bash -c "$(curl -fsSL https://raw.githubusercontent.com/Jaredy899/linux/main/qemu-guest-agent.sh)"
            dialog --msgbox "qemu-guest-agent installed." 8 40 --title "Info"
            ;;
        6)
            bash -c "$(curl -fsSL https://raw.githubusercontent.com/Jaredy899/linux/main/docker.sh)"

            # Reset the terminal session to apply Docker group changes
            exec su -l $USER
            ;;
        7)
            break
            ;;
        *)
            dialog --msgbox "Invalid option!" 8 40 --title "Error"
            ;;
    esac
done

# Clear the screen after exiting
clear
