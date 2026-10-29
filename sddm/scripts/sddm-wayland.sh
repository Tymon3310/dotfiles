#!/usr/bin/env bash
# Switch the SDDM greeter between Wayland (KWin) and X11.
#
#   sudo sddm/scripts/sddm-wayland.sh on    # Wayland greeter
#   sudo sddm/scripts/sddm-wayland.sh off   # back to X11 (Xsetup as before)
#
# SDDM reads its config only when the service starts, so logging out is not
# enough: reboot, or `sudo systemctl restart sddm` from a TTY or SSH (that
# ends a running desktop session).
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONF=/etc/sddm.conf.d/zz-wayland.conf
UNIT=/etc/systemd/system/sddm-impasto-helper.service
SDDM_HOME=/var/lib/sddm

if [ "$EUID" -ne 0 ]; then
    echo "Run with sudo: sudo $0 ${1:-on}" >&2
    exit 1
fi

case "${1:-}" in
on)
    install -m 644 -v "$DOTFILES_DIR/sddm/etc/sddm.conf.d/zz-wayland.conf" "$CONF"
    install -m 644 -v "$DOTFILES_DIR/sddm/systemd/sddm-impasto-helper.service" "$UNIT"
    systemctl daemon-reload
    systemctl enable sddm-impasto-helper.service

    # The greeter's KWin keeps its own monitor setup. Start it from the
    # user's (same layout and primary screen), with HDR forced off.
    user="${SUDO_USER:-}"
    src="/home/$user/.config/kwinoutputconfig.json"
    if [ -n "$user" ] && [ -f "$src" ]; then
        install -d -o sddm -g sddm "$SDDM_HOME/.config"
        python3 - "$src" "$SDDM_HOME/.config/kwinoutputconfig.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
for block in data:
    if block.get("name") == "outputs":
        for output in block["data"]:
            output["highDynamicRange"] = False
            output["wideColorGamut"] = False
json.dump(data, open(sys.argv[2], "w"), indent=4)
PY
        chown sddm:sddm "$SDDM_HOME/.config/kwinoutputconfig.json"
        echo "Copied the monitor layout from $src (HDR off)."
    fi
    echo "Wayland greeter on. Reboot (or restart sddm from a TTY) to try it; '$0 off' goes back."
    ;;
off)
    rm -fv "$CONF"
    systemctl disable sddm-impasto-helper.service 2>/dev/null || true
    rm -fv "$UNIT"
    systemctl daemon-reload
    echo "X11 greeter on (as before) from the next reboot or sddm restart."
    ;;
*)
    echo "usage: $0 on|off" >&2
    exit 2
    ;;
esac
