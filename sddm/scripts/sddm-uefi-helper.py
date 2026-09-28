#!/usr/bin/env python3
"""
SDDM Impasto Helper Daemon
Listens on http://127.0.0.1:18293 for power signals from SDDM greeter.
Sets systemd-logind RebootToFirmwareSetup securely.
"""
import http.server
import grp
import os
import secrets
import subprocess
import sys
import urllib.parse

PORT = 18293
TOKEN_PATH = "/run/sddm-helper-token"
EXPECTED_TOKEN = ""


def init_token():
    global EXPECTED_TOKEN
    EXPECTED_TOKEN = secrets.token_hex(16)
    try:
        with open(TOKEN_PATH, "w") as f:
            f.write(EXPECTED_TOKEN.strip())
        try:
            sddm_gid = grp.getgrnam("sddm").gr_gid
            os.chown(TOKEN_PATH, 0, sddm_gid)
            os.chmod(TOKEN_PATH, 0o640)
        except Exception:
            # Fail closed: root-only read/write
            os.chmod(TOKEN_PATH, 0o600)
    except Exception as e:
        sys.stderr.write(f"Warning: could not write {TOKEN_PATH}: {e}\n")


class HelperHandler(http.server.BaseHTTPRequestHandler):
    def check_auth(self):
        if not EXPECTED_TOKEN:
            return False
        header_token = self.headers.get("X-Helper-Token", "").strip()
        return header_token == EXPECTED_TOKEN

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path

        if not self.check_auth():
            self.send_response(403)
            self.end_headers()
            self.wfile.write(b"Forbidden")
            return

        if path == "/reboot-uefi":
            subprocess.run([
                "busctl", "call", "org.freedesktop.login1",
                "/org/freedesktop/login1", "org.freedesktop.login1.Manager",
                "SetRebootToFirmwareSetup", "b", "true"
            ], check=False)
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"uefi": true}')

        elif path in ("/reboot-normal", "/shutdown"):
            subprocess.run([
                "busctl", "call", "org.freedesktop.login1",
                "/org/freedesktop/login1", "org.freedesktop.login1.Manager",
                "SetRebootToFirmwareSetup", "b", "false"
            ], check=False)
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"uefi": false}')

        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        # Silent
        pass


def main():
    init_token()
    try:
        server = http.server.ThreadingHTTPServer(("127.0.0.1", PORT), HelperHandler)
        server.serve_forever()
    except Exception:
        sys.exit(0)
    finally:
        try:
            if os.path.exists(TOKEN_PATH):
                os.remove(TOKEN_PATH)
        except Exception:
            pass


if __name__ == "__main__":
    main()
