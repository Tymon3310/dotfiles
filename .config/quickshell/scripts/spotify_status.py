#!/usr/bin/env python3
import gi
import json
import sys
import time
import signal
gi.require_version('Playerctl', '2.0')
from gi.repository import Playerctl, GLib

class SpotifyListener:
    def __init__(self):
        self.manager = Playerctl.PlayerManager()
        self.manager.connect('name-appeared', self.on_player_appeared)
        self.manager.connect('player-vanished', self.on_player_vanished)
        self.player = None
        self.find_spotify()

    def find_spotify(self):
        for name in self.manager.props.player_names:
            if 'spotify' in name.name.lower():
                self.init_player(name)
                return
        # If no spotify, fallback to any other player
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
            print(json.dumps({"status": "Stopped"}), flush=True)
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
            length = meta.get('mpris:length') or 0 # microseconds
            
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
                "playerName": self.player.props.player_name
            }), flush=True)
        except Exception as e:
            print(json.dumps({"status": "Error", "error": str(e)}), flush=True)

    def tick(self):
        if self.player and self.player.props.playback_status == Playerctl.PlaybackStatus.PLAYING:
            self.send_update()
        return True

if __name__ == '__main__':
    # Make sure SIGINT can kill the python process
    signal.signal(signal.SIGINT, signal.SIG_DFL)
    listener = SpotifyListener()
    GLib.timeout_add(1000, listener.tick)
    loop = GLib.MainLoop()
    try:
        loop.run()
    except KeyboardInterrupt:
        pass
