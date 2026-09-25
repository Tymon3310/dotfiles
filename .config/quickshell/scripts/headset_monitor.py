#!/usr/bin/env python3
"""
Headset Monitor for Quickshell / Morphing Island
Monitors headset mic mute status and battery milestone levels (e.g. 75%, 50%, 30%, 15%).
Reads from /run/user/<uid>/jbl_quantum export directory maintained by jbl-quantum-tray.
"""

import json
import os
import sys
import time

UID = os.getuid()
JBL_DIR = f"/run/user/{UID}/jbl_quantum"

MILESTONES = [100, 75, 50, 30, 20, 15, 10, 5]


def read_file(filename: str, default: str = "") -> str:
    path = os.path.join(JBL_DIR, filename)
    try:
        with open(path, "r", encoding="utf-8") as f:
            return f.read().strip()
    except Exception:
        return default


def main() -> None:
    last_connected = None
    last_mic_muted = None
    last_battery = None
    last_charging = None
    first_run = True

    while True:
        try:
            if os.path.exists(JBL_DIR):
                conn_str = read_file("connected", "0")
                connected = (conn_str == "1")

                model = read_file("model_name", "Headset")

                mute_str = read_file("mic_muted", "0")
                mic_muted = (mute_str == "1")

                batt_str = read_file("battery_level", "")
                battery = None
                if batt_str.isdigit():
                    battery = int(batt_str)

                charge_str = read_file("charging", "0")
                charging = (charge_str == "1")

                if first_run:
                    last_connected = connected
                    last_mic_muted = mic_muted
                    last_battery = battery
                    last_charging = charging
                    first_run = False
                    # Emit initial state snapshot
                    sys.stdout.write(json.dumps({
                        "type": "init",
                        "connected": connected,
                        "model": model,
                        "mic_muted": mic_muted,
                        "battery": battery,
                        "charging": charging
                    }) + "\n")
                    sys.stdout.flush()
                else:
                    # 1. Connection change
                    if connected != last_connected:
                        last_connected = connected
                        if connected:
                            sys.stdout.write(json.dumps({
                                "type": "connection",
                                "connected": True,
                                "model": model,
                                "battery": battery
                            }) + "\n")
                        else:
                            sys.stdout.write(json.dumps({
                                "type": "connection",
                                "connected": False,
                                "model": model
                            }) + "\n")
                        sys.stdout.flush()

                    # 2. Mic Mute change
                    if connected and mic_muted != last_mic_muted:
                        last_mic_muted = mic_muted
                        sys.stdout.write(json.dumps({
                            "type": "mic_mute",
                            "muted": mic_muted,
                            "model": model
                        }) + "\n")
                        sys.stdout.flush()

                    # 3. Charging status change
                    if connected and charging != last_charging:
                        last_charging = charging
                        sys.stdout.write(json.dumps({
                            "type": "charging",
                            "charging": charging,
                            "battery": battery,
                            "model": model
                        }) + "\n")
                        sys.stdout.flush()

                    # 4. Battery milestone updates (e.g. 75, 50, 30, 15, etc.)
                    if connected and battery is not None and last_battery is not None and battery != last_battery:
                        for m in MILESTONES:
                            # Crossed downwards (discharging)
                            crossed_down = (last_battery > m and battery <= m)
                            # Crossed upwards (charging)
                            crossed_up = (charging and last_battery < m and battery >= m)
                            # Exact hit
                            exact_hit = (battery == m and last_battery != m)

                            if crossed_down or crossed_up or exact_hit:
                                sys.stdout.write(json.dumps({
                                    "type": "battery_milestone",
                                    "milestone": m,
                                    "battery": battery,
                                    "charging": charging,
                                    "model": model
                                }) + "\n")
                                sys.stdout.flush()
                                break
                        last_battery = battery
                    elif battery is not None:
                        last_battery = battery
        except Exception:
            pass

        time.sleep(0.1)


if __name__ == "__main__":
    try:
        main()
    except (KeyboardInterrupt, BrokenPipeError):
        sys.exit(0)
