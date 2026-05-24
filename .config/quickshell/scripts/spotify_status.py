#!/usr/bin/env python3
import gi
import json
import sys
import time
import signal
import os
import base64
import urllib.request
import urllib.parse
import threading
gi.require_version('Playerctl', '2.0')
from gi.repository import Playerctl, GLib

CONFIG_DIR = "/home/tymon/dotfiles/.config/quickshell"
CONFIG_PATH = os.path.join(CONFIG_DIR, "spotify_config.json")
TOKENS_PATH = os.path.join(CONFIG_DIR, "spotify_tokens.json")

def refresh_access_token(client_id, client_secret, refresh_token):
    try:
        body = urllib.parse.urlencode({
            "grant_type": "refresh_token",
            "refresh_token": refresh_token
        }).encode('utf-8')

        auth_str = f"{client_id}:{client_secret}"
        auth_b64 = base64.b64encode(auth_str.encode('utf-8')).decode('utf-8')
        headers = {
            "Authorization": f"Basic {auth_b64}",
            "Content-Type": "application/x-www-form-urlencoded"
        }

        req = urllib.request.Request("https://accounts.spotify.com/api/token", data=body, headers=headers)
        with urllib.request.urlopen(req, timeout=5) as response:
            res_data = json.loads(response.read().decode('utf-8'))
            
        return res_data["access_token"], res_data["expires_in"]
    except Exception as e:
        sys.stderr.write(f"Error refreshing access token: {e}\n")
        return None, None

def query_api(endpoint, access_token):
    try:
        req = urllib.request.Request(
            f"https://api.spotify.com/v1/{endpoint}",
            headers={"Authorization": f"Bearer {access_token}"}
        )
        with urllib.request.urlopen(req, timeout=5) as response:
            return json.loads(response.read().decode('utf-8'))
    except Exception as e:
        sys.stderr.write(f"Error querying Spotify API {endpoint}: {e}\n")
        return None

def get_context_name(context, access_token, cache):
    if not context:
        return ""
    ctx_type = context.get("type")
    uri = context.get("uri")
    if not uri:
        return ""
    if uri in cache:
        return cache[uri]
        
    if ctx_type == "playlist":
        href = context.get("href")
        if href:
            playlist_id = href.split("/")[-1]
            data = query_api(f"playlists/{playlist_id}?fields=name", access_token)
            if data and "name" in data:
                cache[uri] = f"Playlist: {data['name']}"
                return cache[uri]
    elif ctx_type == "album":
        href = context.get("href")
        if href:
            album_id = href.split("/")[-1]
            data = query_api(f"albums/{album_id}?fields=name", access_token)
            if data and "name" in data:
                cache[uri] = f"Album: {data['name']}"
                return cache[uri]
    elif ctx_type == "artist":
        href = context.get("href")
        if href:
            artist_id = href.split("/")[-1]
            data = query_api(f"artists/{artist_id}?fields=name", access_token)
            if data and "name" in data:
                cache[uri] = f"Artist Mix: {data['name']}"
                return cache[uri]
    elif ctx_type == "show":
        cache[uri] = "Podcast"
        return "Podcast"
        
    return ""

class SpotifyApiWorker:
    def __init__(self):
        self.lock = threading.Lock()
        self.client_id = ""
        self.client_secret = ""
        self.refresh_token = ""
        self.access_token = ""
        self.token_expiry = 0
        self.cached_contexts = {}
        self.api_data = {
            "queue": [],
            "isrc": "",
            "contextName": ""
        }
        self.active_track = ""
        self.enabled = False
        self.track_changed_time = 0
        self.needs_poll = False
        self.load_config()
        
    def load_config(self, print_errors=True):
        try:
            if os.path.exists(CONFIG_PATH) and os.path.exists(TOKENS_PATH):
                with open(CONFIG_PATH, "r") as f:
                    cfg = json.load(f)
                    self.client_id = cfg.get("client_id", "")
                    self.client_secret = cfg.get("client_secret", "")
                with open(TOKENS_PATH, "r") as f:
                    tok = json.load(f)
                    self.refresh_token = tok.get("refresh_token", "")
                    self.access_token = tok.get("access_token", "")
                    created_at = tok.get("created_at", 0)
                    expires_in = tok.get("expires_in", 3600)
                    self.token_expiry = created_at + expires_in
                if self.client_id and self.client_secret and self.refresh_token:
                    self.enabled = True
                    sys.stderr.write("Spotify Web API helper initialized successfully.\n")
                else:
                    if print_errors:
                        sys.stderr.write("Spotify config or tokens missing parameters. API disabled.\n")
            else:
                if print_errors:
                    sys.stderr.write("Spotify API config/tokens files not found. Local-only MPRIS mode.\n")
        except Exception as e:
            if print_errors:
                sys.stderr.write(f"Error loading API config: {e}\n")

    def ensure_token(self):
        if not self.enabled:
            return False
        if not self.access_token or time.time() > self.token_expiry - 60:
            sys.stderr.write("Refreshing Spotify access token...\n")
            token, expires_in = refresh_access_token(self.client_id, self.client_secret, self.refresh_token)
            if token:
                self.access_token = token
                self.token_expiry = time.time() + expires_in
                try:
                    with open(TOKENS_PATH, "w") as f:
                        json.dump({
                            "refresh_token": self.refresh_token,
                            "access_token": token,
                            "expires_in": expires_in,
                            "created_at": int(time.time())
                        }, f, indent=4)
                except Exception as e:
                    sys.stderr.write(f"Error saving refreshed tokens: {e}\n")
            else:
                return False
        return True

    def trigger_track_change(self, title, artist):
        track_str = f"{title} - {artist}"
        if track_str != self.active_track:
            self.active_track = track_str
            self.track_changed_time = time.time()
            self.needs_poll = True

    def get_latest_data(self):
        with self.lock:
            return self.api_data.copy()

    def run_loop(self):
        last_poll = 0
        while True:
            try:
                time.sleep(0.5)
                if not self.enabled:
                    self.load_config(print_errors=False)
                    if not self.enabled:
                        continue
                    
                now = time.time()
                should_poll = False
                if self.needs_poll and (now - self.track_changed_time >= 1.5):
                    should_poll = True
                    self.needs_poll = False
                elif now - last_poll > 8:
                    should_poll = True
                    self.needs_poll = False
                
                if should_poll:
                    if not self.ensure_token():
                        time.sleep(5)
                        continue
                        
                    # Query Web API state
                    player_state = query_api("me/player", self.access_token)
                    
                    isrc = ""
                    context_name = ""
                    if player_state:
                        item = player_state.get("item")
                        if item:
                            isrc = item.get("external_ids", {}).get("isrc", "")
                        context = player_state.get("context")
                        if context:
                            context_name = get_context_name(context, self.access_token, self.cached_contexts)
                        else:
                            context_name = "Liked Songs"
                    
                    # Query queue
                    queue_items = []
                    queue_data = query_api("me/player/queue", self.access_token)
                    if queue_data and "queue" in queue_data:
                        raw_queue = queue_data["queue"]
                        for track in raw_queue[:3]:
                            title = track.get("name") or "Unknown"
                            artists = ", ".join([a.get("name") for a in track.get("artists", [])]) or "Unknown Artist"
                            art_url = ""
                            images = track.get("album", {}).get("images", [])
                            if images:
                                art_url = images[-1].get("url", "")
                            queue_items.append({
                                "title": title,
                                "artist": artists,
                                "artUrl": art_url
                            })
                            
                    with self.lock:
                        self.api_data = {
                            "queue": queue_items,
                            "isrc": isrc,
                            "contextName": context_name
                        }
                    
                    last_poll = now
            except Exception as e:
                sys.stderr.write(f"Error in API worker loop: {e}\n")
                time.sleep(5)

class SpotifyListener:
    def __init__(self):
        self.manager = Playerctl.PlayerManager()
        self.manager.connect('name-appeared', self.on_player_appeared)
        self.manager.connect('player-vanished', self.on_player_vanished)
        self.player = None
        
        # Instantiate background Web API worker
        self.api_worker = SpotifyApiWorker()
        self.api_thread = threading.Thread(target=self.api_worker.run_loop, daemon=True)
        self.api_thread.start()
        
        self.find_spotify()
 
    def find_spotify(self):
        for name in self.manager.props.player_names:
            if 'spotify' in name.name.lower():
                self.init_player(name)
                return
        if self.manager.props.player_names:
            self.init_player(self.manager.props.player_names[0])
        else:
            self.player = None
            self.send_update()
 
    def init_player(self, name):
        try:
            player = Playerctl.Player.new_from_name(name)
            player.connect('playback-status', self.on_change)
            player.connect('metadata', self.on_change)
            player.connect('loop-status', self.on_change)
            player.connect('shuffle', self.on_change)
            player.connect('volume', self.on_change)
            self.manager.manage_player(player)
            self.player = player
            self.send_update()
        except Exception as e:
            sys.stderr.write(f"Error initializing player: {e}\n")
 
    def on_player_appeared(self, manager, name):
        if not self.player or 'spotify' not in self.player.props.player_name.lower():
            if 'spotify' in name.name.lower():
                self.init_player(name)
 
    def on_player_vanished(self, manager, player):
        if self.player == player:
            self.player = None
            self.find_spotify()
 
    def on_change(self, player, *args):
        self.send_update()
 
    def send_update(self):
        if not self.player:
            print(json.dumps({
                "status": "Stopped",
                "queue": [],
                "isrc": "",
                "contextName": ""
            }), flush=True)
            return
        try:
            meta_prop = self.player.props.metadata
            if hasattr(meta_prop, 'unpack'):
                meta = meta_prop.unpack()
            else:
                meta = meta_prop
            if not meta:
                meta = {}
                
            title = meta.get('xesam:title') or "Unknown Title"
            artist = meta.get('xesam:artist')
            if isinstance(artist, list) and len(artist) > 0: 
                artist = artist[0]
            elif not artist: 
                artist = "Unknown Artist"
            
            album = meta.get('xesam:album') or "Unknown Album"
            art_url = meta.get('mpris:artUrl') or ""
            length = meta.get('mpris:length') or 0
            
            try: 
                pos = self.player.get_position()
            except: 
                pos = 0
            
            status = self.player.props.playback_status.value_nick.title()
            
            loop = "Off"
            try:
                loop_status = self.player.props.loop_status
                if loop_status == Playerctl.LoopStatus.TRACK: 
                    loop = "Track"
                elif loop_status == Playerctl.LoopStatus.PLAYLIST: 
                    loop = "Playlist"
            except:
                pass
            
            shuffle = False
            try:
                shuffle = self.player.props.shuffle
            except:
                pass
                
            volume = 0.5
            try:
                volume = self.player.props.volume
            except:
                pass
            
            # Notify API worker of track details for check/update
            self.api_worker.trigger_track_change(title, artist)
            
            # Retrieve latest async Web API fields
            api_data = self.api_worker.get_latest_data()
            
            print(json.dumps({
                "title": title,
                "artist": artist,
                "album": album,
                "artUrl": art_url,
                "position": pos,
                "length": length,
                "status": status,
                "loop": loop,
                "shuffle": shuffle,
                "volume": volume,
                "playerName": self.player.props.player_name,
                "queue": api_data["queue"],
                "isrc": api_data["isrc"],
                "contextName": api_data["contextName"]
            }), flush=True)
        except Exception as e:
            print(json.dumps({
                "status": "Error", 
                "error": str(e),
                "queue": [],
                "isrc": "",
                "contextName": ""
            }), flush=True)
 
    def tick(self):
        if self.player and self.player.props.playback_status == Playerctl.PlaybackStatus.PLAYING:
            self.send_update()
        return True
 
if __name__ == '__main__':
    signal.signal(signal.SIGINT, signal.SIG_DFL)
    listener = SpotifyListener()
    GLib.timeout_add(250, listener.tick)
    loop = GLib.MainLoop()
    try:
        loop.run()
    except KeyboardInterrupt:
        pass
