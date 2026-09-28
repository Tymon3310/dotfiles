#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BACKUP_DIR="$DOTFILES_DIR/system_backups/sddm_pam_backup"

echo "=== Restoring SDDM & PAM Backups ==="

if [ "$EUID" -ne 0 ]; then
    echo "Please run with sudo:"
    echo "  sudo $0"
    exit 1
fi

if [ ! -d "$BACKUP_DIR" ]; then
    echo "Error: Backup directory $BACKUP_DIR not found!"
    exit 1
fi

# 1. Restore PAM configs
for pamf in "$BACKUP_DIR"/sddm*; do
    if [ -f "$pamf" ]; then
        target="/etc/pam.d/$(basename "$pamf")"
        echo "Restoring $target..."
        cp -pv "$pamf" "$target"
    fi
done

# 2. Restore SDDM configs
if [ -f "$BACKUP_DIR/sddm.conf" ]; then
    echo "Restoring /etc/sddm.conf..."
    cp -pv "$BACKUP_DIR/sddm.conf" /etc/sddm.conf
fi

if [ -d "$BACKUP_DIR/sddm.conf.d" ]; then
    echo "Restoring /etc/sddm.conf.d..."
    cp -rpv "$BACKUP_DIR/sddm.conf.d"/* /etc/sddm.conf.d/ 2>/dev/null || true
fi

# Remove impasto config override
rm -f /etc/sddm.conf.d/zz-impasto.conf /etc/sddm.conf.d/90-impasto.conf

# Re-enable autologin if it was backed up
if [ -f /etc/sddm.conf.d/99-autologin.conf.bak ]; then
    echo "Restoring 99-autologin.conf..."
    mv -v /etc/sddm.conf.d/99-autologin.conf.bak /etc/sddm.conf.d/99-autologin.conf
fi

# 3. Restore Xsetup and Xstop
if [ -f "$BACKUP_DIR/Xsetup" ]; then
    echo "Restoring /usr/share/sddm/scripts/Xsetup..."
    cp -pv "$BACKUP_DIR/Xsetup" /usr/share/sddm/scripts/Xsetup
fi

if [ -f "$BACKUP_DIR/Xstop" ]; then
    echo "Restoring /usr/share/sddm/scripts/Xstop..."
    cp -pv "$BACKUP_DIR/Xstop" /usr/share/sddm/scripts/Xstop
fi

# 4. Stop helper daemon
pkill -f sddm-uefi-helper 2>/dev/null || true
rm -f /run/sddm-helper-token

echo ""
echo "=== Restore Complete ==="
