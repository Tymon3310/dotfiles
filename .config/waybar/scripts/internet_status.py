#!/usr/bin/env python3
"""
Waybar module: Internet connectivity status (without ICMP ping)

Checks connectivity using short TCP connection attempts and measures latency.
States:
  - Online (Internet reachable: Google/Cloudflare)
  - Local only (Router reachable but Internet not)
  - Offline (Neither router nor Internet)

Outputs an icon with color (using pango markup) and a tooltip with last
successful check times and most recent RTTs.
"""
from __future__ import annotations

import json
import sys
import socket
import struct
import time
from typing import Dict, Iterable, Optional, Tuple

# ----------------------------------------------------------------------------
# Configuration
# ----------------------------------------------------------------------------

# Icons for states
ONLINE_ICON = "󰲝 "                 # Internet reachable
LOCAL_ICON = "<span color='yellow'>󰌚 </span>"  # Router only
OFFLINE_ICON = "<span color='red'>󰲜 </span>"   # No connectivity

# Per-attempt TCP timeout (seconds)
TCP_TIMEOUT = 0.8

# Refresh interval (seconds)
INTERVAL = 2

# Targets: names are displayed in tooltip
# We resolve Router dynamically from the default gateway when possible.

def _get_default_gateway() -> Optional[str]:
    """Return the default IPv4 gateway (as dotted quad) from /proc/net/route.

    Parses the kernel routing table. Returns None if not found or on error.
    """
    try:
        with open("/proc/net/route", "r", encoding="utf-8") as f:
            # Skip header
            next(f)
            for line in f:
                fields = line.strip().split()  # Iface Destination Gateway Flags RefCnt Use Metric Mask MTU Window IRTT
                if len(fields) < 3:
                    continue
                iface, dest_hex, gateway_hex = fields[0], fields[1], fields[2]
                # Default route has destination 00000000
                if dest_hex == "00000000":
                    try:
                        gw_bytes = struct.pack("<L", int(gateway_hex, 16))
                        return socket.inet_ntoa(gw_bytes)
                    except Exception:
                        continue
    except OSError:
        return None
    return None


DEFAULT_ROUTER = _get_default_gateway() or "192.168.1.1"

# Define targets with candidate hosts and ports. We'll try in order until one works.
TARGETS = {
    "Google": {
        "hosts": ("8.8.8.8",),
        "ports": (53, 443),  # DNS TCP then HTTPS
    },
    "Cloudflare": {
        "hosts": ("1.1.1.1",),
        "ports": (53, 443),
    },
    "Router": {
        "hosts": (DEFAULT_ROUTER,),
        "ports": (53, 443, 80),  # common services that respond quickly
    },
}

# Stores last successful timestamp per target (epoch seconds)
last_success: Dict[str, Optional[float]] = {name: None for name in TARGETS}
# Stores last measured RTT in milliseconds (float)
last_rtt_ms: Dict[str, Optional[float]] = {name: None for name in TARGETS}


# ----------------------------------------------------------------------------
# Connectivity checks
# ----------------------------------------------------------------------------

def tcp_check_once(host: str, port: int, timeout: float) -> Optional[float]:
    """Attempt a TCP connection and return RTT in milliseconds if successful.

    Returns None on failure or timeout.
    """
    start = time.perf_counter()
    try:
        with socket.create_connection((host, port), timeout=timeout):
            end = time.perf_counter()
            return (end - start) * 1000.0
    except (OSError, socket.timeout):
        return None


def check_target(hosts: Iterable[str], ports: Iterable[int], timeout: float) -> Tuple[bool, Optional[float]]:
    """Try multiple (host, port) combos; return (ok, best_rtt_ms).

    Tries hosts in order; for each host, tries ports in order. Returns on first
    success; otherwise returns (False, None).
    """
    best: Optional[float] = None
    for h in hosts:
        for p in ports:
            rtt = tcp_check_once(h, p, timeout)
            if rtt is not None:
                best = rtt if best is None else min(best, rtt)
                # Return immediately on first success to keep loop fast
                return True, best
    return False, None


# ----------------------------------------------------------------------------
# Main loop
# ----------------------------------------------------------------------------

if __name__ == "__main__":
    while True:
        now = time.time()

        # Per-iteration current connectivity flags (do not rely on prior state)
        current_ok: Dict[str, bool] = {}

        # Evaluate each target once per cycle
        for name, cfg in TARGETS.items():
            ok, rtt = check_target(cfg["hosts"], cfg["ports"], TCP_TIMEOUT)
            current_ok[name] = ok
            if ok:
                last_success[name] = now
                last_rtt_ms[name] = rtt
            else:
                # Reset RTT so state reflects current failures
                last_rtt_ms[name] = None

        # Determine overall state based on CURRENT results
        internet_online = any(current_ok.get(n, False) for n in ("Google", "Cloudflare"))
        router_only = (not internet_online) and current_ok.get("Router", False)
        offline = (not internet_online) and (not router_only)

        if internet_online:
            text = ONLINE_ICON
            css_class = "online"
        elif router_only:
            text = LOCAL_ICON
            css_class = "local"
        else:
            text = OFFLINE_ICON
            css_class = "offline"

        # Build tooltip with last success ago and latest measured RTT
        tooltip_lines = []
        for name in ("Google", "Cloudflare", "Router"):
            t = last_success.get(name)
            rtt = last_rtt_ms.get(name)
            if t is None:
                tooltip_lines.append(f"{name}: never")
            else:
                delta = int(now - t)
                if rtt is not None:
                    tooltip_lines.append(f"{name}: {delta}s ago ({int(rtt)}ms)")
                else:
                    tooltip_lines.append(f"{name}: {delta}s ago")
        tooltip = "\n".join(tooltip_lines)

        out = {
            "text": text,
            "tooltip": tooltip,
            # Optional: allow styling via Waybar CSS on class
            "class": css_class,
        }
        try:
            print(json.dumps(out), flush=True)
        except BrokenPipeError:
            # When the consumer (e.g., `head`) closes the pipe, exit cleanly
            sys.exit(0)

        try:
            time.sleep(INTERVAL)
        except KeyboardInterrupt:
            sys.exit(0)
