#!/usr/bin/env python3
"""
SDDM Impasto Helper Daemon
Listens on http://127.0.0.1:18293 for power signals from SDDM greeter.
Sets systemd-logind RebootToFirmwareSetup securely.
"""
import http.server
import grp
import hmac
import os
import secrets
import signal
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
        # Create with 0600 from the start so the token is never briefly world-readable
        fd = os.open(TOKEN_PATH, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, "w") as f:
            f.write(EXPECTED_TOKEN)
        try:
            sddm_gid = grp.getgrnam("sddm").gr_gid
            os.chown(TOKEN_PATH, 0, sddm_gid)
            os.chmod(TOKEN_PATH, 0o640)
        except Exception:
            pass  # Fail closed: stays root-only (0600)
    except Exception as e:
        sys.stderr.write(f"Warning: could not write {TOKEN_PATH}: {e}\n")


# path -> whether to boot into firmware setup on next reboot
ROUTES = {"/reboot-uefi": True, "/reboot-normal": False, "/shutdown": False}


def set_reboot_to_firmware(enabled):
    subprocess.run([
        "busctl", "call", "org.freedesktop.login1",
        "/org/freedesktop/login1", "org.freedesktop.login1.Manager",
        "SetRebootToFirmwareSetup", "b", "true" if enabled else "false"
    ], check=False)


class HelperHandler(http.server.BaseHTTPRequestHandler):
    def check_auth(self):
        if not EXPECTED_TOKEN:
            return False
        header_token = self.headers.get("X-Helper-Token", "").strip()
        return hmac.compare_digest(header_token.encode(), EXPECTED_TOKEN.encode())

    def do_GET(self):
        # State-changing routes are POST-only
        self.send_response(405)
        self.send_header("Allow", "POST")
        self.end_headers()

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path

        if not self.check_auth():
            self.send_response(403)
            self.end_headers()
            self.wfile.write(b"Forbidden")
            return

        if path in ROUTES:
            uefi = ROUTES[path]
            set_reboot_to_firmware(uefi)
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"uefi": true}' if uefi else b'{"uefi": false}')
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        # Silent
        pass


def _terminate(signum, frame):
    # Raise SystemExit so the finally block in main() removes the token file
    sys.exit(0)


def main():
    signal.signal(signal.SIGTERM, _terminate)
    init_token()
    exit_code = 0
    try:
        server = http.server.ThreadingHTTPServer(("127.0.0.1", PORT), HelperHandler)
        server.serve_forever()
    except (KeyboardInterrupt, SystemExit):
        pass
    except Exception as e:
        sys.stderr.write(f"sddm-uefi-helper: failed to serve on port {PORT}: {e}\n")
        exit_code = 1
    finally:
        try:
            if os.path.exists(TOKEN_PATH):
                os.remove(TOKEN_PATH)
        except Exception:
            pass
    sys.exit(exit_code)


if __name__ == "__main__":
    main()
