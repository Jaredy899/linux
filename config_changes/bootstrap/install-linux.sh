#!/bin/sh -e
# Bootstrap installer for Linux systems

DOTFILES_DIR="$HOME/dotfiles"
CONFIG_DIR="$HOME/.config"

# Detect distro (pacman, apt, etc.)
detect_pm() {
  if command -v apt >/dev/null 2>&1; then echo apt
  elif command -v pacman >/dev/null 2>&1; then echo pacman
  elif command -v dnf >/dev/null 2>&1; then echo dnf
  elif command -v apk >/dev/null 2>&1; then echo apk
  else echo unknown
  fi
}

PM=$(detect_pm)

install_dep() {
  case "$PM" in
    apt)    sudo apt update && sudo apt install -y git curl unzip fontconfig ;;
    pacman) sudo pacman -Sy --noconfirm git curl unzip fontconfig ;;
    dnf)    sudo dnf install -y git curl unzip fontconfig ;;
    apk)    sudo apk add git curl unzip fontconfig ;;
    *)      echo "⚠️ Unknown packager. Install git/curl manually." ;;
  esac
}

backup_and_link() {
  echo "📂 Symlinking configs..."
  mkdir -p "$CONFIG_DIR/fastfetch" "$CONFIG_DIR/mise"

  # Symlink bashrc
  ln -sf "$DOTFILES_DIR/bash/.bashrc" "$HOME/.bashrc"

  # If Alpine, prefer profile
  if grep -qi alpine /etc/os-release 2>/dev/null; then
    ln -sf "$DOTFILES_DIR/sh/.profile" "$HOME/.profile"
  fi

  # Symlink .zshrc if zsh installed
  if command -v zsh >/dev/null 2>&1; then
    ln -sf "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"
  fi

  # Symlink starship, mise, fastfetch
  ln -sf "$DOTFILES_DIR/config/starship.toml" "$CONFIG_DIR/starship.toml"
  ln -sf "$DOTFILES_DIR/config/mise/config.toml" "$CONFIG_DIR/mise/config.toml"

  # OS-specific fastfetch
  ln -sf "$DOTFILES_DIR/config/fastfetch/linux.jsonc" "$CONFIG_DIR/fastfetch/config.jsonc"
}

install_tools() {
  # starship
  if ! command -v starship >/dev/null 2>&1; then
    curl -sS https://starship.rs/install.sh | sh -s -- -y
  fi
  # zoxide
  if ! command -v zoxide >/dev/null 2>&1; then
    curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
  fi
  # mise
  if ! command -v mise >/dev/null 2>&1; then
    curl -sS https://mise.jdx.dev/install.sh | sh
  fi
  # fastfetch
  if ! command -v fastfetch >/dev/null 2>&1; then
    case "$PM" in
      apt)    sudo apt install -y fastfetch ;;
      pacman) sudo pacman -S --noconfirm fastfetch ;;
      dnf)    sudo dnf install -y fastfetch ;;
      apk)    sudo apk add fastfetch ;;
      *)      echo "⚠️ Install fastfetch manually" ;;
    esac
  fi
}

install_dep
backup_and_link
install_tools

echo "✅ Linux dotfiles installed. Restart shell."