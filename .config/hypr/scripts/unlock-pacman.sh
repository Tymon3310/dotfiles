#!/bin/bash
sleep 1
if [ -f /var/lib/pacman/db.lck ]; then
    if pgrep -x "pacman" > /dev/null; then
        echo ":: Pacman is currently running. Cannot unlock."
        exit 1
    fi
    sudo rm /var/lib/pacman/db.lck
    echo ":: Unlock complete"
else
    echo ":: Pacman database is not locked"
fi
sleep 3