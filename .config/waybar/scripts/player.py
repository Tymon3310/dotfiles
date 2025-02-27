#!/bin/python3
# this is a Waybar Widget for controlling media players with playlist info
import subprocess
import json
import time
import sys

player = "spotify"

playing_icon = ""
paused_icon = ""

loop_icon = "󰑘"
playlist_loop = "󰑖"
not_loop_icon = "󰑗"
shuffle_icon = ""
not_shuffle_icon = "󰒞"


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
        return paused_icon


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


def get_loop():  # returns loop character if loops, not_loop character if not
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


def get_shuffle():  # returns shuffle character if on, not_shuffle character if off
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
    while True:
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
        output = {"text": output_text, "tooltip": tooltip_text}
        print(json.dumps(output))
        sys.stdout.flush()
        time.sleep(1)


if __name__ == "__main__":
    main()
