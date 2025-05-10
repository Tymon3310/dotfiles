#!/bin/bash

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

_isInstalledYay() {
    local package="$1"
    yay -Q "$package" >/dev/null 2>&1
}