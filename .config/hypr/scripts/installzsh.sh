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
yay -S --needed oh-my-posh-bin

# Install Oh My Zsh if it's not already present. Run the official installer
# non-interactively only when ~/.oh-my-zsh is missing to keep this idempotent.
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "Installing Oh My Zsh..."
    # The installer may try to switch shells or start zsh; run it as a shell command.
    # Use curl with -f to fail on HTTP errors. If the installer exits non-zero,
    # continue but report the failure.
    # If we've extracted the installer locally (omz.sh), prefer running it
    # non-interactively so it doesn't exec a new zsh or try to change shell.
    OMZ_LOCAL="$SCRIPT_DIR_ZSH/omz.sh"
    if [ -x "$OMZ_LOCAL" ] || [ -f "$OMZ_LOCAL" ]; then
        echo "Running local Oh My Zsh installer: $OMZ_LOCAL (non-interactive)"
        # --unattended prevents RUNZSH/CHSH prompts, --keep-zshrc avoids overwriting existing .zshrc
        sh "$OMZ_LOCAL" --unattended --keep-zshrc || \
            echo "Warning: local Oh My Zsh installer exited with a non-zero status. You may need to run it manually."
    else
        echo "Running remote Oh My Zsh installer (non-interactive)"
        # Pass an extra empty arg as $0 when invoking via sh -c (see installer comments)
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc || \
            echo "Warning: remote Oh My Zsh installer exited with a non-zero status. You may need to run it manually."
    fi
else
    echo "Oh My Zsh already installed"
fi

install_zsh_plugin() {
    local repo_url="$1"
    # Extract repo name and strip a trailing .git if present
    local plugin_name="${repo_url##*/}"
    plugin_name="${plugin_name%.git}"
    local plugin_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/${plugin_name}"

    if [ ! -d "$plugin_dir" ]; then
        echo "Installing ${plugin_name}"
        # shallow clone to save time/disk
        git clone --depth 1 "$repo_url" "$plugin_dir"
    else
        echo "${plugin_name} already installed"
    fi
}

# Ensure common helper programs are installed so .zshrc init lines don't fail
# yay -S --needed thefuck zoxide || echo "Warning: failed to install thefuck/zoxide via yay; install them manually if needed."

# Install commonly used zsh plugins (idempotent)
install_zsh_plugin "https://github.com/zsh-users/zsh-autosuggestions"
install_zsh_plugin "https://github.com/zsh-users/zsh-syntax-highlighting.git"
install_zsh_plugin "https://github.com/zdharma-continuum/fast-syntax-highlighting.git"
install_zsh_plugin "https://github.com/zsh-users/zsh-completions"
# zsh-autocomplete is provided by marlonrichert
install_zsh_plugin "https://github.com/marlonrichert/zsh-autocomplete"