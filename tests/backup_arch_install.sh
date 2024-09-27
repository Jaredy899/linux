#!/bin/bash

# Function to display banner and handle disk selection
function banner_and_diskpart {
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

    echo -ne "
    ------------------------------------------------------------------------
        THIS WILL FORMAT AND DELETE ALL DATA ON THE DISK
        Please make sure you know what you are doing because
        after formatting your disk, there is no way to get data back.
        *****BACKUP YOUR DATA BEFORE CONTINUING*****
        ***I AM NOT RESPONSIBLE FOR ANY DATA LOSS***
    ------------------------------------------------------------------------
    "
    PS3='Select the disk to install on: '
    options=($(lsblk -n --output TYPE,KNAME,SIZE | awk '$1=="disk"{print "/dev/"$2"|"$3}'))

    select option in "${options[@]}"; do
        disk=${option%|*}
        echo -e "\n${disk} selected \n"
        export DISK=$disk
        break
    done

    clear
}

# Function to detect the active network interface
function detect_iface {
    iface=$(ip route | grep default | awk '{print $5}' | head -n 1)
    echo "Detected network interface: $iface"
    export IFACE=$iface
    clear
}

# Function to prompt for username
function get_username {
    echo "Enter the username: "
    read username
    export USERNAME=$username
    clear
}

# Function to prompt for password and confirm it
function get_password {
    while true; do
        echo "Enter the password: "
        read -s password
        echo
        echo "Confirm the password: "
        read -s password_confirm
        echo
        if [ "$password" == "$password_confirm" ]; then
            export PASSWORD=$password
            break
        else
            echo "Passwords do not match. Please try again."
        fi
    done
    clear
}

# Function to prompt for hostname
function get_hostname {
    echo "Enter the hostname: "
    read hostname
    export HOSTNAME=$hostname
    clear
}

# Function to select filesystem
function select_filesystem {
    echo "Choose filesystem (for root partition):"
    echo "1) Btrfs"
    echo "2) ext4"
    echo "3) xfs"
    read -p "Enter the number (1, 2, or 3): " fs_choice
    case $fs_choice in
        1) filesystem="btrfs" ;;
        2) filesystem="ext4" ;;
        *) filesystem="xfs" ;;
    esac
    export FILESYSTEM=$filesystem
    clear
}

# Function to detect timezone and confirm
function get_timezone {
    timezone=$(curl --silent https://ipapi.co/timezone)
    echo "Detected timezone: $timezone. Do you want to use this timezone? (Y/n): "
    read -r confirm_tz
    if [[ "$confirm_tz" != "Y" && "$confirm_tz" != "y" && "$confirm_tz" != "" ]]; then
        echo "Enter your preferred timezone (e.g., America/New_York): "
        read timezone
    fi
    export TIMEZONE=$timezone
    clear
}

# Function to select keyboard layout (default: us)
function select_keymap {
    echo "Select keyboard layout (default: us):"
    echo "1) us"
    echo "2) uk"
    echo "3) de"
    echo "4) fr"
    echo "5) es"
    read -p "Enter the number (1-5) or press Enter to use 'us': " keymap_choice
    case $keymap_choice in
        2) keymap="uk" ;;
        3) keymap="de" ;;
        4) keymap="fr" ;;
        5) keymap="es" ;;
        *) keymap="us" ;;
    esac
    export KEYMAP=$keymap
    clear
}

# Function to use reflector and update the mirrorlist based on the guide
function update_mirrorlist {
    echo "Updating /etc/pacman.d/mirrorlist with the 20 most recently synchronized HTTPS mirrors..."

    # Ensure reflector is installed
    if ! command -v reflector &> /dev/null; then
        echo "Reflector is not installed. Installing it now..."
        pacman -Syu --noconfirm reflector
    fi

    # Use reflector to get 20 most recent, HTTPS mirrors, sorted by download rate
    reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

    # Check if reflector succeeded
    if [ $? -ne 0 ]; then
        echo "Reflector failed to update mirrors. Restoring backup mirrorlist..."
        cp /etc/pacman.d/mirrorlist.bak /etc/pacman.d/mirrorlist
    else
        echo "Mirrorlist updated successfully."
    fi

    # Display the updated mirrorlist for user inspection
    echo "Here are the top mirrors:"
    head -n 20 /etc/pacman.d/mirrorlist
}

# Main function to run the entire script
function main {
    banner_and_diskpart
    detect_iface
    get_username
    get_password
    get_hostname
    select_filesystem
    get_timezone
    select_keymap

    # Update mirrorlist before proceeding with the installation
    update_mirrorlist

    echo -e "\nSummary:"
    echo "Username: $USERNAME"
    echo "Password: (hidden)"
    echo "Hostname: $HOSTNAME"
    echo "Disk: $DISK"
    echo "Filesystem: $FILESYSTEM"
    echo "Timezone: $TIMEZONE"
    echo "Keymap: $KEYMAP"
}

# Execute the main function
main

# Prepare the JSON configuration for user credentials
credentials_file="user_credentials.json"
echo "Creating $credentials_file..."

cat <<EOL > $credentials_file
{
    "!users": [
        {
            "!password": "$password",
            "sudo": true,
            "username": "$username"
        }
    ]
}
EOL

echo "User credentials saved to $credentials_file."

# Prepare the partition configuration dynamically based on filesystem choice
if [ "$filesystem" == "btrfs" ]; then
    partition_config='{
        "device": "'$DISK'",
        "partitions": [
            {
                "btrfs": [],
                "dev_path": null,
                "flags": [
                    "Boot",
                    "ESP"
                ],
                "fs_type": "fat32",
                "mount_options": [],
                "mountpoint": "/boot",
                "obj_id": "ca133b5f-1b92-4941-872e-020d8e82933d",
                "size": {
                    "sector_size": {
                        "unit": "B",
                        "value": 512
                    },
                    "unit": "GiB",
                    "value": 1
                },
                "start": {
                    "sector_size": {
                        "unit": "B",
                        "value": 512
                    },
                    "unit": "MiB",
                    "value": 1
                },
                "status": "create",
                "type": "primary"
            },
            {
                "btrfs": [
                    {
                        "mountpoint": "/",
                        "name": "@"
                    },
                    {
                        "mountpoint": "/home",
                        "name": "@home"
                    }
                ],
                "dev_path": null,
                "flags": [],
                "fs_type": "btrfs",
                "mount_options": [
                    "compress=zstd"
                ],
                "mountpoint": null,
                "obj_id": "419587f1-0f2c-4890-a13a-9b752f1ee786",
                "size": {
                    "sector_size": {
                        "unit": "B",
                        "value": 512
                    },
                    "unit": "B",
                    "value": 67643637760
                },
                "start": {
                    "sector_size": {
                        "unit": "B",
                        "value": 512
                    },
                    "unit": "B",
                    "value": 1074790400
                },
                "status": "create",
                "type": "primary"
            }
        ],
        "wipe": true
    }'
elif [ "$filesystem" == "xfs" ]; then
    partition_config='{
        "device": "'$DISK'",
        "partitions": [
            {
                "btrfs": [],
                "dev_path": null,
                "flags": [
                    "Boot",
                    "ESP"
                ],
                "fs_type": "fat32",
                "mount_options": [],
                "mountpoint": "/boot",
                "obj_id": "25cb7add-6d80-414e-a7d3-0687d098e56e",
                "size": {
                    "sector_size": {
                        "unit": "B",
                        "value": 512
                    },
                    "unit": "GiB",
                    "value": 1
                },
                "start": {
                    "sector_size": {
                        "unit": "B",
                        "value": 512
                    },
                    "unit": "MiB",
                    "value": 1
                },
                "status": "create",
                "type": "primary"
            },
            {
                "btrfs": [],
                "dev_path": null,
                "flags": [],
                "fs_type": "xfs",
                "mount_options": [],
                "mountpoint": "/",
                "obj_id": "3a5ee17c-609d-4bf1-895e-ffce49e04674",
                "size": {
                    "sector_size": {
                        "unit": "B",
                        "value": 512
                    },
                    "unit": "GiB",
                    "value": 20
                },
                "start": {
                    "sector_size": {
                        "unit": "B",
                        "value": 512
                    },
                    "unit": "B",
                    "value": 1074790400
                },
                "status": "create",
                "type": "primary"
            },
            {
                "btrfs": [],
                "dev_path": null,
                "flags": [],
                "fs_type": "xfs",
                "mount_options": [],
                "mountpoint": "/home",
                "obj_id": "67a6c9cc-2a66-4ea7-a16b-93957566c8d9",
                "size": {
                    "sector_size": {
                        "unit": "B",
                        "value": 512
                    },
                    "unit": "B",
                    "value": 46168801280
                },
                "start": {
                    "sector_size": {
                        "unit": "B",
                        "value": 512
                    },
                    "unit": "B",
                    "value": 22549626880
                },
                "status": "create",
                "type": "primary"
            }
        ],
        "wipe": true
    }'
else
    partition_config='{
        "device": "'$DISK'",
        "partitions": [
            {
                "btrfs": [],
                "dev_path": null,
                "flags": [
                    "Boot",
                    "ESP"
                ],
                "fs_type": "fat32",
                "mount_options": [],
                "mountpoint": "/boot",
                "obj_id": "172d3330-6327-43b8-ad2b-6b9c6b2c2ca0",
                "size": {
                    "sector_size": {
                        "unit": "B",
                        "value": 512
                    },
                    "unit": "GiB",
                    "value": 1
                },
                "start": {
                    "sector_size": {
                        "unit": "B",
                        "value": 512
                    },
                    "unit": "MiB",
                    "value": 1
                },
                "status": "create",
                "type": "primary"
            },
            {
                "btrfs": [],
                "dev_path": null,
                "flags": [],
                "fs_type": "ext4",
                "mount_options": [],
                "mountpoint": "/",
                "obj_id": "ed2389fa-b437-4796-88b5-acbaca91a6cc",
                "size": {
                    "sector_size": {
                        "unit": "B",
                        "value": 512
                    },
                    "unit": "GiB",
                    "value": 20
                },
                "start": {
                    "sector_size": {
                        "unit": "B",
                        "value": 512
                    },
                    "unit": "B",
                    "value": 1074790400
                },
                "status": "create",
                "type": "primary"
            },
            {
                "btrfs": [],
                "dev_path": null,
                "flags": [],
                "fs_type": "ext4",
                "mount_options": [],
                "mountpoint": "/home",
                "obj_id": "636531bd-0855-4831-b8a0-0c919bd6fc18",
                "size": {
                    "sector_size": {
                        "unit": "B",
                        "value": 512
                    },
                    "unit": "B",
                    "value": 46168801280
                },
                "start": {
                    "sector_size": {
                        "unit": "B",
                        "value": 512
                    },
                    "unit": "B",
                    "value": 22549626880
                },
                "status": "create",
                "type": "primary"
            }
        ],
        "wipe": true
    }'
fi

# Create the final configuration file
config_file="user_configuration.json"
echo "Creating $config_file..."

cat <<EOL > $config_file
{
    "additional-repositories": [],
    "archinstall-language": "English",
    "bootloader": "Grub",
    "config_version": "2.8.6",
    "debug": false,
    "disk_config": {
        "config_type": "default_layout",
        "device_modifications": [
            $partition_config
        ]
    },
    "hostname": "$hostname",
    "kernels": [
        "linux"
    ],
    "locale_config": {
        "kb_layout": "$keymap",
        "sys_enc": "UTF-8",
        "sys_lang": "en_US"
    },
    "network_config": {
        "nics": [
            {
                "dhcp": true,
                "dns": [],
                "gateway": null,
                "iface": "$IFACE",
                "ip": null
            }
        ],
        "type": "manual"
    },
    "no_pkg_lookups": false,
    "ntp": true,
    "offline": false,
    "profile_config": {
        "gfx_driver": null,
        "greeter": null,
        "profile": {
            "custom_settings": {
                "sshd": {}
            },
            "details": [
                "sshd"
            ],
            "main": "Server"
        }
    },
    "swap": true,
    "timezone": "$timezone",
    "version": "2.8.6"
}
EOL

echo "Installation configuration saved to $config_file."

# Start the installation process using archinstall with the user credentials and config files
archinstall --config $config_file --creds $credentials_file --silent

# Reboot after the installation completes
echo "Rebooting the system in 5 seconds..."
sleep 5
reboot