#!/bin/bash -e
# Bootstrap installer for macOS (zsh default)

DOTFILES_DIR="$HOME/dotfiles"
CONFIG_DIR="$HOME/.config"

install_homebrew() {
  if ! command -v brew >/dev/null 2>&1; then
    echo "🍺 Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
}

install_dep() {
  brew install git curl unzip starship zoxide fastfetch mise fzf bat eza tree
  brew tap homebrew/cask-fonts && brew install --cask font-meslo-lg-nerd-font
}

backup_and_link() {
  echo "📂 Linking configs..."
  mkdir -p "$CONFIG_DIR/fastfetch" "$CONFIG_DIR/mise"

  ln -sf "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"
  ln -sf "$DOTFILES_DIR/config/starship.toml" "$CONFIG_DIR/starship.toml"
  ln -sf "$DOTFILES_DIR/config/mise/config.toml" "$CONFIG_DIR/mise/config.toml"
  ln -sf "$DOTFILES_DIR/config/fastfetch/macos.jsonc" "$CONFIG_DIR/fastfetch/config.jsonc"
}

install_homebrew
install_dep
backup_and_link

echo "✅ macOS dotfiles installed. Restart your terminal."