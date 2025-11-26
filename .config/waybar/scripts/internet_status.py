#!/usr/bin/python3
import json
import sys
import socket
import time
import struct
import signal
from gi.repository import GLib

CHECK_INTERVAL = 5
TIMEOUT = 1.0
PRIMARY_COLOR = "#48A3FF"
WARNING_COLOR = "#ff9a3c"
CRITICAL_COLOR = "#dc2f2f"
SUCCESS_COLOR = "#FFFFFF"
ICON_ONLINE = "󰲝"
ICON_LOCAL = "󰌚"
ICON_OFFLINE = "󰲜"

class NetMonitor:
    def __init__(self):
        self.targets = [("Quad9", "9.9.9.9", 53), ("Google", "8.8.8.8", 53), ("Cloudflare", "1.1.1.1", 53), ("AdGuard", "192.168.1.62", 53)]
        self.router = self.get_default_gateway()
        self.check_connectivity()
        GLib.timeout_add_seconds(CHECK_INTERVAL, self.timer_tick)

    def get_default_gateway(self):
        try:
            with open("/proc/net/route") as f:
                for line in f:
                    fields = line.strip().split()
                    if fields[1] != '00000000' or not int(fields[3], 16) & 2: continue
                    return socket.inet_ntoa(struct.pack("<L", int(fields[2], 16)))
        except: return "192.168.1.1"

    def check_tcp(self, ip, port):
        try:
            start = time.time()
            with socket.create_connection((ip, port), timeout=TIMEOUT):
                return (time.time() - start) * 1000
        except: return None

    def timer_tick(self):
        self.check_connectivity()
        return True

    def check_connectivity(self):
        results = {}
        internet_ok = False
        for name, ip, port in self.targets:
            ping = self.check_tcp(ip, port)
            results[name] = ping
            if ping is not None: internet_ok = True

        router_ping = self.check_tcp(self.router, 53) or self.check_tcp(self.router, 80)
        results["Router"] = router_ping

        if internet_ok: self.update_ui("online", results)
        elif router_ping: self.update_ui("local", results)
        else: self.update_ui("offline", results)

    def update_ui(self, state, data):
        tooltip = f"<span color='{PRIMARY_COLOR}'>Network Status:</span>\n"
        if state == "online": text = f"<span color='{SUCCESS_COLOR}'>{ICON_ONLINE}</span>"; css = "online"
        elif state == "local": text = f"<span color='{WARNING_COLOR}'>{ICON_LOCAL}</span>"; css = "local"
        else: text = f"<span color='{CRITICAL_COLOR}'>{ICON_OFFLINE}</span>"; css = "offline"

        for host, ms in data.items():
            status = f"{int(ms)}ms" if ms else "Unreachable"
            color = SUCCESS_COLOR if ms else CRITICAL_COLOR
            tooltip += f" ├─ {host}: <span color='{color}'>{status}</span>\n"

        print(json.dumps({"text": text, "tooltip": tooltip.strip(), "class": css}), flush=True)

if __name__ == "__main__":
    signal.signal(signal.SIGINT, signal.SIG_DFL)
    app = NetMonitor()
    loop = GLib.MainLoop()
    loop.run()