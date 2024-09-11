#!/bin/bash

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

pacman -Sy --noconfirm --needed pacman-contrib terminus-font
setfont ter-v18b

clear_with_banner

# Function to display banner and handle disk selection
function diskpart {

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

    clear_with_banner
}

# Function to detect the active network interface
function detect_iface {
    iface=$(ip route | grep default | awk '{print $5}' | head -n 1)
    echo "Detected network interface: $iface"
    export IFACE=$iface
    clear_with_banner
}

# Function to prompt for username
function get_username {
    echo "Enter the username: "
    read username
    export USERNAME=$username
    clear_with_banner
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
    clear_with_banner
}

# Function to prompt for hostname
function get_hostname {
    echo "Enter the hostname: "
    read hostname
    export HOSTNAME=$hostname
    clear_with_banner
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
    clear_with_banner
}

function get_timezone {
    timezone=$(curl --silent https://ipapi.co/timezone)
    echo "Detected timezone: $timezone. Do you want to use this timezone? (Y/n): "
    read -r confirm_tz
    if [[ "$confirm_tz" != "Y" && "$confirm_tz" != "y" && "$confirm_tz" != "" ]]; then
        echo "Enter your preferred timezone (e.g., America/New_York): "
        read timezone
    fi
    export TIMEZONE=$timezone

    # Map the timezone to a country
    if [[ $timezone == America/* ]]; then
        country="United States"
    elif [[ $timezone == Europe/* ]]; then
        country="Germany"  # You can change this or add more specific mappings
    elif [[ $timezone == Asia/* ]]; then
        country="Japan"  # Example for Asia timezones
    else
        country="Worldwide"
    fi

    export COUNTRY=$country
    clear_with_banner
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
    clear_with_banner
}

function update_mirrorlist {
    echo "Updating the Mirror list from your timezone's country ($COUNTRY)..."

    # Ensure reflector is installed
    if ! command -v reflector &> /dev/null; then
        echo "Reflector is not installed. Installing it now..."
        pacman -Syu --noconfirm reflector
    fi

    # Use reflector to get 20 most recent, HTTPS mirrors from the detected country, sorted by download rate
    if [[ "$COUNTRY" != "Worldwide" ]]; then
        reflector --latest 20 --protocol https --country "$COUNTRY" --sort rate --save /etc/pacman.d/mirrorlist
    else
        # Default to worldwide mirrors if the country is not determined
        reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
    fi

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
    diskpart
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

# Run archinstall with the provided config and credentials
archinstall --config $config_file --creds $credentials_file --silent

# --- Insert the script here to handle mounting, chrooting, and rebooting ---

# List partitions of the selected disk with no tree format (-ln) and log them
partitions=$(lsblk -ln -o NAME,FSTYPE | grep "^$(basename $DISK)")
echo "Detected partitions on $DISK:"
echo "$partitions"

# Ensure /mnt exists
[ ! -d /mnt ] && mkdir /mnt

# Look for ext4, xfs, or btrfs filesystems on the selected disk
if echo "$partitions" | grep -q "ext4\|xfs"; then
  root_partition=$(echo "$partitions" | grep "ext4\|xfs" | head -n 1 | awk '{print $1}')
  echo "Mounting ext4 or xfs root partition: /dev/$root_partition"
  mount /dev/$root_partition /mnt || { echo "Failed to mount root partition: /dev/$root_partition"; exit 1; }
elif echo "$partitions" | grep -q "btrfs"; then
  btrfs_partition=$(echo "$partitions" | grep "btrfs" | head -n 1 | awk '{print $1}')
  echo "Mounting btrfs partition: /dev/$btrfs_partition"
  mount -o subvol=@ /dev/$btrfs_partition /mnt || { echo "Failed to mount root subvolume: /dev/$btrfs_partition"; exit 1; }
  mkdir -p /mnt/home /mnt/boot
  mount -o subvol=@home /dev/$btrfs_partition /mnt/home || { echo "Failed to mount @home subvolume: /dev/$btrfs_partition"; exit 1; }
  
  # Mount boot partition if applicable
  boot_partition=$(echo "$partitions" | grep "vfat" | head -n 1 | awk '{print $1}')
  if [ -n "$boot_partition" ]; then
    echo "Mounting boot partition: /dev/$boot_partition"
    mount /dev/$boot_partition /mnt/boot || { echo "Failed to mount boot partition: /dev/$boot_partition"; exit 1; }
  fi
else
  echo "No ext4, xfs, or btrfs partitions found on $DISK."
  exit 1
fi

# If the mount was successful, proceed
echo "Mount successful. Proceeding to chroot."

# Mount API filesystems
mount -t proc /proc /mnt/proc
mount --rbind /sys /mnt/sys
mount --rbind /dev /mnt/dev
mount --rbind /run /mnt/run

# Enter chroot using arch-chroot
arch-chroot /mnt << EOF
  curl https://raw.githubusercontent.com/Jaredy899/linux/main/installs/post_install.sh | sh
  exit
EOF

# # Unmount filesystems, handle force unmount if necessary
# echo "Unmounting filesystems..."

# umount -R /mnt || { 
#     echo "Some filesystems couldn't be unmounted cleanly, attempting lazy unmounts...";
#     umount -Rl /mnt || { 
#         echo "Force rebooting due to unmount issues...";
#         reboot -f
#     }
# }

# If unmounting succeeds, reboot normally
echo "Rebooting the system..."
reboot -f