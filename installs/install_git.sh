#!/bin/sh -e

# Set SKIP_AUR_CHECK to ignore AUR helper check
SKIP_AUR_CHECK=true

# Source the common script directly from GitHub
eval "$(curl -s https://raw.githubusercontent.com/Jaredy899/linux/refs/heads/main/common_script.sh)"
eval "$(curl -s https://raw.githubusercontent.com/Jaredy899/linux/refs/heads/dev/common_service_script.sh)"

# Run the environment check
checkEnv || exit 1

# Function to install Git
install_git() {
    if ! command_exists git; then
        printf "%b\n" "${YELLOW}Installing Git...${RC}"
        noninteractive git
        printf "%b\n" "${GREEN}Git installation complete.${RC}"
    else
        printf "%b\n" "${GREEN}Git is already installed.${RC}"
    fi
}

# Main script
install_git

# Verify Git installation
if command_exists git; then
    git_version=$(git --version)
    printf "%b\n" "${GREEN}Git is installed successfully. Version: $git_version${RC}"
else
    printf "%b\n" "${RED}Git installation failed or Git is not in the system PATH.${RC}"
    exit 1
fi
