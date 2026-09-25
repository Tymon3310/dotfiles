#!/usr/bin/env python3
import evdev
import glob
import json
import os
import select
import subprocess
import sys
import time


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

def read_hypr_locks():
    try:
        out = subprocess.check_output(['hyprctl', 'devices', '-j'], timeout=0.5).decode('utf-8')
        data = json.loads(out)
        for kb in data.get('keyboards', []):
            if kb.get('main'):
                return kb.get('capsLock', False), kb.get('numLock', False)
        # Fallback to any keyboard
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
    # 1. Check evdev leds()
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

    # 2. Check sysfs
    sys_caps, sys_num = read_sysfs_locks()

    # 3. Check hyprctl, only as a fallback
    hypr_caps, hypr_num = read_hypr_locks() if ask_hyprland else (None, None)

    final_caps = evdev_caps or sys_caps or (hypr_caps is True)
    final_num = evdev_num or sys_num or (hypr_num is True)

    return final_caps, final_num

def open_keyboards():
    devices = []
    for path in evdev.list_devices():
        try:
            dev = evdev.InputDevice(path)
            caps = dev.capabilities().get(evdev.ecodes.EV_KEY, [])
            led_caps = dev.capabilities().get(evdev.ecodes.EV_LED, [])
            if evdev.ecodes.KEY_CAPSLOCK in caps or evdev.ecodes.KEY_NUMLOCK in caps or led_caps:
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

def has_leds(devices):
    """Whether evdev or sysfs can report the lock LEDs at all."""
    if glob.glob('/sys/class/leds/*::capslock/brightness'):
        return True
    return any(evdev.ecodes.EV_LED in dev.capabilities() for dev in devices)


def main():
    die_with_parent()
    devices = open_keyboards()
    leds = has_leds(devices)
    last_caps, last_num = query_state(devices, ask_hyprland=not leds)

    print(json.dumps({"type": "init", "caps": last_caps, "num": last_num}), flush=True)

    last_scan_time = time.time()

    while True:
        try:
            # Rescan devices periodically every 15 seconds
            now = time.time()
            if now - last_scan_time > 15.0 or not devices:
                close_devices(devices)
                devices = open_keyboards()
                leds = has_leds(devices)
                last_scan_time = now

            # Select on devices with a 100ms timeout
            r, _, _ = select.select(devices, [], [], 0.1)

            key_triggered = False
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
                            elif ev.type == evdev.ecodes.EV_LED:
                                key_triggered = True
                    except (BlockingIOError, OSError):
                        pass

            # If a lock key or LED was triggered, poll quickly over 120ms to catch state transition
            if key_triggered:
                for _ in range(4):
                    time.sleep(0.03)
                    cur_caps, cur_num = query_state(devices, ask_hyprland=not leds)
                    if cur_caps != last_caps or cur_num != last_num:
                        break
            elif leds:
                cur_caps, cur_num = query_state(devices)
            else:
                # Nothing to poll without LEDs; Hyprland is asked on a key.
                cur_caps, cur_num = last_caps, last_num

            if cur_caps != last_caps:
                last_caps = cur_caps
                print(json.dumps({"type": "caps", "state": cur_caps}), flush=True)

            if cur_num != last_num:
                last_num = cur_num
                print(json.dumps({"type": "num", "state": cur_num}), flush=True)

        except KeyboardInterrupt:
            break
        except Exception as e:
            sys.stderr.write(f"Lock monitor error: {e}\n")
            time.sleep(1)
            close_devices(devices)
            devices = open_keyboards()

    close_devices(devices)

if __name__ == "__main__":
    main()
