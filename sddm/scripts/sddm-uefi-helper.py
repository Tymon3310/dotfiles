#!/usr/bin/env python3
"""
SDDM UEFI Reboot Helper
Listens on http://127.0.0.1:18293 for power signals from SDDM greeter.
Sets systemd-logind RebootToFirmwareSetup accordingly.
"""
import http.server
import subprocess
import sys

PORT = 18293

class HelperHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/reboot-uefi":
            subprocess.run([
                "busctl", "call", "org.freedesktop.login1",
                "/org/freedesktop/login1", "org.freedesktop.login1.Manager",
                "SetRebootToFirmwareSetup", "b", "true"
            ], check=False)
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"UEFI=true")
        elif self.path in ("/reboot-normal", "/shutdown"):
            subprocess.run([
                "busctl", "call", "org.freedesktop.login1",
                "/org/freedesktop/login1", "org.freedesktop.login1.Manager",
                "SetRebootToFirmwareSetup", "b", "false"
            ], check=False)
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"UEFI=false")
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        # Silent
        pass

def main():
    try:
        server = http.server.HTTPServer(("127.0.0.1", PORT), HelperHandler)
        server.serve_forever()
    except Exception:
        sys.exit(0)

if __name__ == "__main__":
    main()
