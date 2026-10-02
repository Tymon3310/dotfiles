#!/usr/bin/env python3
"""Stream Spotify queue changes as JSON; playback state belongs to MPRIS."""

import base64
import json
import os
import signal
import sys
import threading
import tempfile
import time
import urllib.parse
import urllib.request

import gi

gi.require_version("Playerctl", "2.0")
from gi.repository import GLib, Playerctl

CONFIG_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONFIG_PATH = os.path.join(CONFIG_DIR, "spotify_config.json")
TOKENS_PATH = os.path.join(CONFIG_DIR, "spotify_tokens.json")


def query_json(url, *, headers, data=None):
    request = urllib.request.Request(url, headers=headers, data=data)
    with urllib.request.urlopen(request, timeout=5) as response:
        body = response.read()
        return json.loads(body) if body.strip() else None


class SpotifyQueueWorker:
    def __init__(self):
        self.changed = threading.Event()
        self.player_present = False
        self.client_id = ""
        self.client_secret = ""
        self.refresh_token = ""
        self.access_token = ""
        self.token_expiry = 0
        self.last_queue = None

    def load_config(self):
        try:
            with open(CONFIG_PATH) as stream:
                config = json.load(stream)
            with open(TOKENS_PATH) as stream:
                tokens = json.load(stream)
        except FileNotFoundError:
            # Authentication can be configured while the shell is running.
            return False
        self.client_id = config.get("client_id", "")
        self.client_secret = config.get("client_secret", "")
        self.refresh_token = tokens.get("refresh_token", "")
        self.access_token = tokens.get("access_token", "")
        self.token_expiry = tokens.get("created_at", 0) + tokens.get("expires_in", 3600)
        return bool(self.client_id and self.client_secret and self.refresh_token)

    def ensure_token(self):
        if self.access_token and time.time() < self.token_expiry - 60:
            return
        credentials = base64.b64encode(
            f"{self.client_id}:{self.client_secret}".encode()
        ).decode()
        data = urllib.parse.urlencode({
            "grant_type": "refresh_token",
            "refresh_token": self.refresh_token,
        }).encode()
        tokens = query_json(
            "https://accounts.spotify.com/api/token",
            data=data,
            headers={
                "Authorization": f"Basic {credentials}",
                "Content-Type": "application/x-www-form-urlencoded",
            },
        )
        self.access_token = tokens["access_token"]
        self.refresh_token = tokens.get("refresh_token", self.refresh_token)
        created_at = int(time.time())
        self.token_expiry = created_at + tokens["expires_in"]
        # Keep the credential format shared with spotify_auth.py. Create the
        # replacement privately and atomically so a reload cannot read half JSON.
        with tempfile.NamedTemporaryFile(
            mode="w", dir=CONFIG_DIR, prefix=".spotify-tokens-", delete=False
        ) as stream:
            temporary_path = stream.name
            try:
                json.dump({
                    "refresh_token": self.refresh_token,
                    "access_token": self.access_token,
                    "expires_in": tokens["expires_in"],
                    "created_at": created_at,
                }, stream, indent=4)
            except Exception:
                os.unlink(temporary_path)
                raise
        try:
            os.replace(temporary_path, TOKENS_PATH)
        finally:
            if os.path.exists(temporary_path):
                os.unlink(temporary_path)

    def publish(self, queue):
        if queue != self.last_queue:
            print(json.dumps({"queue": queue}), flush=True)
            self.last_queue = queue

    def run(self):
        while True:
            requested = self.changed.wait(timeout=8)
            self.changed.clear()
            if requested:
                # Give Spotify's Web API time to catch up with local metadata.
                time.sleep(1.5)
            try:
                if not self.player_present:
                    self.publish([])
                    continue
                if not self.load_config():
                    self.publish([])
                    continue
                self.ensure_token()
                data = query_json(
                    "https://api.spotify.com/v1/me/player/queue",
                    headers={"Authorization": f"Bearer {self.access_token}"},
                )
                queue = []
                for track in (data or {}).get("queue", [])[:3]:
                    images = (track.get("album") or {}).get("images", [])
                    queue.append({
                        "title": track.get("name") or "Unknown",
                        "artist": ", ".join(
                            artist.get("name") or "Unknown Artist"
                            for artist in track.get("artists", [])
                        ) or "Unknown Artist",
                        "artUrl": images[-1].get("url", "") if images else "",
                    })
                self.publish(queue if self.player_present else [])
            except Exception as error:
                sys.stderr.write(f"Queue update failed: {error}\n")


class SpotifyQueueListener:
    def __init__(self):
        self.worker = SpotifyQueueWorker()
        self.manager = Playerctl.PlayerManager()
        self.manager.connect("name-appeared", self.on_player_appeared)
        self.manager.connect("player-vanished", self.on_player_vanished)
        self.player = None
        self.find_spotify()
        threading.Thread(target=self.worker.run, daemon=True).start()

    def find_spotify(self):
        for name in self.manager.props.player_names:
            if "spotify" in name.name.lower() and self.init_player(name):
                return
        self.worker.player_present = False
        self.worker.changed.set()

    def init_player(self, name):
        try:
            player = Playerctl.Player.new_from_name(name)
            player.connect("metadata", self.on_metadata)
            self.manager.manage_player(player)
            self.player = player
            self.worker.player_present = True
            self.worker.changed.set()
            return True
        except Exception as error:
            sys.stderr.write(f"Cannot watch Spotify metadata: {error}\n")
            return False

    def on_player_appeared(self, manager, name):
        if self.player is None and "spotify" in name.name.lower():
            self.init_player(name)

    def on_player_vanished(self, manager, player):
        if self.player == player:
            self.player = None
            self.find_spotify()

    def on_metadata(self, player, *args):
        self.worker.changed.set()


if __name__ == "__main__":
    signal.signal(signal.SIGINT, signal.SIG_DFL)
    listener = SpotifyQueueListener()
    GLib.MainLoop().run()
