#!/bin/bash
#  ___           _        _ _   _   _           _       _
# |_ _|_ __  ___| |_ __ _| | | | | | |_ __   __| | __ _| |_ ___  ___
#  | || '_ \/ __| __/ _` | | | | | | | '_ \ / _` |/ _` | __/ _ \/ __|
#  | || | | \__ \ || (_| | | | | |_| | |_) | (_| | (_| | ||  __/\__ \
# |___|_| |_|___/\__\__,_|_|_|  \___/| .__/ \__,_|\__,_|\__\___||___/
#                                    |_|

sleep 1
clear
figlet -f smslant "Updates"
echo

# ------------------------------------------------------
# Confirm Start
# ------------------------------------------------------

# if gum confirm "DO YOU WANT TO START THE UPDATE NOW?" ;then
#     echo
#     echo ":: Update started."
# elif [ $? -eq 130 ]; then
#         exit 130
# else
#     echo
#     echo ":: Update canceled."
#     exit;
# fi

# if [[ $(_isInstalledAUR "timeshift") == "1" ]] ;then
#     if gum confirm "DO YOU WANT TO CREATE A SNAPSHOT?" ;then
#         echo
#         c=$(gum input --placeholder "Enter a comment for the snapshot...")
#         sudo timeshift --create --comments "$c"
#         sudo timeshift --list
#         sudo grub-mkconfig -o /boot/grub/grub.cfg
#         echo ":: DONE. Snapshot $c created!"
#         echo
#     elif [ $? -eq 130 ]; then
#         echo ":: Snapshot canceled."
#         exit 130
#     else
#         echo ":: Snapshot canceled."
#     fi
#     echo
# fi

yay

flatpak update

# notify-send "Update complete"
echo
echo ":: Update complete"
echo
echo

echo "Press [ENTER] to close."
read
