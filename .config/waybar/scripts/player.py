#!/bin/python3
# this is a Waybar Widget for controlling media players with playlist info
import subprocess
import json
import time
import sys

# Use "any" to detect any available player instead of hardcoding "spotify"
player = "spotify"

no_player_icon = "󰝛"  # Icon when no player is available

playing_icon = ""
paused_icon = ""

loop_icon = "󰑘"
playlist_loop = "󰑖"
not_loop_icon = "󰑗"
shuffle_icon = ""
not_shuffle_icon = "󰒞"

def check_player_available():
    """Check if any media player is available"""
    try:
        status = subprocess.run(
            ["playerctl", "--list-all"], 
            capture_output=True, 
            text=True, 
            timeout=1
        )
        return len(status.stdout.strip()) > 0
    except Exception:
        return False

def get_title():
    try:
        title = (
            subprocess.check_output(["playerctl", "-p", player, "metadata", "title"])
            .decode("utf-8")
            .strip()
        )
        # Remove any info in parentheses and escape &
        return title.split("(")[0].replace("&", "&amp;")
    except Exception:
        return "No Title"


def get_playing():
    try:
        status = (
            subprocess.check_output(["playerctl", "-p", player, "status"])
            .decode("utf-8")
            .strip()
        )
        return playing_icon if status == "Playing" else paused_icon
    except Exception:
        return no_player_icon


def get_artist():
    try:
        return (
            subprocess.check_output(["playerctl", "-p", player, "metadata", "artist"])
            .decode("utf-8")
            .strip()
        )
    except Exception:
        return "Unknown Artist"


def get_album():
    try:
        return (
            subprocess.check_output(["playerctl", "-p", player, "metadata", "album"])
            .decode("utf-8")
            .strip()
        )
    except Exception:
        return "Unknown Album"


def get_position():
    try:
        seconds = int(
            float(
                subprocess.check_output(["playerctl", "-p", player, "position"])
                .decode("utf-8")
                .strip()
            )
        )
        minutes = seconds // 60
        remaining_seconds = seconds % 60
        return f"{minutes:02d}:{remaining_seconds:02d}"
    except Exception:
        return "00:00"


def get_length():
    try:
        microseconds = int(
            subprocess.check_output(
                ["playerctl", "-p", player, "metadata", "mpris:length"]
            )
            .decode("utf-8")
            .strip()
        )
        seconds = microseconds // 1000000
        minutes = seconds // 60
        remaining_seconds = seconds % 60
        return f"{minutes:02d}:{remaining_seconds:02d}"
    except Exception:
        return "00:00"


def get_playlist():
    try:
        playlist = (
            subprocess.check_output(
                ["playerctl", "-p", player, "metadata", "xesam:playlist"]
            )
            .decode("utf-8")
            .strip()
        )
        # Fallback to another key if playlist isn't provided
        if not playlist:
            playlist = (
                subprocess.check_output(
                    ["playerctl", "-p", player, "metadata", "xesam:station"]
                )
                .decode("utf-8")
                .strip()
            )
        return playlist if playlist else "No Playlist"
    except Exception:
        return "No Playlist"


def get_loop():
    try:
        status = (
            subprocess.check_output(["playerctl", "-p", player, "loop"])
            .decode("utf-8")
            .strip()
        )
        if status == "Playlist":
            return playlist_loop
        elif status == "Track":
            return loop_icon
        else:
            return not_loop_icon
    except Exception:
        return not_loop_icon


def get_shuffle():
    try:
        status = (
            subprocess.check_output(["playerctl", "-p", player, "shuffle"])
            .decode("utf-8")
            .strip()
        )
        return shuffle_icon if status == "On" else not_shuffle_icon
    except Exception:
        return not_shuffle_icon


def main():
    no_player_count = 0
    
    while True:
        # Check if a player is available
        if check_player_available():
            no_player_count = 0
            
            try:
                icon = get_playing()
                title = get_title()
                artist = get_artist()
                album = get_album()
                playlist = get_playlist()
                position = get_position()
                length = get_length()
                looping = get_loop()
                shuffling = get_shuffle()

                output_text = (
                    f"{icon} {title} - {artist} [{position}/{length}] {looping} {shuffling}"
                )
                # Create an invisible dynamic dummy using zero-width spaces.
                # The length of the dummy string changes every second.
                dummy = "\u200B" * ((int(time.time() * 1000) % 10) + 1)
                tooltip_text = f"Album: {album}\nPlaylist: {playlist} {looping} {shuffling}{dummy}"
            except Exception as e:
                output_text = f"{no_player_icon} No media playing"
                tooltip_text = "No active media player detected"
        else:
            output_text = f"{no_player_icon} No media playing"
            tooltip_text = "No active media player detected"
            
            # Increase sleep time when no player is available
            no_player_count += 1
            
        output = {"text": output_text, "tooltip": tooltip_text}
        print(json.dumps(output))
        sys.stdout.flush()
        
        # Sleep longer if no player has been detected multiple times in a row
        if no_player_count > 5:
            time.sleep(5)  # Check less frequently when no players are active
        else:
            time.sleep(1)


if __name__ == "__main__":
    main()