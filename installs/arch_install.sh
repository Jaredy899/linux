# #!/bin/bash

pacman -Sy --noconfirm archlinux-keyring #update keyrings to latest to prevent packages failing to install
pacman -Sy --noconfirm --needed pacman-contrib terminus-font
setfont ter-v18b

# Download the Python install script from GitHub
echo "Downloading Arch installation Python script..."
curl -o /mnt/install_arch.py https://raw.githubusercontent.com/Jaredy899/linux/main/config_changes/install_arch.py

# Ensure the script was downloaded successfully
if [ ! -f /mnt/install_arch.py ]; then
    echo "Error: Failed to download the Python script."
    exit 1
fi

# Run the Python Arch install script from /mnt
echo "Running the Python installation script..."
python /mnt/install_arch.py

# Check if the Python script executed successfully
if [ $? -eq 0 ]; then
    echo "Python installation script completed successfully."
else
    echo "Error: Python installation script failed."
    exit 1
fi
