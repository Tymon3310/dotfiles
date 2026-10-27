#!/usr/bin/env python3
"""OSD event monitors for Quickshell / Morphing Island.

Single entry point for the transient-event daemons behind OsdService:

    osd.py locks    Caps/Num Lock from keyboard LEDs (evdev + sysfs)
    osd.py headset  JBL Quantum wireless headset (mute, battery, connection)

Each mode prints one JSON object per line on stdout. QML owners:

    locks    -> OsdService (lock monitor Process)
    headset  -> HeadsetService (headset monitor Process)
"""

import glob
import json
import os
import select
import subprocess
import sys
import time

try:
    import evdev
except ImportError:
    evdev = None


def die_with_parent():
    """Exit when the shell that started us does, instead of lingering as an
    orphan after a crash or restart (Linux: PR_SET_PDEATHSIG)."""
    try:
        import ctypes
        import signal
        libc = ctypes.CDLL("libc.so.6", use_errno=True)
        libc.prctl(1, signal.SIGTERM)  # PR_SET_PDEATHSIG
        if os.getppid() == 1:  # the parent was already gone
            sys.exit(0)
    except Exception:
        pass


def emit(event) -> None:
    sys.stdout.write(json.dumps(event) + "\n")
    sys.stdout.flush()



def read_hypr_locks():
    try:
        out = subprocess.check_output(['hyprctl', 'devices', '-j'], timeout=0.5).decode('utf-8')
        data = json.loads(out)
        for kb in data.get('keyboards', []):
            if kb.get('main'):
                return kb.get('capsLock', False), kb.get('numLock', False)
        for kb in data.get('keyboards', []):
            if kb.get('capsLock') or kb.get('numLock'):
                return kb.get('capsLock', False), kb.get('numLock', False)
    except Exception:
        pass
    return None, None


def read_sysfs_locks():
    caps = False
    num = False
    try:
        for p in glob.glob('/sys/class/leds/*::capslock/brightness'):
            try:
                with open(p, 'r') as f:
                    if int(f.read().strip()) > 0:
                        caps = True
                        break
            except Exception:
                pass
    except Exception:
        pass

    try:
        for p in glob.glob('/sys/class/leds/*::numlock/brightness'):
            try:
                with open(p, 'r') as f:
                    if int(f.read().strip()) > 0:
                        num = True
                        break
            except Exception:
                pass
    except Exception:
        pass

    return caps, num


def query_state(devices, ask_hyprland=False):
    """Caps and Num Lock from the keyboards' LEDs and sysfs. Hyprland is only
    asked when asked to (after a lock key, with no LED to read): every
    `hyprctl` call is a process, and this runs ten times a second."""
    evdev_caps = False
    evdev_num = False
    for dev in devices:
        try:
            active_leds = dev.leds()
            if evdev.ecodes.LED_CAPSL in active_leds:
                evdev_caps = True
            if evdev.ecodes.LED_NUML in active_leds:
                evdev_num = True
        except Exception:
            pass

    sys_caps, sys_num = read_sysfs_locks()

    hypr_caps, hypr_num = read_hypr_locks() if ask_hyprland else (None, None)

    final_caps = evdev_caps or sys_caps or (hypr_caps is True)
    final_num = evdev_num or sys_num or (hypr_num is True)

    return final_caps, final_num


# Devices that can never report Caps/Num Lock meaningfully, even though
# they expose EV_KEY or EV_LED: headset dongles (a single LED_MISC), mice
# with remappable buttons, macro pads, virtual keyboards, ...
LOCKS_NAME_DENYLIST = (
    "jbl", "quantum", "harman", "headset", "headphone", "dongle",
    "webcam", "elgato", "stream deck",
)


def device_usable(dev) -> bool:
    """Whether an input device can genuinely report lock-key state.

    Requires a real lock key (Caps/Num) AND a real lock LED. This excludes
    headset dongles (LED_MISC only, no lock keys), mice with remappable
    buttons, and virtual macro pads (keys, no LEDs): none of them can ever
    change the Caps/Num Lock state, but every USB disconnect/reconnect of
    such a device used to churn the monitored device set.
    """
    try:
        name = (dev.name or "").lower()
    except Exception:
        return False
    if any(key in name for key in LOCKS_NAME_DENYLIST):
        return False
    try:
        caps = dev.capabilities()
    except Exception:
        return False
    keys = caps.get(evdev.ecodes.EV_KEY, [])
    leds = caps.get(evdev.ecodes.EV_LED, [])
    if evdev.ecodes.KEY_CAPSLOCK not in keys and evdev.ecodes.KEY_NUMLOCK not in keys:
        return False
    if evdev.ecodes.LED_CAPSL not in leds and evdev.ecodes.LED_NUML not in leds:
        return False
    return True


def open_keyboards(exclude=()):
    devices = []
    excluded = set(exclude)
    for path in evdev.list_devices():
        if path in excluded:
            continue
        try:
            dev = evdev.InputDevice(path)
            if device_usable(dev):
                # Crucial: set non-blocking so dev.read() never hangs!
                os.set_blocking(dev.fd, False)
                devices.append(dev)
            else:
                dev.close()
        except Exception:
            continue
    return devices


def close_devices(devices):
    for dev in devices:
        try:
            dev.close()
        except Exception:
            pass


def prune_dead(devices) -> bool:
    """Drop devices whose /dev/input node vanished (USB disconnect).

    Returns True when the monitored set changed. Stale fds left in the
    list would read as "no LEDs", which the state query would mistake
    for locks turning off.
    """
    alive = []
    changed = False
    for dev in devices:
        try:
            if os.path.exists(dev.path):
                alive.append(dev)
                continue
        except Exception:
            pass
        try:
            dev.close()
        except Exception:
            pass
        changed = True
    devices[:] = alive
    return changed


def has_leds(devices):
    """Whether evdev or sysfs can report the lock LEDs at all."""
    if glob.glob('/sys/class/leds/*::capslock/brightness'):
        return True
    for dev in devices:
        try:
            if evdev.ecodes.EV_LED in dev.capabilities():
                return True
        except Exception:
            # Device vanished mid-query (USB disconnect); prune handles it.
            continue
    return False


def locks_main():
    if evdev is None:
        sys.stderr.write("osd.py locks: python-evdev is not installed\n")
        sys.exit(1)
    die_with_parent()
    devices = open_keyboards()
    leds = has_leds(devices)
    last_caps, last_num = query_state(devices, ask_hyprland=not leds)

    emit({"type": "init", "caps": last_caps, "num": last_num})

    last_scan_time = time.time()

    # Monotonic time of the last observed Caps/Num Lock keypress. State
    # changes are only reported within a short window after such a press;
    # everything else (login defaults being applied, VT switches, device
    # quirks, transient misreads) converges silently. LED events alone do
    # not arm reporting: applying a default also emits one.
    last_lock_key_at = 0.0
    LOCK_KEY_WINDOW = 1.0

    while True:
        try:
            # Drop vanished USB devices immediately (their fds would read
            # as "no LEDs") and pick up replacements without waiting for
            # the periodic rescan.
            devices_changed = prune_dead(devices)
            if devices_changed:
                known = set(dev.path for dev in devices)
                devices.extend(open_keyboards(exclude=known))
                leds = has_leds(devices)

            # Rescan devices periodically (15s when active, 5s throttle when no devices accessible)
            now = time.time()
            if now - last_scan_time > (5.0 if not devices else 15.0):
                known = set(dev.path for dev in devices)
                fresh = open_keyboards(exclude=known)
                if fresh:
                    devices.extend(fresh)
                    devices_changed = True
                leds = has_leds(devices)
                last_scan_time = now

            r, _, _ = select.select(devices, [], [], 0.1) if devices else ([], [], [])

            key_triggered = False
            led_event = False
            if r:
                for dev in r:
                    try:
                        while True:
                            ev = dev.read_one()
                            if ev is None:
                                break
                            if ev.type == evdev.ecodes.EV_KEY and ev.value == 1:
                                if ev.code in (evdev.ecodes.KEY_CAPSLOCK, evdev.ecodes.KEY_NUMLOCK):
                                    key_triggered = True
                                    last_lock_key_at = time.monotonic()
                            elif ev.type == evdev.ecodes.EV_LED:
                                # Wakes the quick poll below, but does NOT
                                # arm reporting on its own.
                                led_event = True
                    except (BlockingIOError, OSError):
                        pass

            # After a lock keypress (or LED event), poll quickly over 120ms
            # to catch the state transition.
            if key_triggered or led_event:
                for _ in range(4):
                    time.sleep(0.03)
                    if prune_dead(devices):
                        devices_changed = True
                    cur_caps, cur_num = query_state(devices, ask_hyprland=not leds)
                    if cur_caps != last_caps or cur_num != last_num:
                        break
            elif leds:
                cur_caps, cur_num = query_state(devices)
            else:
                # Nothing to poll without LEDs; Hyprland is asked on a key.
                cur_caps, cur_num = last_caps, last_num

            # A changed device set means reporters came or went (USB
            # re-enumeration): re-baseline silently instead of flashing
            # phantom Caps/Num Lock OSDs for hardware that vanished.
            if devices_changed:
                last_caps, last_num = cur_caps, cur_num
                continue

            # No lock keypress behind this change: drift, not input.
            # Converge silently instead of flashing a phantom OSD.
            if time.monotonic() - last_lock_key_at >= LOCK_KEY_WINDOW:
                last_caps, last_num = cur_caps, cur_num
                continue

            if cur_caps != last_caps:
                last_caps = cur_caps
                emit({"type": "caps", "state": cur_caps})

            if cur_num != last_num:
                last_num = cur_num
                emit({"type": "num", "state": cur_num})

        except KeyboardInterrupt:
            break
        except Exception as e:
            sys.stderr.write(f"Lock monitor error: {e}\n")
            time.sleep(1)
            close_devices(devices)
            devices = open_keyboards()

    close_devices(devices)


# Tracks wireless headset state (mute status, battery milestones, connection)
# exported by jbl-quantum-tray daemon into /run/user/<uid>/jbl_quantum.

UID = os.getuid()
JBL_DIR = os.environ.get("JBL_QUANTUM_DIR", f"/run/user/{UID}/jbl_quantum")

MILESTONES = [100, 75, 50, 30, 20, 15, 10, 5]

# A USB re-enumeration flaps `connected` for a moment; only stable changes
# are reported, so a flapping hub does not strobe the island.
CONNECTION_STABLE_SECS = 2.0


def read_file(filename: str, default: str = "") -> str:
    path = os.path.join(JBL_DIR, filename)
    try:
        with open(path, "r", encoding="utf-8") as f:
            return f.read().strip()
    except Exception:
        return default


def usb_charge_cable_connected() -> bool:
    """The Quantum 610 exposes a second HID device when its charge cable is
    plugged into this PC: USB VID:PID 0ecb:205b (Wireless headphone)."""
    for device_dir in glob.glob("/sys/bus/usb/devices/*"):
        try:
            with open(os.path.join(device_dir, "idVendor"), "r", encoding="utf-8") as f:
                vendor = f.read().strip().lower()
            with open(os.path.join(device_dir, "idProduct"), "r", encoding="utf-8") as f:
                product = f.read().strip().lower()
            if vendor == "0ecb" and product == "205b":
                return True
        except OSError:
            # Interface and hub entries do not have both descriptor files.
            continue
    return False


def headset_main() -> None:
    die_with_parent()
    last_connected = None
    last_mic_muted = None
    last_battery = None
    last_charging = None
    conn_candidate = None
    conn_candidate_since = 0.0
    usb_charge_candidate = None
    usb_charge_candidate_since = 0.0
    usb_charge_stable = False
    last_usb_poll = 0.0
    usb_charge_raw = False
    first_run = True

    while True:
        try:
            now = time.monotonic()
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
                exported_charging = (charge_str == "1")
                if first_run or (now - last_usb_poll >= 1.0):
                    usb_charge_raw = usb_charge_cable_connected()
                    last_usb_poll = now
                if usb_charge_raw != usb_charge_candidate:
                    usb_charge_candidate = usb_charge_raw
                    usb_charge_candidate_since = now
                elif now - usb_charge_candidate_since >= 1.0:
                    usb_charge_stable = usb_charge_candidate
                charging = exported_charging or usb_charge_stable

                if first_run:
                    last_connected = connected
                    conn_candidate = connected
                    last_mic_muted = mic_muted
                    last_battery = battery
                    last_charging = charging
                    first_run = False
                    emit({
                        "type": "init",
                        "connected": connected,
                        "model": model,
                        "mic_muted": mic_muted,
                        "battery": battery,
                        "charging": charging
                    })
                else:
                    # 1. Connection change (debounced: USB re-enumeration
                    # flaps this for a moment; only stable changes show)
                    if connected != last_connected:
                        if connected != conn_candidate:
                            conn_candidate = connected
                            conn_candidate_since = now
                        elif now - conn_candidate_since >= CONNECTION_STABLE_SECS:
                            last_connected = connected
                            conn_candidate = connected
                            if connected:
                                emit({
                                    "type": "connection",
                                    "connected": True,
                                    "model": model,
                                    "battery": battery
                                })
                            else:
                                emit({
                                    "type": "connection",
                                    "connected": False,
                                    "model": model
                                })
                    else:
                        conn_candidate = connected

                    if connected and mic_muted != last_mic_muted:
                        last_mic_muted = mic_muted
                        emit({
                            "type": "mic_mute",
                            "muted": mic_muted,
                            "model": model
                        })

                    if connected and charging != last_charging:
                        last_charging = charging
                        emit({
                            "type": "charging",
                            "charging": charging,
                            "battery": battery,
                            "model": model
                        })

                    if connected and battery is not None and last_battery is not None and battery != last_battery:
                        emit({
                            "type": "battery",
                            "battery": battery,
                            "charging": charging,
                            "model": model
                        })

                        for m in MILESTONES:
                            crossed_down = (last_battery > m and battery <= m)
                            crossed_up = (charging and last_battery < m and battery >= m)
                            exact_hit = (battery == m and last_battery != m)

                            if crossed_down or crossed_up or exact_hit:
                                emit({
                                    "type": "battery_milestone",
                                    "milestone": m,
                                    "battery": battery,
                                    "charging": charging,
                                    "model": model
                                })
                                break
                        last_battery = battery
                    elif battery is not None:
                        last_battery = battery
            elif not first_run and last_connected:
                # The tray daemon may remove its export directory entirely
                # when the headset disconnects. Treat that as a connection
                # transition too (debounced like the file-backed one);
                # HeadsetService forwards it to OsdService.
                if conn_candidate is not False:
                    conn_candidate = False
                    conn_candidate_since = now
                elif now - conn_candidate_since >= CONNECTION_STABLE_SECS:
                    last_connected = False
                    conn_candidate = False
                    last_battery = None
                    last_charging = False
                    emit({
                        "type": "connection",
                        "connected": False,
                        "model": "Headset"
                    })
        except Exception:
            pass

        time.sleep(0.1)


if __name__ == "__main__":
    try:
        if len(sys.argv) == 2 and sys.argv[1] == "locks":
            locks_main()
        elif len(sys.argv) == 2 and sys.argv[1] == "headset":
            headset_main()
        else:
            sys.stderr.write(f"usage: {sys.argv[0]} {{locks|headset}}\n")
            sys.exit(2)
    except (KeyboardInterrupt, BrokenPipeError):
        sys.exit(0)
