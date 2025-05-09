#!/bin/bash

# --- Configuration ---
# Determine the script's actual directory, regardless of where it's called from
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
DOTFILES_DIR="$SCRIPT_DIR" # Set DOTFILES_DIR to the script's directory

CONFIG_DIR="$DOTFILES_DIR/.config"
PACKAGES_FILE="$DOTFILES_DIR/install" # Points to the file with only package names
ZSH_INSTALL_SCRIPT="$CONFIG_DIR/hypr/scripts/installzsh.sh"
PACMAN_ADDITIONAL_SCRIPT="$CONFIG_DIR/hypr/scripts/pacman-additional.sh"
BACKUP_DIR="$HOME/.config_$(date +%Y%m%d_%H%M%S)_bak"
TARGET_CONFIG_DIR="$HOME/.config"

# --- Helper Functions ---
_command_exists() {
    command -v "$1" >/dev/null 2>&1
}

_gum_confirm() {
    if _command_exists gum; then
        gum confirm "$1"
    else
        read -p "$1 [y/N] " response
        [[ "$response" =~ ^[Yy]$ ]]
    fi
}

_gum_spin() {
    if _command_exists gum; then
        gum spin --spinner dot --title "$1" -- sleep "$2"
    else
        echo "$1"
        sleep "$2"
    fi
}

# --- Start Script ---
clear
if _command_exists figlet; then
    figlet -f smslant "Dotfiles Setup"
else
    echo "====================="
    echo " Dotfiles Setup"
    echo "====================="
fi
echo "This script will install packages, configure Zsh, backup your current config, and symlink the dotfiles."
echo "Running from: $DOTFILES_DIR"
echo "Backing up ~/.config to: $BACKUP_DIR"
echo

if ! _gum_confirm "Do you want to proceed?"; then
    echo "Installation aborted."
    exit 1
fi

# --- 1. Install Packages ---
echo
echo "--- Installing Packages ---"
if ! _command_exists yay; then
    echo "ERROR: yay is not installed. Please install it first."
    echo "Do you want to install it now?"
    if _gum_confirm "Install yay?"; then
        sudo pacman -S --needed git base-devel
        git clone https://aur.archlinux.org/yay-bin.git
        cd yay-bin
        makepkg -si
        cd ..
    fi
fi

# Extract package names from $PACKAGES_FILE
echo "Reading package list from $PACKAGES_FILE..."
if [ ! -f "$PACKAGES_FILE" ]; then
    echo "ERROR: Package list file not found at $PACKAGES_FILE."
    exit 1
fi

# Read the file, handle line continuations, squeeze multiple spaces, and trim.
packages=$(cat "$PACKAGES_FILE" | tr '\\\n' ' ' | tr -s ' ' | xargs)

if [ -z "$packages" ]; then
    echo "ERROR: Could not extract package list from $PACKAGES_FILE (or file is empty)."
    exit 1
fi

echo "Found packages: $packages"
echo "Installing packages using 'yay -S --needed'..."
if ! yay -S --needed $packages; then
    echo "ERROR: Package installation failed."
    exit 1
fi
echo "Packages installed successfully."

# --- 2. Backup Current ~/.config ---
echo
echo "--- Backing up ~/.config ---"
if [ -d "$TARGET_CONFIG_DIR" ] || [ -L "$TARGET_CONFIG_DIR" ]; then
    echo "Existing ~/.config found. Moving to $BACKUP_DIR..."
    if mv "$TARGET_CONFIG_DIR" "$BACKUP_DIR"; then
        echo "Backup successful."
    else
        echo "ERROR: Failed to backup ~/.config."
        exit 1
    fi
else
    echo "~/.config does not exist. Skipping backup."
fi

# --- Create necessary placeholder files BEFORE symlinking ---
echo
echo "--- Creating placeholder files ---"
# Ensure target directory exists in dotfiles source for custom.conf
mkdir -p "$TARGET_CONFIG_DIR/hypr/conf"
echo "Creating empty custom config file: $TARGET_CONFIG_DIR/hypr/conf/custom.conf"
touch "$TARGET_CONFIG_DIR/hypr/conf/custom.conf"
# Create .env file directly in HOME after potential backup/symlink setup
echo "Creating empty environment file: $HOME/.env"
touch "$HOME/.env"

# --- 3. Symlink Dotfiles ---
echo
echo "--- Symlinking Dotfiles ---"

# Create ~/.config directory if it doesn't exist (after potential backup)
mkdir -p "$TARGET_CONFIG_DIR"

# Symlink top-level dotfiles (e.g., .zshrc, .bashrc)
echo "Symlinking top-level files (.*) to $HOME..."
find "$DOTFILES_DIR" -maxdepth 1 -type f -name ".*" -not -name ".git" -not -name "*.md" -not -name "install" -not -name "*.sh" -print -exec ln -sf {} "$HOME/" \;
# Add specific handling for other top-level files if needed (e.g., .gitconfig)
# Example: ln -sf "$DOTFILES_DIR/.gitconfig" "$HOME/.gitconfig"

# Symlink contents of the repository's .config directory
echo "Symlinking contents of $CONFIG_DIR to $TARGET_CONFIG_DIR..."
if [ -d "$CONFIG_DIR" ]; then
    for item in "$CONFIG_DIR"/*; do
        if [ -e "$item" ]; then # Check if item exists
            target_path="$TARGET_CONFIG_DIR/$(basename "$item")"
            echo "Linking $(basename "$item") -> $target_path"
            ln -sf "$item" "$target_path"
        fi
    done
else
    echo "WARNING: $CONFIG_DIR not found in dotfiles repository. No config files linked."
fi
echo "Symlinking complete."

# --- 4. Install Hyprland Plugins ---
echo
echo "--- Installing Hyprland Plugins ---"
if _command_exists hyprpm; then
    echo "Installing split-monitor-workspaces plugin..."
    if hyprpm add https://github.com/Duckonaut/split-monitor-workspaces; then
        echo "Enabling split-monitor-workspaces plugin..."
        if hyprpm enable split-monitor-workspaces; then
            echo "Reloading hyprpm plugins..."
            if hyprpm reload; then
                echo "Hyprland plugin installed and enabled successfully."
            else
                echo "WARNING: hyprpm reload failed."
            fi
        else
            echo "ERROR: Failed to enable hyprpm plugin."
        fi
    else
        echo "ERROR: Failed to add hyprpm plugin repository."
    fi
else
    echo "WARNING: hyprpm command not found. Skipping plugin installation."
fi

# --- 5. Run Zsh Install Script ---
echo
echo "--- Configuring Zsh ---"
if [ -f "$ZSH_INSTALL_SCRIPT" ]; then
    echo "Running Zsh installation script: $ZSH_INSTALL_SCRIPT"
    chmod +x "$ZSH_INSTALL_SCRIPT"
    if "$ZSH_INSTALL_SCRIPT"; then
        echo "Zsh configuration script finished."
    else
        echo "ERROR: Zsh configuration script failed."
        exit 1
    fi
else
    echo "ERROR: Zsh installation script not found at $ZSH_INSTALL_SCRIPT."
    exit 1
fi

# --- 6. Configure Pacman ---
echo
echo "--- Configuring Pacman ---"
if [ -f "$PACMAN_ADDITIONAL_SCRIPT" ]; then
    echo "Running Pacman configuration script: $PACMAN_ADDITIONAL_SCRIPT"
    chmod +x "$PACMAN_ADDITIONAL_SCRIPT"
    if "$PACMAN_ADDITIONAL_SCRIPT"; then
        echo "Pacman configuration script finished."
    else
        echo "ERROR: Pacman configuration script failed."
        exit 1
    fi
else
    echo "ERROR: Pacman configuration script not found at $PACMAN_ADDITIONAL_SCRIPT."
    exit 1
fi
# --- Finish ---
echo
echo "=========================="
echo " Dotfiles Setup Complete!"
echo "=========================="
echo "Notes:"
echo "*   Your original ~/.config directory was backed up to $BACKUP_DIR"
echo "*   Dotfiles have been symlinked."
echo "*   Zsh has been configured."
echo "*   Placeholder ~/.env and .config/hypr/conf/custom.conf created."
echo "*   Hyprland plugin 'split-monitor-workspaces' installation attempted."
_gum_spin "A system reboot or logging out and back in might be required for all changes to take effect." 5

exit 0