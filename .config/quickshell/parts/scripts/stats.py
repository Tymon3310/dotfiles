#!/usr/bin/env python3

# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   S T A T S                                                              │
# │   one snapshot of what the machine is doing                              │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""CPU, memory, disk, network and temperature from /proc and /sys.

Read from the kernel directly, so there is no locale- or version-dependent
output to parse. CPU and network are rates and need two samples.

`stats.py` prints one reading and exits. `stats.py watch <seconds>` stays
resident and prints a line per interval, so the shell can keep a history
without paying Python's start-up on every tick. The sampling interval is set
here either way, not by however often the caller happens to ask.
"""

import glob
import json
import os
import shutil
import subprocess
import sys
import time

SAMPLE_WINDOW = 0.25

# While watching, disks are re-read only every SLOW_EVERY
# intervals: they cost about 16 ms, against 0.1 ms for all the rates and
# sensors together, and they barely change.
SLOW_EVERY = 10


def read(path):
    try:
        with open(path, encoding="utf-8") as handle:
            return handle.read()
    except OSError:
        return ""


def cpu_times():
    """Busy and total jiffies for the package and for each core."""
    entries = []
    for line in read("/proc/stat").splitlines():
        if not line.startswith("cpu"):
            break
        fields = line.split()
        values = [int(value) for value in fields[1:]]
        if len(values) < 4:
            continue
        idle = values[3] + (values[4] if len(values) > 4 else 0)
        total = sum(values)
        entries.append((total - idle, total))
    return entries


VIRTUAL_PREFIXES = ("tailscale", "wg", "tun", "tap", "vmnet", "virbr",
                    "docker", "br-", "veth", "zt")


def network_bytes():
    received = transmitted = 0
    for line in read("/proc/net/dev").splitlines()[2:]:
        name, _, rest = line.partition(":")
        name = name.strip()
        # Loopback traffic never leaves the machine, and tunnels, bridges and
        # VM adapters carry traffic the physical link already counts.
        if name == "lo" or name.startswith(VIRTUAL_PREFIXES):
            continue
        fields = rest.split()
        if len(fields) >= 9:
            received += int(fields[0])
            transmitted += int(fields[8])
    return received, transmitted


def memory():
    values = {}
    for line in read("/proc/meminfo").splitlines():
        key, _, rest = line.partition(":")
        parts = rest.split()
        if parts:
            values[key] = int(parts[0]) * 1024

    total = values.get("MemTotal", 0)
    available = values.get("MemAvailable", 0)
    swap_total = values.get("SwapTotal", 0)
    swap_free = values.get("SwapFree", 0)
    return {
        "total": total,
        # Total minus available, not minus free: cache and buffers are
        # reclaimable and should not count as used.
        "used": total - available,
        "swapTotal": swap_total,
        "swapUsed": swap_total - swap_free,
    }


def disks():
    if not shutil.which("df"):
        return []
    try:
        result = subprocess.run(
            ["df", "-B1", "--output=target,size,used,fstype"],
            capture_output=True, text=True, timeout=10,
        )
    except (OSError, subprocess.SubprocessError):
        return []

    skip = {"tmpfs", "devtmpfs", "squashfs", "overlay", "efivarfs", "ramfs"}
    entries = []
    for line in result.stdout.splitlines()[1:]:
        fields = line.split()
        if len(fields) < 4:
            continue
        target, size, used, fstype = fields[0], fields[1], fields[2], fields[3]
        if fstype in skip or not size.isdigit() or int(size) == 0:
            continue
        entries.append({
            "target": target,
            "total": int(size),
            "used": int(used),
        })
    entries.sort(key=lambda entry: -entry["total"])
    return entries[:4]


# ── SENSORS ──────────────────────────────────────────────────────────────────
#
# Found once, then read every tick: a read is one small sysfs file.

# CPU drivers and the label of their package reading, best first.
CPU_SENSORS = [("zenpower", ("Tctl", "Tdie")), ("k10temp", ("Tctl", "Tdie")),
               ("coretemp", ("Package id 0",)), ("cpu_thermal", ("",))]
# Never the CPU, however hot: the fallback skips these.
NOT_CPU = ("amdgpu", "nouveau", "nvme", "iwlwifi", "r8169", "acpitz", "ucsi")

_sensors = None


def hwmon_temps():
    """(driver, label, path) for every temperature input."""
    found = []
    for path in sorted(glob.glob("/sys/class/hwmon/hwmon*/temp*_input")):
        folder = os.path.dirname(path)
        name = read(os.path.join(folder, "name")).strip()
        label = read(path.replace("_input", "_label")).strip()
        found.append((name, label, path))
    return found


def find_sensors():
    temps = hwmon_temps()

    cpu = None
    for driver, labels in CPU_SENSORS:
        for name, label, path in temps:
            if name == driver and (label in labels or labels == ("",)):
                cpu = {"path": path, "label": label or name}
                break
        if cpu:
            break
    if cpu is None:
        # Hottest plausible sensor that is not a known other device.
        best = None
        for name, label, path in temps:
            if name.startswith(NOT_CPU):
                continue
            value = celsius_at(path)
            if value is not None and (best is None or value > best[0]):
                best = (value, {"path": path, "label": label or name})
        cpu = best[1] if best else None

    # The first GPU that reports its load (amdgpu does; others would need a
    # vendor tool).
    gpu = None
    for card in sorted(glob.glob("/sys/class/drm/card[0-9]*/device")):
        busy = os.path.join(card, "gpu_busy_percent")
        if not os.path.exists(busy):
            continue
        gpu = {
            "busy": busy,
            "vramUsed": os.path.join(card, "mem_info_vram_used"),
            "vramTotal": os.path.join(card, "mem_info_vram_total"),
            "temps": {},
        }
        for path in glob.glob(os.path.join(card, "hwmon", "hwmon*", "temp*_input")):
            label = read(path.replace("_input", "_label")).strip() or "edge"
            gpu["temps"][label] = path
        break

    return {"cpu": cpu, "gpu": gpu}


def celsius_at(path):
    raw = read(path).strip()
    if not raw.lstrip("-").isdigit():
        return None
    value = int(raw) / 1000
    return round(value, 1) if 5 < value < 125 else None


def sensors():
    global _sensors
    if _sensors is None:
        _sensors = find_sensors()
    return _sensors


def temperature():
    """The CPU package temperature, from the CPU's own driver when present."""
    cpu = sensors()["cpu"]
    if not cpu:
        return None
    value = celsius_at(cpu["path"])
    return {"celsius": value, "label": cpu["label"]} if value is not None else None


def integer_at(path):
    raw = read(path).strip()
    return int(raw) if raw.isdigit() else None


def gpu():
    """Load, video memory and temperatures of the first GPU that reports them."""
    found = sensors()["gpu"]
    if not found:
        return None
    temps = {label: celsius_at(path) for label, path in found["temps"].items()}
    return {
        "usage": integer_at(found["busy"]) or 0,
        "vramUsed": integer_at(found["vramUsed"]) or 0,
        "vramTotal": integer_at(found["vramTotal"]) or 0,
        # "edge" is the die as vendors quote it; junction is its hottest spot.
        "temperature": temps.get("edge"),
        "junction": temps.get("junction"),
        "memoryTemperature": temps.get("mem"),
    }


def counters():
    """The raw totals a rate is the difference of, and when they were read."""
    return (time.monotonic(), cpu_times(), network_bytes())


def slow_readings():
    """The part worth re-reading rarely: what is mounted."""
    return {"disks": disks()}


def report(before, after, slow=None):
    """One reading, with every rate measured across the two samples given."""
    if slow is None:
        slow = slow_readings()
    span = max(1e-6, after[0] - before[0])
    first_cpu, first_net = before[1], before[2]
    second_cpu, second_net = after[1], after[2]

    usages = []
    for (busy_a, total_a), (busy_b, total_b) in zip(first_cpu, second_cpu):
        jiffies = total_b - total_a
        usages.append(round((busy_b - busy_a) / jiffies * 100, 1) if jiffies > 0 else 0.0)

    load = read("/proc/loadavg").split()[:3]
    uptime = read("/proc/uptime").split()
    model = ""
    for line in read("/proc/cpuinfo").splitlines():
        if line.startswith("model name"):
            model = line.partition(":")[2].strip()
            break

    return {
        "cpu": {
            "total": usages[0] if usages else 0.0,
            "cores": usages[1:],
            "model": model,
            "load": [float(value) for value in load] if len(load) == 3 else [0, 0, 0],
        },
        "memory": memory(),
        "disks": slow["disks"],
        "network": {
            "down": max(0, int((second_net[0] - first_net[0]) / span)),
            "up": max(0, int((second_net[1] - first_net[1]) / span)),
        },
        "temperature": temperature(),
        "gpu": gpu(),
        "uptime": int(float(uptime[0])) if uptime else 0,
    }


def snapshot():
    """A single reading, for a caller that wants one and then goes away."""
    before = counters()
    time.sleep(SAMPLE_WINDOW)
    return report(before, counters())


def watch(interval):
    """One line per interval, forever. The reader decides when to stop."""
    before = counters()
    slow = slow_readings()
    tick = 0
    while True:
        time.sleep(interval)
        after = counters()
        tick += 1
        if tick % SLOW_EVERY == 0:
            slow = slow_readings()
        print(json.dumps(report(before, after, slow)), flush=True)
        before = after


if __name__ == "__main__":
    try:
        if len(sys.argv) > 1 and sys.argv[1] == "watch":
            watch(float(sys.argv[2]) if len(sys.argv) > 2 else 3.0)
        else:
            print(json.dumps(snapshot()))
    except (KeyboardInterrupt, BrokenPipeError):
        # The reader closed the pipe.
        pass
    except Exception as error:  # a stats panel must never take the shell down
        sys.stderr.write(f"stats failed: {error}\n")
        print(json.dumps({}))
