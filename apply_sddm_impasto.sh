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

# 1. Double check backup exists
if [ ! -d "$DOTFILES_DIR/system_backups/sddm_pam_backup" ]; then
    echo "Creating backup of current SDDM and PAM configs..."
    mkdir -p "$DOTFILES_DIR/system_backups/sddm_pam_backup"
    [ -f /etc/sddm.conf ] && cp -pv /etc/sddm.conf "$DOTFILES_DIR/system_backups/sddm_pam_backup/" || true
    [ -d /etc/sddm.conf.d ] && cp -rpv /etc/sddm.conf.d "$DOTFILES_DIR/system_backups/sddm_pam_backup/" || true
    cp -pv /etc/pam.d/sddm* "$DOTFILES_DIR/system_backups/sddm_pam_backup/" || true
    [ -f /usr/share/sddm/scripts/Xsetup ] && cp -pv /usr/share/sddm/scripts/Xsetup "$DOTFILES_DIR/system_backups/sddm_pam_backup/" || true
    [ -f /usr/share/sddm/scripts/Xstop ] && cp -pv /usr/share/sddm/scripts/Xstop "$DOTFILES_DIR/system_backups/sddm_pam_backup/" || true
fi

# 2. Install theme
echo "Installing theme to $THEME_DST..."
mkdir -p "$THEME_DST"
cp -rp "$THEME_SRC"/* "$THEME_DST"/
chmod -R 755 "$THEME_DST"

# 3. Create faces directory
mkdir -p /var/lib/impasto/faces
chmod 755 /var/lib/impasto/faces

# 4. Install UEFI helper script and integrate into SDDM Xsetup / Xstop
echo "Installing SDDM UEFI reboot helper..."
mkdir -p /usr/share/sddm/scripts
if [ -f "$DOTFILES_DIR/sddm/scripts/sddm-uefi-helper.py" ]; then
    cp -pv "$DOTFILES_DIR/sddm/scripts/sddm-uefi-helper.py" /usr/share/sddm/scripts/sddm-uefi-helper.py
    chmod 755 /usr/share/sddm/scripts/sddm-uefi-helper.py
fi

if [ -f /usr/share/sddm/scripts/Xsetup ]; then
    if ! grep -q "sddm-uefi-helper" /usr/share/sddm/scripts/Xsetup; then
        cat << 'XSETUP' >> /usr/share/sddm/scripts/Xsetup

# Reset any stale UEFI reboot state and start SDDM helper daemon
busctl call org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager SetRebootToFirmwareSetup b false 2>/dev/null || true
pkill -f sddm-uefi-helper 2>/dev/null || true
python3 /usr/share/sddm/scripts/sddm-uefi-helper.py &
XSETUP
    fi
fi

if [ -f /usr/share/sddm/scripts/Xstop ]; then
    if ! grep -q "sddm-uefi-helper" /usr/share/sddm/scripts/Xstop; then
        cat << 'XSTOP' >> /usr/share/sddm/scripts/Xstop

# Stop SDDM helper daemon
pkill -f sddm-uefi-helper 2>/dev/null || true
XSTOP
    fi
fi

# 5. Install SDDM config override & clean up competing overrides
echo "Configuring SDDM theme..."
mkdir -p /etc/sddm.conf.d

# Clean up older numbered config
rm -f /etc/sddm.conf.d/90-impasto.conf

# Use zz-impasto.conf so it sorts after all other .conf files alphabetically
cat << 'CONF' > /etc/sddm.conf.d/zz-impasto.conf
[General]
GreeterEnvironment=QML_XHR_ALLOW_FILE_READ=1

[Theme]
Current=impasto
FacesDir=/var/lib/impasto/faces
CONF
chmod 644 /etc/sddm.conf.d/zz-impasto.conf

# Disable competing Current= lines in existing configuration files
if [ -f /etc/sddm.conf.d/sddm.conf ]; then
    sed -i 's/^Current=simple-sddm/#Current=simple-sddm/' /etc/sddm.conf.d/sddm.conf
fi
if [ -f /etc/sddm.conf.d/kde_settings.conf ]; then
    sed -i 's/^Current=breeze/#Current=breeze/' /etc/sddm.conf.d/kde_settings.conf
fi

# Also set directly in /etc/sddm.conf (highest precedence)
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

# 6. Handle autologin (disable so login screen is displayed)
if [ -f /etc/sddm.conf.d/99-autologin.conf ]; then
    echo "Disabling 99-autologin.conf (renaming to 99-autologin.conf.bak) so SDDM greeter displays..."
    mv /etc/sddm.conf.d/99-autologin.conf /etc/sddm.conf.d/99-autologin.conf.bak
fi

# 7. Configure PAM for SDDM Face Unlock
echo "Configuring PAM (/etc/pam.d/sddm) with biopass face unlock..."
if ! grep -q "libbiopass_pam.so" /etc/pam.d/sddm; then
    cat << 'PAM' > /etc/pam.d/sddm
#%PAM-1.0

auth            sufficient      /usr/lib/security/libbiopass_pam.so
auth            include         system-login
auth            optional        pam_kwallet5.so

account         include         system-login

password        include         system-login

session         include         system-login
session         optional        pam_kwallet5.so
PAM
    chmod 644 /etc/pam.d/sddm
fi

# 8. Add sddm user to video group
if id sddm >/dev/null 2>&1; then
    echo "Ensuring sddm user has access to camera (video group)..."
    usermod -aG video sddm || true
fi

echo ""
echo "=== Impasto SDDM and Face Unlock setup complete! ==="
echo "You can test the greeter at any time with:"
echo "  sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/impasto"
echo ""
echo "To restore previous SDDM / PAM configs at any time, run:"
echo "  sudo $DOTFILES_DIR/system_backups/restore_sddm_backup.sh"
