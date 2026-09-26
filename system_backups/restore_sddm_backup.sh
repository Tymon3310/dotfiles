#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/sddm_pam_backup" && pwd)"

echo "Restoring SDDM and PAM configuration from $BACKUP_DIR..."

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (or use sudo)."
    exit 1
fi

if [ -f "$BACKUP_DIR/sddm.conf" ]; then
    cp -pv "$BACKUP_DIR/sddm.conf" /etc/sddm.conf
fi

if [ -d "$BACKUP_DIR/sddm.conf.d" ]; then
    rm -rf /etc/sddm.conf.d
    cp -rpv "$BACKUP_DIR/sddm.conf.d" /etc/sddm.conf.d
fi

if [ -f "$BACKUP_DIR/sddm" ]; then
    cp -pv "$BACKUP_DIR/sddm" /etc/pam.d/sddm
fi

if [ -f "$BACKUP_DIR/sddm-autologin" ]; then
    cp -pv "$BACKUP_DIR/sddm-autologin" /etc/pam.d/sddm-autologin
fi

if [ -f "$BACKUP_DIR/sddm-greeter" ]; then
    cp -pv "$BACKUP_DIR/sddm-greeter" /etc/pam.d/sddm-greeter
fi

echo "SDDM and PAM restoration complete."
