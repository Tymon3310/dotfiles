#!/bin/bash

# Source shared functions
SCRIPT_DIR_PACMAN=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
SHARED_FUNCTIONS_SCRIPT="$SCRIPT_DIR_PACMAN/shared-functions.sh"

if [ -f "$SHARED_FUNCTIONS_SCRIPT" ]; then
    source "$SHARED_FUNCTIONS_SCRIPT"
else
    echo "ERROR: Shared functions script not found at $SHARED_FUNCTIONS_SCRIPT for pacman-additional.sh."
    _gum_confirm() { read -p "$1 [y/N] " response; [[ "$response" =~ ^[Yy]$ ]]; }
    _command_exists() { command -v "$1" >/dev/null 2>&1; } # Minimal fallback for _command_exists
    echo "Warning: Using minimal fallback helper functions in pacman-additional.sh."
fi
 
if [[ -z "$CALLED_BY_INSTALL_SH" ]]; then
    if _command_exists figlet; then
        figlet -f smslant "Pacman Configuration"
    elif _command_exists toilet; then # Added toilet as an alternative
        toilet -f standard --filter border "Pacman Configuration"
    else
        echo "========================="
        echo " Pacman Configuration"
        echo "========================="
    fi
    echo # Extra empty line for spacing when run standalone
fi

echo
echo "This script will guide you through configuring options in /etc/pacman.conf."
echo

configure_pacman_option() {
    local option_name="$1"
    local confirmation_prompt="Do you want to activate ${option_name}?"

    # 1. Check if already active (start of line, no #, followed by name, then word boundary or space)
    if grep -q "^${option_name}\b" /etc/pacman.conf; then
        echo "${option_name} is already activated."
        return
    fi

    # 2. Check if commented out (start of line, #, optional spaces, name)
    # We use regex to match lines like "#ParallelDownloads = 5" or "#Color"
    if grep -q "^#[[:space:]]*${option_name}\b" /etc/pacman.conf; then
        if _gum_confirm "${confirmation_prompt}"; then
            # Uncomment: replace '#Option' or '# Option' with 'Option'
            # We only replace the leading comment char, preserving the rest of the line (like '= 5')
            sudo sed -i "s/^#[[:space:]]*${option_name}/${option_name}/" /etc/pacman.conf
            echo "${option_name} activated."
        else
            echo "Activation of ${option_name} skipped."
        fi
    else
        echo "WARNING: ${option_name} line not found in pacman.conf. Skipping."
    fi
}

configure_pacman_option "ParallelDownloads"
configure_pacman_option "Color"
configure_pacman_option "NoProgressBar"
configure_pacman_option "VerbosePkgLists"

if grep -Fxq "ILoveCandy" /etc/pacman.conf; then
    echo "ILoveCandy is already activated."
else
    if _gum_confirm "Do you want to activate ILoveCandy?"; then
        # Insert after ParallelDownloads, regardless of whether it is commented (#) or not
        sudo sed -i '/^#\?ParallelDownloads/a ILoveCandy' /etc/pacman.conf
        echo "ILoveCandy activated."
    else
        echo "Activation of ILoveCandy skipped."
    fi
fi
