#!/bin/python3
# this is a Waybar Widget for controlling media players
import subprocess

player = "spotify"

playing_icon = ""
paused_icon = ""

def get_title():
    return (
        subprocess.check_output(["playerctl", "-p", player, "metadata", "title"])
        .decode("utf-8")
        .strip()
        .split("(")[0]
        .replace("&", "&amp;")
    )


def get_playing():
    if (
        subprocess.check_output(["playerctl", "-p", player, "status"])
        .decode("utf-8")
        .strip()
        == "Playing"
    ):
        return playing_icon
    else:
        return paused_icon

def get_artist():
    return (
        subprocess.check_output(["playerctl", "-p", player, "metadata", "artist"])
        .decode("utf-8")
        .strip()
    )

def get_album():
    return (
        subprocess.check_output(["playerctl", "-p", player, "metadata", "album"])
        .decode("utf-8")
        .strip()
    )

def get_position():
    seconds = int(float(subprocess.check_output(["playerctl", "-p", player, "position"])
        .decode("utf-8")
        .strip()))
    minutes = seconds // 60
    remaining_seconds = seconds % 60
    return f"{minutes:02d}:{remaining_seconds:02d}"

def get_length():
    microseconds = int(subprocess.check_output(["playerctl", "-p", player, "metadata", "mpris:length"])
        .decode("utf-8")
        .strip())
    seconds = microseconds // 1000000
    minutes = seconds // 60
    remaining_seconds = seconds % 60
    return f"{minutes:02d}:{remaining_seconds:02d}"

def main():
    icon = get_playing()
    title = get_title()
    artist = get_artist()
    album = get_album()
    position = get_position()
    length = get_length()

    # just do {thing}
    print(f"{icon} {title} - {artist} [{position}/{length}]")

main()