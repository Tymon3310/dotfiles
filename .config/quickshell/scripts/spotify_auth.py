#!/usr/bin/env python3
import os
import sys
import json
import base64
import urllib.request
import urllib.parse
import webbrowser
from http.server import BaseHTTPRequestHandler, HTTPServer

CONFIG_DIR = "/home/tymon/dotfiles/.config/quickshell"
CONFIG_PATH = os.path.join(CONFIG_DIR, "spotify_config.json")
TOKENS_PATH = os.path.join(CONFIG_DIR, "spotify_tokens.json")
KEY_PATH = os.path.join(CONFIG_DIR, "key.pem")
CERT_PATH = os.path.join(CONFIG_DIR, "cert.pem")

def generate_self_signed_cert():
    if not os.path.exists(KEY_PATH) or not os.path.exists(CERT_PATH):
        print("Generating self-signed SSL certificate for secure HTTPS callback...")
        import subprocess
        try:
            subprocess.run([
                "openssl", "req", "-newkey", "rsa:2048", "-new", "-nodes", "-x509",
                "-days", "365",
                "-keyout", KEY_PATH,
                "-out", CERT_PATH,
                "-subj", "/CN=127.0.0.1"
            ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            print("Self-signed certificate generated.")
        except Exception as e:
            print(f"Error generating self-signed certificate: {e}")
            print("HTTPS callback server might fail to start.")

class CallbackHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        # Suppress logging to stdout
        pass

    def do_GET(self):
        parsed_path = urllib.parse.urlparse(self.path)
        query = urllib.parse.parse_qs(parsed_path.query)
        
        if parsed_path.path == '/callback' and 'code' in query:
            self.server.auth_code = query['code'][0]
            self.send_response(200)
            self.send_header('Content-type', 'text/html; charset=utf-8')
            self.end_headers()
            self.wfile.write(b"""
                <html>
                <head>
                    <title>Spotify Auth Success</title>
                    <style>
                        body { font-family: sans-serif; background: #121212; color: #ffffff; text-align: center; padding-top: 100px; }
                        .card { background: #1e1e1e; border-radius: 12px; padding: 40px; display: inline-block; box-shadow: 0 4px 20px rgba(0,0,0,0.5); border: 1px solid #333; }
                        h1 { color: #1DB954; margin-bottom: 20px; }
                        p { color: #b3b3b3; }
                    </style>
                </head>
                <body>
                    <div class="card">
                        <h1>Authorization Successful!</h1>
                        <p>You can close this tab now. The credentials have been saved to your system.</p>
                    </div>
                </body>
                </html>
            """)
        else:
            self.send_response(400)
            self.end_headers()
            self.wfile.write(b"Invalid redirect request.")

def main():
    if not os.path.exists(CONFIG_DIR):
        os.makedirs(CONFIG_DIR)

    client_id = ""
    client_secret = ""

    # Load existing config if available
    if os.path.exists(CONFIG_PATH):
        try:
            with open(CONFIG_PATH, "r") as f:
                cfg = json.load(f)
                client_id = cfg.get("client_id", "")
                client_secret = cfg.get("client_secret", "")
        except:
            pass

    # Prompt user for credentials if not found
    if not client_id or not client_secret:
        print("=== Spotify Developer Credentials Setup ===")
        print("Please enter the credentials from your Spotify Developer Dashboard:")
        client_id = input("Client ID: ").strip()
        client_secret = input("Client Secret: ").strip()
        
        if not client_id or not client_secret:
            print("Error: Client ID and Client Secret cannot be empty.")
            sys.exit(1)
            
        with open(CONFIG_PATH, "w") as f:
            json.dump({"client_id": client_id, "client_secret": client_secret}, f, indent=4)
            print(f"Credentials saved to: {CONFIG_PATH}")

    # Set up auth parameters
    redirect_uri = "https://127.0.0.1:8888/callback"
    scope = "user-read-playback-state playlist-read-private playlist-read-collaborative"
    
    auth_params = {
        "client_id": client_id,
        "response_type": "code",
        "redirect_uri": redirect_uri,
        "scope": scope
    }
    auth_url = "https://accounts.spotify.com/authorize?" + urllib.parse.urlencode(auth_params)

    # Start local HTTPS server
    print("\nStarting local HTTPS authentication listener on port 8888...")
    generate_self_signed_cert()
    try:
        import ssl
        server = HTTPServer(('127.0.0.1', 8888), CallbackHandler)
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(certfile=CERT_PATH, keyfile=KEY_PATH)
        server.socket = context.wrap_socket(server.socket, server_side=True)
    except Exception as e:
        print(f"Error starting local HTTPS server: {e}")
        print("Please check if another app is using port 8888.")
        sys.exit(1)
        
    server.auth_code = None

    # Open authorization URL in web browser
    print("Opening your browser to authorize the application...")
    webbrowser.open(auth_url)

    # Wait for callback
    print("Waiting for callback from Spotify...")
    while server.auth_code is None:
        server.handle_request()

    auth_code = server.auth_code
    server.server_close()
    print("Authorization code received!")

    # Exchange authorization code for tokens
    print("Exchanging authorization code for access tokens...")
    try:
        body = urllib.parse.urlencode({
            "grant_type": "authorization_code",
            "code": auth_code,
            "redirect_uri": redirect_uri
        }).encode('utf-8')

        auth_str = f"{client_id}:{client_secret}"
        auth_b64 = base64.b64encode(auth_str.encode('utf-8')).decode('utf-8')
        headers = {
            "Authorization": f"Basic {auth_b64}",
            "Content-Type": "application/x-www-form-urlencoded"
        }

        req = urllib.request.Request("https://accounts.spotify.com/api/token", data=body, headers=headers)
        with urllib.request.urlopen(req) as response:
            res_data = json.loads(response.read().decode('utf-8'))
            
        import time
        tokens = {
            "refresh_token": res_data["refresh_token"],
            "access_token": res_data["access_token"],
            "expires_in": res_data["expires_in"],
            # Save token generation timestamp
            "created_at": int(time.time())
        }
        
        # Save tokens
        with open(TOKENS_PATH, "w") as f:
            json.dump(tokens, f, indent=4)
        print(f"Tokens saved successfully to: {TOKENS_PATH}")
        print("Authorization complete!")

    except Exception as e:
        print(f"\nError exchanging authorization code: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
