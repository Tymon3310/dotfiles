#!/usr/bin/env python3
"""Round trips to a few hosts, one JSON line per interval, until killed.

    ping.py INTERVAL HOST...

Each line maps every host to its round trip in milliseconds, or -1 when the
echo went unanswered:

    {"8.8.8.8": 11.2, "1.1.1.1": 9.4, "ping.archlinux.org": -1}

Resident so the shell starts one process for as long as the pings are shown,
instead of one per host per tick: every process the shell starts is a fork of
the whole shell. The hosts are pinged in parallel, so a slow one does not hold
the others up.
"""

import json
import re
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor

TIME = re.compile(rb"time=([\d.]+)")


def ping(host):
    try:
        result = subprocess.run(["ping", "-n", "-c", "1", "-W", "1", host],
                                capture_output=True, timeout=3)
    except (OSError, subprocess.TimeoutExpired):
        return -1
    match = TIME.search(result.stdout)
    return float(match.group(1)) if match else -1


def main():
    interval = float(sys.argv[1])
    hosts = sys.argv[2:]
    with ThreadPoolExecutor(max_workers=len(hosts)) as pool:
        while True:
            started = time.monotonic()
            results = dict(zip(hosts, pool.map(ping, hosts)))
            print(json.dumps(results), flush=True)
            time.sleep(max(0, interval - (time.monotonic() - started)))


if __name__ == "__main__":
    try:
        main()
    except (KeyboardInterrupt, BrokenPipeError):
        pass
