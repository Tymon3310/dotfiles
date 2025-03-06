#!/bin/bash
# filepath: /home/tymon/dotfiles/.config/hypr/scripts/ascii-text.sh
# ----------------------------------------------------------
# Script to create ASCII art text using the ANSI Shadow font
# and copy the result to the clipboard
# ----------------------------------------------------------
#
# Example output with "Hello":
#
# ██╗  ██╗███████╗██╗     ██╗      ██████╗ 
# ██║  ██║██╔════╝██║     ██║     ██╔═══██╗
# ███████║█████╗  ██║     ██║     ██║   ██║
# ██╔══██║██╔══╝  ██║     ██║     ██║   ██║
# ██║  ██║███████╗███████╗███████╗╚██████╔╝
# ╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝ ╚═════╝ 


# Check if figlet is installed
if ! command -v figlet &> /dev/null; then
    echo "Error: figlet is not installed. Please install it first."
    exit 1
fi

# Display a sample of the font
echo -e "\nExample with ANSI Shadow font:\n"
figlet -f "ANSI Shadow" "Demo"
echo

# Get user input
read -p "Enter the text for ASCII encoding: " mytext

# Create or overwrite the figlet.txt file
if [ ! -f ~/figlet.txt ]; then
    touch ~/figlet.txt
fi

# Generate the ASCII art with a proper bash heredoc format
echo "cat <<\"EOF\"" > ~/figlet.txt
figlet -f "ANSI Shadow" "$mytext" >> ~/figlet.txt
echo "EOF" >> ~/figlet.txt

# Copy to clipboard
lines=$(cat ~/figlet.txt)

# Try both clipboard methods for compatibility
if command -v wl-copy &> /dev/null; then
    echo "$lines" | wl-copy
    clipboard_status="Copied to Wayland clipboard"
else
    clipboard_status="Wayland clipboard (wl-copy) not available"
fi

if command -v xclip &> /dev/null; then
    echo "$lines" | xclip -sel clip
    clipboard_status="$clipboard_status and X11 clipboard"
else
    clipboard_status="$clipboard_status. X11 clipboard (xclip) not available"
fi

echo -e "\nText copied to clipboard!"
echo "Output preview:"
echo "--------------"
figlet -f "ANSI Shadow" "$mytext"
echo "--------------"
echo "The output has been saved to ~/figlet.txt"