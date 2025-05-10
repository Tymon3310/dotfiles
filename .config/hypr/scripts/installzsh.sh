#!/bin/bash

# Source shared functions
SCRIPT_DIR_ZSH=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
SHARED_FUNCTIONS_SCRIPT_ZSH="$SCRIPT_DIR_ZSH/shared-functions.sh"

if [ -f "$SHARED_FUNCTIONS_SCRIPT_ZSH" ]; then
    source "$SHARED_FUNCTIONS_SCRIPT_ZSH"
else
    echo "ERROR: Shared functions script not found at $SHARED_FUNCTIONS_SCRIPT_ZSH for installzsh.sh."
    _command_exists() { command -v "$1" >/dev/null 2>&1; }
    _isInstalledYay() { yay -Q "$1" >/dev/null 2>&1; }
    echo "Warning: Using minimal fallback helper functions in installzsh.sh (if applicable)."
fi

if [[ -z "$CALLED_BY_INSTALL_SH" ]]; then
    if _command_exists figlet; then
        figlet -f smslant "Zsh Configuration"
    elif _command_exists toilet; then
        toilet -f standard --filter border "Zsh Configuration"
    else
        echo "====================="
        echo " Zsh Configuration"
        echo "====================="
    fi
    echo # Extra empty line for spacing when run standalone
fi

echo
echo "This script will set Zsh as the default shell and install recommended plugins."
echo


# -----------------------------------------------------
# Activate zsh
# -----------------------------------------------------
# Change shell to zsh

while ! chsh -s $(which zsh); do
  echo "ERROR: Authentication failed. Please enter the correct password."
  sleep 1
done
echo "Shell is now zsh."

# Installing oh-my-posh
yay -S --needed oh-my-posh

install_zsh_plugin() {
    local repo_url="$1"
    local plugin_name="${repo_url##*/}" # Extracts "zsh-autosuggestions" from URL
    local plugin_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/${plugin_name}"

    if [ ! -d "$plugin_dir" ]; then
        echo "Installing ${plugin_name}"
        git clone "$repo_url" "$plugin_dir"
    else
        echo "${plugin_name} already installed"
    fi
}

install_zsh_plugin "https://github.com/zsh-users/zsh-autosuggestions"
install_zsh_plugin "https://github.com/zsh-users/zsh-syntax-highlighting.git"
install_zsh_plugin "https://github.com/zdharma-continuum/fast-syntax-highlighting.git"
install_zsh_plugin "https://github.com/zsh-users/zsh-completions"