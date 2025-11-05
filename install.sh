
#!/bin/bash

# --- Configuration ---
# Determine the script's actual directory, regardless of where it's called from
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
DOTFILES_DIR="$SCRIPT_DIR" # Set DOTFILES_DIR to the script's directory

CONFIG_DIR="$DOTFILES_DIR/.config"
SHARED_FUNCTIONS_SCRIPT="$CONFIG_DIR/hypr/scripts/shared-functions.sh" # Path to shared functions
PACKAGES_FILE="$DOTFILES_DIR/install" # Points to the file with only package names
ZSH_INSTALL_SCRIPT="$CONFIG_DIR/hypr/scripts/installzsh.sh"
PACMAN_ADDITIONAL_SCRIPT="$CONFIG_DIR/hypr/scripts/pacman-additional.sh"
BACKUP_DIR="$HOME/.config_$(date +%Y%m%d_%H%M%S)_bak"
TARGET_CONFIG_DIR="$HOME/.config"

# --- Source Shared Functions ---
if [ -f "$SHARED_FUNCTIONS_SCRIPT" ]; then
    source "$SHARED_FUNCTIONS_SCRIPT"
else
    echo "ERROR: Shared functions script not found at $SHARED_FUNCTIONS_SCRIPT."
    echo "Please ensure the file exists and the path is correct."
    # Define minimal fallbacks if shared functions are absolutely critical for script startup
    _command_exists() { command -v "$1" >/dev/null 2>&1; } # Minimal fallback
    _gum_confirm() { read -p "$1 [y/N] " response; [[ "$response" =~ ^[Yy]$ ]]; } # Minimal fallback
    _gum_spin() { echo "$1"; sleep "$2"; } # Minimal fallback
    _isInstalledYay() {
        local package="$1"
        yay -Q "$package" >/dev/null 2>&1
    }
    echo "Warning: Using minimal fallback helper functions."
fi

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
packages_array=()
while IFS= read -r pkg; do
    # Skip empty lines and comments
    [[ -z "$pkg" || "$pkg" =~ ^# ]] && continue
    packages_array+=("$pkg")
done < "$PACKAGES_FILE"

if [ ${#packages_array[@]} -eq 0 ]; then
    echo "ERROR: Could not extract package list from $PACKAGES_FILE (or file is empty)."
    exit 1
fi

echo "Found ${#packages_array[@]} packages to install"
echo "Installing packages using 'yay -S --needed'..."
if ! yay -S --needed "${packages_array[@]}"; then
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
# Create minimal placeholders that will be preserved if the repo doesn't provide them.
# Note: we create them again after symlinking in case the symlink step replaces the
# target directory (common when the repo contains a hypr/ folder). This prevents
# the placeholder from being lost.
echo
echo "--- Creating initial placeholder files (may be re-checked after symlink) ---"
# create parent dir so touch doesn't fail; these may be clobbered by symlink step
mkdir -p "$TARGET_CONFIG_DIR/hypr/conf"
if [ ! -f "$TARGET_CONFIG_DIR/hypr/conf/custom.conf" ]; then
    echo "Creating empty custom config file: $TARGET_CONFIG_DIR/hypr/conf/custom.conf"
    touch "$TARGET_CONFIG_DIR/hypr/conf/custom.conf"
fi
# Create .env file directly in HOME (only if missing)
# If repo provides a .env, copy it to $HOME (backing up any existing file). Otherwise create an empty file if missing.
if [ -f "$DOTFILES_DIR/.env" ]; then
    if [ -f "$HOME/.env" ]; then
        ENV_BACKUP="$HOME/.env.bak_$(date +%Y%m%d_%H%M%S)"
        echo "Backing up existing $HOME/.env -> $ENV_BACKUP"
        mv "$HOME/.env" "$ENV_BACKUP"
    fi
    echo "Copying repo .env -> $HOME/.env"
    cp -a "$DOTFILES_DIR/.env" "$HOME/.env"
else
    if [ ! -f "$HOME/.env" ]; then
        echo "Creating empty environment file: $HOME/.env"
        touch "$HOME/.env"
    fi
fi

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

# --- Ensure placeholders and important files exist AFTER symlinking ---
echo
echo "--- Verifying placeholders and user files after symlink ---"
# Ensure hypr custom.conf exists in the final config location
if [ ! -f "$TARGET_CONFIG_DIR/hypr/conf/custom.conf" ]; then
    echo "Note: $TARGET_CONFIG_DIR/hypr/conf/custom.conf missing after symlink. Creating placeholder."
    mkdir -p "$TARGET_CONFIG_DIR/hypr/conf"
    touch "$TARGET_CONFIG_DIR/hypr/conf/custom.conf"
fi
# Ensure pref.conf exists in the user's home (some setups expect it at $HOME/pref.conf).
# If the repo provides pref.conf, copy it into place (backing up any existing file).
if [ -f "$DOTFILES_DIR/pref.conf" ]; then
    if [ -f "$HOME/pref.conf" ]; then
        PREF_BACKUP="$HOME/pref.conf.bak_$(date +%Y%m%d_%H%M%S)"
        echo "Backing up existing $HOME/pref.conf -> $PREF_BACKUP"
        mv "$HOME/pref.conf" "$PREF_BACKUP"
    fi
    echo "Copying repo pref.conf -> $HOME/pref.conf"
    cp -a "$DOTFILES_DIR/pref.conf" "$HOME/pref.conf"
else
    if [ ! -f "$HOME/pref.conf" ]; then
        echo "Note: $HOME/pref.conf missing after symlink. Creating placeholder."
        touch "$HOME/pref.conf"
    fi
fi
# Ensure user has a .zshrc; if not, link the repo one if available
if [ ! -f "$HOME/.zshrc" ] && [ -f "$DOTFILES_DIR/.zshrc" ]; then
    echo ".zshrc not present in home; creating symlink to repo .zshrc"
    ln -sf "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"
fi

echo "Post-symlink verification complete."

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
    export CALLED_BY_INSTALL_SH=true
    if "$ZSH_INSTALL_SCRIPT"; then
        echo "Zsh configuration script finished."
    else
        echo "ERROR: Zsh configuration script failed."
        exit 1
    fi
    unset CALLED_BY_INSTALL_SH
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
    export CALLED_BY_INSTALL_SH=true
    if "$PACMAN_ADDITIONAL_SCRIPT"; then
        echo "Pacman configuration script finished."
    else
        echo "ERROR: Pacman configuration script failed."
        exit 1
    fi
    unset CALLED_BY_INSTALL_SH
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