#!/usr/bin/python3
import gi
import json
import sys
import html
import signal

gi.require_version('Playerctl', '2.0')
from gi.repository import Playerctl, GLib

# --- Configuration ---
SCROLL_LENGTH = 20
PRIMARY_COLOR = "#48A3FF"
STARTUP_DELAY_MS = 750 

ICONS = {
    "Default": "󰝛",
    "Playing": "",
    "Paused": "",
    "Stopped": "󰝛",
    "Track": "󰑘",
    "Playlist": "󰑖",
    "None": "󰑗",
    "ShuffleOn": "󰒟",
    "ShuffleOff": "󰒞"
}

PLAYER_MAP = {
    "spotify": "󰓇",
    "firefox": "󰈹",
    "chrome": "",
    "chromium": "",
    "youtube": "󰗃",
    "vlc": "󰕼",
    "mpv": "󰝚"
}

class WaybarPlayer:
    def __init__(self):
        self.manager = Playerctl.PlayerManager()
        self.manager.connect('name-appeared', self.on_player_appeared)
        self.manager.connect('player-vanished', self.on_player_vanished)
        
        self.current_player = None
        self.scroll_index = 0
        self.scroll_timer = None
        self.position_timer = None
        
        GLib.timeout_add(STARTUP_DELAY_MS, self.initial_check)

    def initial_check(self):
        if not self.current_player:
            if len(self.manager.props.player_names) > 0:
                found = False
                for name in self.manager.props.player_names:
                    if 'spotify' in name.name.lower():
                        self.init_player(name)
                        found = True
                        break
                if not found:
                    self.init_player(self.manager.props.player_names[0])
            else:
                self.exit_cleanly()
        return False

    def init_player(self, name):
        try:
            player = Playerctl.Player.new_from_name(name)
            player.connect('playback-status', self.on_state_change)
            player.connect('metadata', self.on_metadata_change)
            player.connect('loop-status', self.on_metadata_change)
            player.connect('shuffle', self.on_metadata_change)
            player.connect('volume', self.on_metadata_change)
            self.manager.manage_player(player)
            self.current_player = player
            self.update_output()
        except Exception:
            pass

    def on_player_appeared(self, manager, name):
        if not self.current_player:
            self.init_player(name)

    def on_player_vanished(self, manager, player):
        if self.current_player == player:
            self.current_player = None
            if len(self.manager.props.players) > 0:
                self.current_player = self.manager.props.players[0]
                self.update_output()
            else:
                self.exit_cleanly()

    def on_state_change(self, player, status):
        if player == self.current_player:
            self.update_output()

    def on_metadata_change(self, player, *args):
        if player == self.current_player:
            self.update_output()

    def exit_cleanly(self):
        print(json.dumps({"text": "", "tooltip": "", "class": "stopped"}), flush=True)
        if self.scroll_timer: GLib.source_remove(self.scroll_timer)
        if self.position_timer: GLib.source_remove(self.position_timer)
        sys.exit(0)

    def format_time(self, microseconds):
        try:
            seconds = int(microseconds / 1000000)
            return f"{seconds // 60}:{seconds % 60:02d}"
        except:
            return "0:00"

    def update_output(self):
        if not self.current_player:
            return

        player = self.current_player
        
        try:
            status = player.props.playback_status
            
            # Variant Unpacking
            meta_prop = player.props.metadata
            if hasattr(meta_prop, 'unpack'): meta = meta_prop.unpack()
            else: meta = meta_prop
            if not meta: meta = {}

            title = meta.get('xesam:title')
            if not title: title = "Unknown Title"

            artist_raw = meta.get('xesam:artist')
            if isinstance(artist_raw, list) and len(artist_raw) > 0: artist = artist_raw[0]
            elif isinstance(artist_raw, str): artist = artist_raw
            else: artist = "Unknown Artist"

            album = meta.get('xesam:album')
            if not album: album = "Unknown Album"
            
            length_us = meta.get('mpris:length')
            if not length_us: length_us = 0
            
            status_txt = status.value_nick.title()
            status_icon = ICONS.get(status_txt, ICONS["Stopped"])
            
            loop_status = player.props.loop_status
            if loop_status == Playerctl.LoopStatus.TRACK: loop_ico = ICONS["Track"]; loop_txt = "Track"
            elif loop_status == Playerctl.LoopStatus.PLAYLIST: loop_ico = ICONS["Playlist"]; loop_txt = "Playlist"
            else: loop_ico = ICONS["None"]; loop_txt = "Off"

            shuffle = player.props.shuffle
            shuffle_ico = ICONS["ShuffleOn"] if shuffle else ICONS["ShuffleOff"]
            shuffle_txt = "On" if shuffle else "Off"

            volume_percent = int(player.props.volume * 100)

            try: pos_us = player.get_position()
            except: pos_us = 0
            
            time_str = f"[{self.format_time(pos_us)}/{self.format_time(length_us)}]"

            if status == Playerctl.PlaybackStatus.PLAYING:
                if not self.position_timer:
                    self.position_timer = GLib.timeout_add(1000, self.on_tick_position)
                if not self.scroll_timer and len(title) > SCROLL_LENGTH:
                    self.scroll_timer = GLib.timeout_add(250, self.on_tick_scroll)
            else:
                if self.position_timer:
                    GLib.source_remove(self.position_timer)
                    self.position_timer = None
                if self.scroll_timer:
                    GLib.source_remove(self.scroll_timer)
                    self.scroll_timer = None
                    self.scroll_index = 0

            display_title = title
            if len(title) > SCROLL_LENGTH:
                padded = f"{title} | {title[:SCROLL_LENGTH]}"
                start = self.scroll_index % (len(title) + 3)
                display_title = padded[start:start+SCROLL_LENGTH]
            
            esc_title = html.escape(title)
            esc_artist = html.escape(artist)
            esc_album = html.escape(album)
            esc_player = html.escape(player.props.player_name)
            
            player_icon = "󱁫"
            for key, icon in PLAYER_MAP.items():
                if key in esc_player.lower():
                    player_icon = icon
                    break

            output_text = f" {status_icon} {html.escape(display_title)} {time_str} {volume_percent}% {loop_ico} {shuffle_ico} "
            
            tooltip =  f"<span color='{PRIMARY_COLOR}'><b>{player_icon} {esc_player.title()} Media Player</b></span>\n\n"
            tooltip += f" ├─ Title: {esc_title}\n"
            tooltip += f" ├─ Volume: {volume_percent}%\n"
            tooltip += f" ├─ Artist: {esc_artist}\n"
            tooltip += f" └─ Album: {esc_album}\n\n"
            tooltip += f" ├─ Time: {self.format_time(pos_us)}/{self.format_time(length_us)}\n"
            tooltip += f" ├─ Loop: {loop_txt}\n"
            tooltip += f" └─ Shuffle: {shuffle_txt}"

            print(json.dumps({
                "text": output_text,
                "tooltip": tooltip,
                "class": status.value_nick.lower()
            }), flush=True)

        except Exception:
            self.exit_cleanly()

    def on_tick_scroll(self):
        self.scroll_index += 1
        self.update_output()
        return True
    
    def on_tick_position(self):
        self.update_output()
        return True

if __name__ == '__main__':
    signal.signal(signal.SIGINT, signal.SIG_DFL)
    app = WaybarPlayer()
    loop = GLib.MainLoop()
    try:
        loop.run()
    except KeyboardInterrupt:
        pass