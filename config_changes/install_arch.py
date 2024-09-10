from pathlib import Path
from archinstall import Installer, profile, disk, models
from archinstall.default_profiles.minimal import MinimalProfile
import subprocess
import os
import getpass
import urllib.request
import json

# Function to clear the screen and display the banner
def clear_screen_with_banner():
    os.system('clear')
    print("""
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
    """)

# Function to get timezone and country information
def get_timezone_and_country():
    try:
        response = urllib.request.urlopen("https://ipapi.co/json")
        data = json.load(response)
        return {
            "timezone": data["timezone"],
            "country_code": data["country_code"]
        }
    except Exception as e:
        print(f"Failed to detect timezone and country: {e}")
        return {
            "timezone": "UTC",
            "country_code": "US"  # Default to "US" if detection fails
        }

# Function to allow the user to select the disk by number
def select_disk():
    clear_screen_with_banner()
    print("Available disks:")
    
    # List all available disks using lsblk and extract the device names and sizes
    result = subprocess.run(['lsblk', '-dn', '-o', 'NAME,SIZE,TYPE', '--json'], capture_output=True, text=True)
    devices = json.loads(result.stdout)["blockdevices"]

    # Filter out non-disk devices
    disks = [dev for dev in devices if dev["type"] == "disk"]
    
    # Display disks with numbers
    for index, disk in enumerate(disks):
        print(f"{index + 1}) {disk['name']} - {disk['size']}")

    # Prompt the user to select a disk
    while True:
        disk_choice = input(f"Select a disk by number (1-{len(disks)}): ").strip()
        if disk_choice.isdigit() and 1 <= int(disk_choice) <= len(disks):
            selected_disk = disks[int(disk_choice) - 1]["name"]
            break
        else:
            print("Invalid choice. Please enter a valid number.")

    disk_path = f"/dev/{selected_disk}"
    print(f"Selected disk: {disk_path}")
    return disk_path

# Function to set up the mirrors using reflector
def setup_mirrors():
    print("Setting up mirrors for optimal download")
    
    # Get country ISO code based on public IP
    try:
        iso = subprocess.check_output("curl -4 ifconfig.co/country-iso", shell=True).decode().strip()
        print(f"Detected country ISO: {iso}")
    except subprocess.CalledProcessError as e:
        print(f"Error detecting country ISO: {e}")
        iso = "US"  # Fallback to US if detection fails

    # Sync system time
    subprocess.run(['timedatectl', 'set-ntp', 'true'])

    # Update keyrings and install necessary packages
    subprocess.run(['pacman', '-S', '--noconfirm', 'archlinux-keyring'])

    # Enable parallel downloads
    subprocess.run(["sed", "-i", "'s/^#ParallelDownloads/ParallelDownloads/'", "/etc/pacman.conf"])

    # Install reflector and other packages
    subprocess.run(['pacman', '-S', '--noconfirm', '--needed', 'reflector', 'rsync', 'grub'])

    # Backup mirrorlist
    subprocess.run(['cp', '/etc/pacman.d/mirrorlist', '/etc/pacman.d/mirrorlist.backup'])

    print(f"\nSetting up {iso} mirrors for faster downloads...\n")

    # Use reflector to update the mirrorlist with the best mirrors based on country ISO
    subprocess.run([
        'reflector', '-a', '48', '-c', iso, '-f', '5', '-l', '20', '--sort', 'rate', '--save', '/etc/pacman.d/mirrorlist'
    ])

    if not os.path.exists('/mnt'):
        os.makedirs('/mnt')

# Call mirror setup before installation
setup_mirrors()

# Select disk for installation
disk_path = select_disk()

# Ask the user for the desired filesystem
clear_screen_with_banner()
print("Choose filesystem:")
print("1) Btrfs")
print("2) ext4")
print("3) XFS")
fs_choice = input("Enter the number (1, 2, or 3): ").strip()

# Determine the filesystem type based on user input
if fs_choice == "1":
    fs_type = disk.FilesystemType('btrfs')
elif fs_choice == "2":
    fs_type = disk.FilesystemType('ext4')
elif fs_choice == "3":
    fs_type = disk.FilesystemType('xfs')
else:
    print("Invalid choice, defaulting to ext4.")
    fs_type = disk.FilesystemType('ext4')

# Get the physical disk device
device = disk.device_handler.get_device(Path(disk_path))
if not device:
    raise ValueError(f"No device found for path {disk_path}")

# Disk modification configuration
device_modification = disk.DeviceModification(device, wipe=True)

# Create partitions
boot_partition = disk.PartitionModification(
    status=disk.ModificationStatus.Create,
    type=disk.PartitionType.Primary,
    start=disk.Size(1, disk.Unit.MiB, device.device_info.sector_size),
    length=disk.Size(512, disk.Unit.MiB, device.device_info.sector_size),
    mountpoint=Path('/boot'),
    fs_type=disk.FilesystemType.Fat32,
    flags=[disk.PartitionFlag.Boot]
)
device_modification.add_partition(boot_partition)

root_partition = disk.PartitionModification(
    status=disk.ModificationStatus.Create,
    type=disk.PartitionType.Primary,
    start=disk.Size(513, disk.Unit.MiB, device.device_info.sector_size),
    length=disk.Size(20, disk.Unit.GiB, device.device_info.sector_size),
    mountpoint=Path('/'),
    fs_type=fs_type,
    mount_options=[]
)
device_modification.add_partition(root_partition)

# Create the disk configuration
disk_config = disk.DiskLayoutConfiguration(
    config_type=disk.DiskLayoutType.Default,
    device_modifications=[device_modification]
)

# Filesystem handler to format and prepare disks
fs_handler = disk.FilesystemHandler(disk_config)
fs_handler.perform_filesystem_operations(show_countdown=False)

# Continue the rest of your installation logic...
