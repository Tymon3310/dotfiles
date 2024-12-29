#!/bin/python3
# this is a Waybar Widget for controlling media players
import subprocess

ignore = ["vlc", "mpv", "chromium", "firefox", "plasma-browser-integration"]
ignoreString = ",".join(ignore)
player = "spotify"


def get_title():
    # return subprocess.check_output(["playerctl", "metadata", "title"]).decode("utf-8").strip()
    # ^^ this is old code. modify it to work with the ignore list. playerctl has the -i flag to ignore players
    return (
        # subprocess.check_output(["playerctl", "-i", ignoreString, "metadata", "title"])
        subprocess.check_output(["playerctl", "-p", player, "metadata", "title"])
        .decode("utf-8")
        .strip()
        .split("(")[0]
        .replace("&", "&amp;")
    )


def get_playing():
    if (
        # subprocess.check_output(["playerctl", "-i", ignoreString, "status"])
        subprocess.check_output(["playerctl", "-p", player, "status"])
        .decode("utf-8")
        .strip()
        == "Playing"
    ):
        return ""
    else:
        return ""


def main():
    print(f"{get_playing()} {get_title()}")


main()
