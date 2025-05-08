#!/usr/bin/env python3
"""
Waybar module: Internet connectivity status
Pings google DNS, Cloudflare DNS, and local router.
Displays latencies in status text and shows last successful ping times in tooltip.
"""
import subprocess
import time
import json
import sys

# Hosts to monitor
HOSTS = {
    'Google': '8.8.8.8',
    'Cloudflare': '1.1.1.1',
    'Router': '192.168.1.1'
}
# ping command options
COUNT = '1'
TIMEOUT = '1'  # seconds
# Stores last successful ping timestamp
last_success = { name: None for name in HOSTS }
# Stores last measured latency (ms)
last_rtt = { name: None for name in HOSTS }
# Icons for online/offline
ONLINE_ICON = "󰲝 "
OFFLINE_ICON = "<span style='color: red;'>󰲜 </span>"

# Helper: perform a single ping, return RTT in ms or None
def ping(host):
    try:
        res = subprocess.run(
            ['ping', '-c', COUNT, '-W', TIMEOUT, host],
            capture_output=True, text=True)
        if res.returncode == 0:
            # parse rtt from output: "time=X ms"
            for part in res.stdout.split():
                if 'time=' in part:
                    # e.g. time=12.3 ms
                    val = part.split('=')[1]
                    if val.endswith('ms'):
                        val = val[:-2]
                    return float(val)
    except Exception:
        pass
    return None

# Main loop
if __name__ == '__main__':
    while True:
        now = time.time()
        # Ping each host to update last success and RTT
        for name, addr in HOSTS.items():
            rtt = ping(addr)
            if rtt is not None:
                last_success[name] = now
                last_rtt[name] = rtt
        # Determine online status: any successful ping this cycle
        online = any(rtt is not None for rtt in last_rtt.values())
        text = ONLINE_ICON if online else OFFLINE_ICON
        # Build tooltip lines
        tooltip_lines = []
        for name in HOSTS:
            t = last_success[name]
            rtt = last_rtt[name]
            if t is None:
                tooltip_lines.append(f"{name}: never")
            else:
                delta = int(now - t)
                # Include last RTT in milliseconds
                if rtt is not None:
                    tooltip_lines.append(f"{name}: {delta}s ago ({int(rtt)}ms)")
                else:
                    tooltip_lines.append(f"{name}: {delta}s ago")
        tooltip = '\n'.join(tooltip_lines)
        # Output JSON
        out = {
            'text': text,
            'tooltip': tooltip
        }
        print(json.dumps(out), flush=True)
        # Sleep before next update
        time.sleep(5)
