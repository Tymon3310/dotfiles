#!/usr/bin/env python3
"""
SDDM Impasto Helper Daemon
Listens on http://127.0.0.1:18293 for power and biometric signals from SDDM greeter.
Sets systemd-logind RebootToFirmwareSetup and runs non-blocking face auth probes.
"""
import http.server
import json
import os
import pwd
import grp
import secrets
import shutil
import subprocess
import sys
import threading
import urllib.parse

PORT = 18293
TOKEN_PATH = "/run/sddm-helper-token"
EXPECTED_TOKEN = ""
CURRENT_FACE_PROC = None
FACE_PROC_LOCK = threading.Lock()

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
            os.chmod(TOKEN_PATH, 0o644)
    except Exception as e:
        sys.stderr.write(f"Warning: could not write {TOKEN_PATH}: {e}\n")

def cancel_current_face():
    global CURRENT_FACE_PROC
    with FACE_PROC_LOCK:
        if CURRENT_FACE_PROC and CURRENT_FACE_PROC.poll() is None:
            try:
                CURRENT_FACE_PROC.terminate()
            except Exception:
                pass
            CURRENT_FACE_PROC = None

class HelperHandler(http.server.BaseHTTPRequestHandler):
    def check_auth(self):
        if not EXPECTED_TOKEN:
            return True
        header_token = self.headers.get("X-Helper-Token", "").strip()
        parsed = urllib.parse.urlparse(self.path)
        query = urllib.parse.parse_qs(parsed.query)
        param_token = query.get("token", [""])[0].strip()
        return header_token == EXPECTED_TOKEN or param_token == EXPECTED_TOKEN

    def do_GET(self):
        global CURRENT_FACE_PROC
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        query = urllib.parse.parse_qs(parsed.query)

        if not self.check_auth():
            self.send_response(403)
            self.end_headers()
            self.wfile.write(b"Forbidden")
            return

        if path == "/reboot-uefi":
            cancel_current_face()
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
            cancel_current_face()
            subprocess.run([
                "busctl", "call", "org.freedesktop.login1",
                "/org/freedesktop/login1", "org.freedesktop.login1.Manager",
                "SetRebootToFirmwareSetup", "b", "false"
            ], check=False)
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"uefi": false}')

        elif path == "/cancel-face":
            cancel_current_face()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"cancelled": true}')

        elif path == "/face-auth":
            biopass_path = shutil.which("biopass-helper") or "/usr/bin/biopass-helper"
            if not os.path.exists(biopass_path):
                self.send_response(503)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(b'{"error": "biopass-helper not available"}')
                return

            user = query.get("user", [""])[0].strip()
            if not user:
                human_users = [u.pw_name for u in pwd.getpwall() if 1000 <= u.pw_uid < 60000]
                user = human_users[0] if human_users else os.environ.get("USER", "")

            cancel_current_face()
            try:
                proc = subprocess.Popen(
                    [biopass_path, "auth", "-u", user, "--service", "login"],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL
                )
                with FACE_PROC_LOCK:
                    CURRENT_FACE_PROC = proc

                try:
                    code = proc.wait(timeout=4.0)
                except subprocess.TimeoutExpired:
                    proc.kill()
                    code = 1
                finally:
                    with FACE_PROC_LOCK:
                        if CURRENT_FACE_PROC == proc:
                            CURRENT_FACE_PROC = None

                if code == 0:
                    self.send_response(200)
                    self.send_header("Content-Type", "application/json")
                    self.end_headers()
                    self.wfile.write(b'{"verified": true}')
                else:
                    self.send_response(401)
                    self.send_header("Content-Type", "application/json")
                    self.end_headers()
                    self.wfile.write(b'{"verified": false}')
            except Exception as e:
                self.send_response(500)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"error": str(e)}).encode())

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
