#!/usr/bin/env python3
import ctypes
import glob
import json
import os
import select
import signal
import subprocess
import sys
import time

DEVICES = "/dev/video*"
SETTLE = 0.25
BROKERS = {"pipewire", "wireplumber"}


def holders(devices):
    found = set()
    for fd_dir in glob.glob("/proc/[0-9]*/fd"):
        try:
            links = [os.readlink(os.path.join(fd_dir, fd)) for fd in os.listdir(fd_dir)]
        except OSError:
            continue
        if not any(link in devices for link in links):
            continue
        pid_dir = os.path.dirname(fd_dir)
        try:
            with open(os.path.join(pid_dir, "comm"), encoding="utf-8") as source:
                name = source.read().strip()
        except OSError:
            continue
        found.add("pipewire" if name in BROKERS else name)
    return sorted(found)


def report(devices, last):
    now = holders(devices)
    if now != last:
        print(json.dumps({"camera": now}), flush=True)
    return now


def die_with_parent():
    try:
        libc = ctypes.CDLL(None, use_errno=True)
        libc.prctl(1, signal.SIGTERM)  # PR_SET_PDEATHSIG
    except Exception:
        pass


def read_burst(stream):
    try:
        data = os.read(stream, 4096)
        if not data:
            return None
        while select.select([stream], [], [], SETTLE)[0]:
            more = os.read(stream, 4096)
            if not more:
                return None
            data += more
        return data
    except Exception:
        return None


def main():
    devices = set(glob.glob(DEVICES))
    last = report(devices, None)
    if not devices:
        # Fallback polling if no devices at startup or inotifywait not available
        while True:
            time.sleep(3)
            devices = set(glob.glob(DEVICES))
            last = report(devices, last)

    try:
        watch = subprocess.Popen(
            ["inotifywait", "-m", "-q", "-e", "open,close", "--format", "%w %e", *sorted(devices)],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            preexec_fn=die_with_parent,
        )
    except FileNotFoundError:
        # Fallback if inotifywait missing
        while True:
            time.sleep(2)
            last = report(devices, last)

    if watch.stdout is None:
        return
    stream = watch.stdout.fileno()
    held = dict.fromkeys(devices, 0)
    seen = dict(held)
    pending = b""
    while (burst := read_burst(stream)) is not None:
        *lines, pending = (pending + burst).split(b"\n")
        for line in lines:
            device, _, events = line.decode(errors="replace").partition(" ")
            if device in held:
                held[device] += 1 if events.startswith("OPEN") else -1
        if held != seen:
            seen = dict(held)
            last = report(devices, last)


if __name__ == "__main__":
    try:
        main()
    except (KeyboardInterrupt, BrokenPipeError):
        sys.exit(0)
