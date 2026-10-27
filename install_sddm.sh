#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEME_SRC="$DOTFILES_DIR/sddm/themes/impasto"
THEME_DST="/usr/share/sddm/themes/impasto"

echo "=== Applying Impasto SDDM Theme & Face Unlock ==="

if [ "$EUID" -ne 0 ]; then
    echo "This script configures system files in /etc and /usr/share. Please run with sudo:"
    echo "  sudo $0"
    exit 1
fi

BACKUP_DIR="$DOTFILES_DIR/system_backups/sddm_pam_backup"
mkdir -p "$BACKUP_DIR"
backup() {
    local src="$1"
    [ -e "$src" ] || return 0
    [ -e "$BACKUP_DIR/$(basename "$src")" ] || cp -rpv "$src" "$BACKUP_DIR/"
}
backup /etc/sddm.conf
backup /etc/sddm.conf.d
for pamf in /etc/pam.d/sddm*; do backup "$pamf"; done
backup /usr/share/sddm/scripts/Xsetup
backup /usr/share/sddm/scripts/Xstop

# Provide restore script in system_backups
cp -pv "$DOTFILES_DIR/sddm/scripts/restore_sddm_backup.sh" "$DOTFILES_DIR/system_backups/restore_sddm_backup.sh"
chmod 755 "$DOTFILES_DIR/system_backups/restore_sddm_backup.sh"

echo "Installing theme to $THEME_DST..."
mkdir -p "$THEME_DST"
rm -rf "$THEME_DST"/*
cp -rp "$THEME_SRC"/* "$THEME_DST"/
find "$THEME_DST" -type d -exec chmod 755 {} +
find "$THEME_DST" -type f -exec chmod 644 {} +

mkdir -p /var/lib/impasto/faces
chmod 755 /var/lib/impasto/faces

echo "Installing SDDM UEFI reboot helper & password validation helper..."
mkdir -p /usr/share/sddm/scripts
install -m 755 -v "$DOTFILES_DIR/sddm/scripts/sddm-uefi-helper.py" /usr/share/sddm/scripts/
install -m 755 -v "$DOTFILES_DIR/sddm/scripts/check_empty_password.sh" /usr/share/sddm/scripts/

if [ -f /usr/share/sddm/scripts/Xsetup ]; then
    if ! grep -q "sddm-uefi-helper" /usr/share/sddm/scripts/Xsetup; then
        cat << 'XSETUP' >> /usr/share/sddm/scripts/Xsetup

busctl call org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager SetRebootToFirmwareSetup b false 2>/dev/null || true
pkill -f sddm-uefi-helper 2>/dev/null || true
python3 /usr/share/sddm/scripts/sddm-uefi-helper.py &
XSETUP
    fi
fi

if [ -f /usr/share/sddm/scripts/Xstop ]; then
    if ! grep -q "sddm-uefi-helper" /usr/share/sddm/scripts/Xstop; then
        cat << 'XSTOP' >> /usr/share/sddm/scripts/Xstop

pkill -f sddm-uefi-helper 2>/dev/null || true
XSTOP
    fi
fi

echo "Configuring SDDM theme..."
mkdir -p /etc/sddm.conf.d

rm -f /etc/sddm.conf.d/90-impasto.conf

# zz- prefix sorts after all other .conf files so our settings win.
# (AMD_DEBUG=nodcc in the file avoids DCC tile corruption on AMD GPUs under X11.)
install -m 644 -v "$DOTFILES_DIR/sddm/etc/sddm.conf.d/zz-impasto.conf" /etc/sddm.conf.d/zz-impasto.conf

if [ -f /etc/sddm.conf.d/sddm.conf ]; then
    sed -i 's/^Current=simple-sddm/#Current=simple-sddm/' /etc/sddm.conf.d/sddm.conf
fi
if [ -f /etc/sddm.conf.d/kde_settings.conf ]; then
    sed -i 's/^Current=breeze/#Current=breeze/' /etc/sddm.conf.d/kde_settings.conf
fi

if [ -f /etc/sddm.conf ]; then
    if grep -q "\[Theme\]" /etc/sddm.conf; then
        sed -i '/\[Theme\]/,/^\[/ s/^Current=.*/Current=impasto/' /etc/sddm.conf
    else
        cat << 'EOF_THEME' >> /etc/sddm.conf

[Theme]
Current=impasto
FacesDir=/var/lib/impasto/faces
EOF_THEME
    fi
fi

if [ -f /etc/sddm.conf.d/99-autologin.conf ]; then
    echo "Notice: /etc/sddm.conf.d/99-autologin.conf is present."
    echo "Disabling 99-autologin.conf (renaming to 99-autologin.conf.bak) so SDDM greeter displays..."
    mv /etc/sddm.conf.d/99-autologin.conf /etc/sddm.conf.d/99-autologin.conf.bak
fi

echo "Configuring PAM (/etc/pam.d/sddm) with biopass face unlock and faillock protection..."
install -m 644 -v "$DOTFILES_DIR/sddm/etc/pam.d/sddm" /etc/pam.d/sddm

if id sddm >/dev/null 2>&1; then
    echo "Ensuring sddm user has access to camera (video group)..."
    usermod -aG video sddm || true
fi

if [ -n "${SUDO_USER:-}" ]; then
    chown -R "$SUDO_USER:$SUDO_USER" "$DOTFILES_DIR/system_backups" 2>/dev/null || true
fi

echo ""
echo "=== Impasto SDDM and Face Unlock setup complete! ==="
echo "You can test the greeter at any time with:"
echo "  sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/impasto"
echo ""
echo "To restore previous SDDM / PAM configs at any time, run:"
echo "  sudo $DOTFILES_DIR/system_backups/restore_sddm_backup.sh"
