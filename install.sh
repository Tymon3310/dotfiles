#!/bin/bash

# --- Configuration ---
# Determine the script's actual directory, regardless of where it's called from
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
DOTFILES_DIR="$SCRIPT_DIR" # Set DOTFILES_DIR to the script's directory

CONFIG_DIR="$DOTFILES_DIR/.config"
PACKAGES_FILE="$DOTFILES_DIR/PACKAGES.md"
ZSH_INSTALL_SCRIPT="$CONFIG_DIR/hypr/scripts/installzsh.sh"
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
    exit 1
fi

# Extract packages from PACKAGES.md installation command block
echo "Reading package list from $PACKAGES_FILE..."
packages=$(awk '/## Installation Command/,/```bash/{flag=1; next} /```/{flag=0} flag' "$PACKAGES_FILE" | grep -v '^$' | sed 's/\\//g' | tr '\n' ' ')

if [ -z "$packages" ]; then
    echo "ERROR: Could not extract package list from $PACKAGES_FILE."
    exit 1
fi

echo "Found packages: $packages"
echo "Installing packages using yay..."
if ! yay -S --needed --noconfirm $packages; then
    echo "ERROR: Package installation failed."
    exit 1
fi
echo "Packages installed successfully."

# --- 3. Backup Current ~/.config ---
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
mkdir -p "$CONFIG_DIR/hypr/conf"
echo "Creating empty custom config file: $CONFIG_DIR/hypr/conf/custom.conf"
touch "$CONFIG_DIR/hypr/conf/custom.conf"
# Create .env file directly in HOME after potential backup/symlink setup
echo "Creating empty environment file: $HOME/.env"
touch "$HOME/.env"

# --- 4. Symlink Dotfiles ---
echo
echo "--- Symlinking Dotfiles ---"

# Create ~/.config directory if it doesn't exist (after potential backup)
mkdir -p "$TARGET_CONFIG_DIR"

# Symlink top-level dotfiles (e.g., .zshrc, .bashrc)
echo "Symlinking top-level files (.*) to $HOME..."
find "$DOTFILES_DIR" -maxdepth 1 -type f -name ".*" -print -exec ln -sf {} "$HOME/" \;
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

# --- Install Hyprland Plugins ---
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

# --- 2. Run Zsh Install Script ---
echo
echo "--- Configuring Zsh ---"
if [ -f "$ZSH_INSTALL_SCRIPT" ]; then
    echo "Running Zsh installation script: $ZSH_INSTALL_SCRIPT"
    chmod +x "$ZSH_INSTALL_SCRIPT"
    if "$ZSH_INSTALL_SCRIPT"; then
        echo "Zsh configuration script finished."
    else
        echo "ERROR: Zsh configuration script failed."
        # Decide if this is critical enough to exit
        # exit 1
    fi
else
    echo "ERROR: Zsh installation script not found at $ZSH_INSTALL_SCRIPT."
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