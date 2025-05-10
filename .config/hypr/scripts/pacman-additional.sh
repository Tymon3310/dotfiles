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
    local regex_check="${2:-#${option_name}}" # Default to check for commented line
    local sed_uncomment="s/^#${option_name}/${option_name}/"
    local confirmation_prompt="Do you want to activate ${option_name}?"

    if grep -Fxq "${option_name}" /etc/pacman.conf; then
        echo "${option_name} is already activated."
    elif grep -Fxq "${regex_check}" /etc/pacman.conf; then # Check if it's commented out
        if _gum_confirm "${confirmation_prompt}"; then
            sudo sed -i "${sed_uncomment}" /etc/pacman.conf
            echo "${option_name} activated." # Provide success feedback
        else
            echo "Activation of ${option_name} skipped."
        fi
    else
        # If it's neither active nor commented, maybe add it or inform.
        # For these specific options (Color, ParallelDownloads, VerbosePkgLists),
        # they are usually present but commented out.
        echo "WARNING: ${option_name} line not found in pacman.conf. Skipping."
    fi
}

configure_pacman_option "ParallelDownloads"
configure_pacman_option "Color"
configure_pacman_option "NoProgressBar"
configure_pacman_option "VerbosePkgLists"

if grep -Fxq "ILoveCandy" /etc/pacman.conf
then
    echo "ILoveCandy is already activated."
else
    if _gum_confirm "Do you want to activate ILoveCandy?" ;then
        sudo sed -i '/^ParallelDownloads = .*/a ILoveCandy' /etc/pacman.conf
        echo "ILoveCandy activated."
    else
        echo "Activation of ILoveCandy skipped."
    fi
fi
