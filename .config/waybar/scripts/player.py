#!/bin/python3
# this is a Waybar Widget for controlling media players with playlist info
import subprocess
import json
import time
import sys
import os
import argparse
import html

# Global debug flag
DEBUG_MODE = False

# Standard colors for all scripts - updated with lighter primary color
PRIMARY_COLOR = "#48A3FF"     # Lighter blue color that's more visible
WHITE_COLOR = "#FFFFFF"       # White text color
WARNING_COLOR = "#ff9a3c"     # Orange warning color from CSS .yellow 
CRITICAL_COLOR = "#dc2f2f"    # Red critical color from CSS .red
NEUTRAL_COLOR = "#FFFFFF"     # White for normal text
HEADER_COLOR = "#48A3FF"      # Lighter blue for section headers

# Use -p flag to specify one like "spotify" or "YoutubeMusic" OR use "any" to detect any available player
#player = "spotify" # Uncomment to override

# Restore ALL original icons
no_player_icon = "󰝛"  # Icon when no player is available
playing_icon = ""     # Original playing icon
paused_icon = ""      # Original paused icon
loop_icon = "󰑘"       # Original loop icon
playlist_loop = "󰑖"   # Original playlist loop icon
not_loop_icon = "󰑗"   # Original not loop icon
shuffle_icon = "󰒟"    # Original shuffle icon (restored!)
not_shuffle_icon = "󰒞" # Original not shuffle icon

# Scrolling text settings
SCROLL_TEXT_LENGTH = 20  # Number of characters for title scroll window
SCROLL_INTERVAL = 0.2   # Seconds between scroll steps

def scroll_text(text, length=SCROLL_TEXT_LENGTH):
    text = text.ljust(length)
    scrolling = text + ' | ' + text[:length]
    for i in range(len(scrolling) - length + 1):
        yield scrolling[i:i+length]

def get_all_metadata(player_name):
    """Get all track metadata in a single call using JSON format."""
    global DEBUG_MODE # Access the global debug flag
    # print(f"DEBUG: get_all_metadata called for {player_name}", file=sys.stderr)
    defaults = {
        "title": "Unknown Title",
        "artist": "Unknown Artist",
        "album": "Unknown Album",
        "length_us": 0,  # microseconds
        # "position_us": 0 # Removed, will use separate playerctl position call
    }
    try:
        format_string = (
            '{"title": "{{markup_escape(xesam:title)}}", "artist": "{{markup_escape(xesam:artist)}}", "album": "{{markup_escape(xesam:album)}}", '
            '"length_us": "{{mpris:length}}"}'
        )

        proc = subprocess.run(
            ["playerctl", f"--player={player_name}", "metadata", "--format", format_string],
            capture_output=True,
            text=True, 
            timeout=1
        )

        if proc.returncode != 0:
            if DEBUG_MODE:
                print(f"DEBUG: playerctl for {player_name} exited with {proc.returncode}. Stderr: {proc.stderr.strip()}", file=sys.stderr)
            return defaults

        raw_output_str = proc.stdout.strip()
        if DEBUG_MODE:
            print(f"DEBUG: raw_output_str for {player_name}: [{raw_output_str}]", file=sys.stderr)

        if not raw_output_str:
            if DEBUG_MODE:
                print(f"DEBUG: raw_output_str for {player_name} is empty.", file=sys.stderr)
            return defaults

        # Try to find the start and end of the main JSON object braces
        start_brace = raw_output_str.find('{')
        end_brace = raw_output_str.rfind('}')

        if start_brace == -1 or end_brace == -1 or end_brace < start_brace:
            if DEBUG_MODE:
                print(f"DEBUG: Could not find valid JSON object braces in [{raw_output_str}] for {player_name}.", file=sys.stderr)
            return defaults
        
        json_candidate_str = raw_output_str[start_brace : end_brace+1]
        if DEBUG_MODE:
            print(f"DEBUG: Extracted JSON candidate: [{json_candidate_str}] for {player_name}", file=sys.stderr)
        
        # Sanitize this candidate string (remove control chars except tab, LF, CR)
        sanitized_json_data = "".join(ch for ch in json_candidate_str if ord(ch) >= 32 or ch in '\t\n\r')
        if DEBUG_MODE:
            print(f"DEBUG: Sanitized JSON data: [{sanitized_json_data}] for {player_name}", file=sys.stderr)

        if not sanitized_json_data:
            if DEBUG_MODE:
                print(f"DEBUG: sanitized_json_data is empty after filtering for {player_name}.", file=sys.stderr)
            return defaults

        parsed_metadata_obj = None
        try:
            parsed_metadata_obj = json.loads(sanitized_json_data)
            if not isinstance(parsed_metadata_obj, dict):
                if DEBUG_MODE:
                    print(f"DEBUG: Parsed JSON was not a dict for {player_name}: {type(parsed_metadata_obj)}", file=sys.stderr)
                return defaults
            if DEBUG_MODE:
                print(f"DEBUG: Successfully parsed JSON object for {player_name}", file=sys.stderr)

        except json.JSONDecodeError as e_json:
            if DEBUG_MODE:
                # Enhanced error logging for JSONDecodeError
                error_message = f"DEBUG: JSONDecodeError for {player_name}: {e_json.msg}\\n"
                error_message += f"DEBUG: Error at Pos: {e_json.pos}, Line: {e_json.lineno}, Col: {e_json.colno}\\n"
                char_at_pos_info = "N/A"
                if e_json.doc and 0 <= e_json.pos < len(e_json.doc):
                    char_at_pos = e_json.doc[e_json.pos]
                    char_at_pos_info = f"'{char_at_pos}' (Unicode ord: {ord(char_at_pos)})"
                error_message += f"DEBUG: Character at error position {e_json.pos}: {char_at_pos_info}\\n"
                context_snippet_info = "N/A"
                if e_json.doc:
                    start_context = max(0, e_json.pos - 20)
                    end_context = min(len(e_json.doc), e_json.pos + 20)
                    context_snippet_info = repr(e_json.doc[start_context:end_context])
                error_message += f"DEBUG: Snippet of doc around error pos {e_json.pos}: {context_snippet_info}\\n"
                error_message += f"DEBUG: Sanitized data that was passed to json.loads: [{sanitized_json_data}]"
                print(error_message, file=sys.stderr)
            return defaults

        if parsed_metadata_obj is None: # Should not happen if logic above is correct
            if DEBUG_MODE:
                print(f"DEBUG: parsed_metadata_obj is None before populating data_out for {player_name}.", file=sys.stderr)
            return defaults

        data_out = defaults.copy()
        
        title_raw = parsed_metadata_obj.get('title', defaults['title'])
        data_out['title'] = html.unescape(title_raw) if title_raw else defaults['title']
        # Ensure that if unescape results in an empty string from a non-empty raw, we keep default
        if title_raw and not data_out['title']: data_out['title'] = defaults['title']

        artist_raw = parsed_metadata_obj.get('artist', defaults['artist'])
        data_out['artist'] = html.unescape(artist_raw) if artist_raw else defaults['artist']
        if artist_raw and not data_out['artist']: data_out['artist'] = defaults['artist']

        album_raw = parsed_metadata_obj.get('album', defaults['album'])
        data_out['album'] = html.unescape(album_raw) if album_raw else defaults['album']
        if album_raw and not data_out['album']: data_out['album'] = defaults['album']

        length_val = parsed_metadata_obj.get('length_us')
        if isinstance(length_val, str) and length_val.isdigit():
            data_out['length_us'] = int(length_val)
        elif isinstance(length_val, int):
            data_out['length_us'] = length_val
        else:
            data_out['length_us'] = defaults['length_us']

        # pos_val = parsed_metadata_obj.get('position_us') # Removed position parsing
        # if isinstance(pos_val, str) and pos_val.isdigit():
        #     data_out['position_us'] = int(pos_val)
        # elif isinstance(pos_val, int):
        #     data_out['position_us'] = pos_val
        # else:
        #     data_out['position_us'] = defaults['position_us']

        if DEBUG_MODE:
            print(f"DEBUG: Returning data_out: {data_out}", file=sys.stderr)
        return data_out
        
    except (OSError, subprocess.TimeoutExpired, ValueError) as e_subproc:
        if DEBUG_MODE:
            print(f"DEBUG: Subprocess/OS/Value error in get_all_metadata for {player_name}: {str(e_subproc)}", file=sys.stderr)
        return defaults
    except Exception as e_general: # Catch-all for any other unexpected error during the process
        if DEBUG_MODE:
            print(f"DEBUG: General Exception in get_all_metadata for {player_name}: {str(e_general)}", file=sys.stderr)
        return defaults

def check_player_available(player_name):
    """Check if the specified media player is available and responsive."""
    try:
        # Use a short timeout and check=True to quickly determine if playerctl can reach the player
        subprocess.run(
            ["playerctl", f"--player={player_name}", "status"],
            capture_output=True, text=True, timeout=0.2, check=True
        )
        return True
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired, OSError):
        return False

def get_playing_status(player_name):
    """Get the play/pause status using playerctl status."""
    try:
        status_proc = subprocess.run(
            ["playerctl", f"--player={player_name}", "status"],
            capture_output=True, text=True, timeout=0.5
        )
        if status_proc.returncode == 0:
            return status_proc.stdout.strip() # e.g., "Playing", "Paused", "Stopped"
        return "Stopped" # Default if status command has non-zero rc but didn't raise exception
    except (OSError, subprocess.TimeoutExpired, ValueError):
        return "Stopped"

def get_loop_status(player_name):
    """Get loop status using playerctl loop."""
    try:
        loop_proc = subprocess.run(
            ["playerctl", f"--player={player_name}", "loop"],
            capture_output=True, text=True, timeout=0.5
        )
        if loop_proc.returncode == 0:
             return loop_proc.stdout.strip() # e.g., "Track", "Playlist", "None"
        return "None"
    except (OSError, subprocess.TimeoutExpired, ValueError):
        return "None"

def get_shuffle_status(player_name):
    """Get shuffle status using playerctl shuffle. Returns boolean."""
    try:
        shuffle_proc = subprocess.run(
            ["playerctl", f"--player={player_name}", "shuffle"],
            capture_output=True, text=True, timeout=0.5
        )
        if shuffle_proc.returncode == 0:
            shuffle_state = shuffle_proc.stdout.strip().lower()
            return shuffle_state == "on" or shuffle_state == "true"
        return False # Default to False if command has non-zero rc
    except (OSError, subprocess.TimeoutExpired, ValueError):
        return False

def get_current_position_seconds(player_name):
    """Get current track position in seconds using 'playerctl position'."""
    try:
        pos_proc = subprocess.run(
            ["playerctl", f"--player={player_name}", "position"],
            capture_output=True, text=True, timeout=0.5
        )
        if pos_proc.returncode == 0 and pos_proc.stdout.strip():
            # playerctl position returns seconds, possibly with decimals
            return float(pos_proc.stdout.strip())
        return 0.0 # Default to 0.0 if no output or error
    except (OSError, subprocess.TimeoutExpired, ValueError, TypeError): # Added TypeError for float conversion
        return 0.0 # Default to 0.0 on any error

def get_player_volume(player_name):
    """Get the current player volume as a float between 0.0 and 1.0."""
    try:
        proc = subprocess.run(
            ["playerctl", f"--player={player_name}", "volume"],
            capture_output=True, text=True, timeout=0.5
        )
        if proc.returncode == 0 and proc.stdout.strip():
            return float(proc.stdout.strip())
        return None
    except (OSError, subprocess.TimeoutExpired, ValueError, TypeError):
        return None

def sanitize_markup(text):
    """Escape characters that would break pango markup"""
    if text is None:
        return ""
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("'", "&#39;").replace('"', "&quot;")

# Album art functionality removed: no fetching, caching, or cleanup

def main():
    global DEBUG_MODE # Declare DEBUG_MODE as global to modify it

    parser = argparse.ArgumentParser(description="Waybar Media Player Controller")
    parser.add_argument("-p", "--player", type=str, default="spotify", 
                        help="Name of the media player to control (e.g., spotify, vlc). Default: spotify")
    parser.add_argument("--debug", action="store_true", 
                        help="Enable debug logging to stderr.")
    args = parser.parse_args()
    player_name = args.player
    DEBUG_MODE = args.debug # Set the global debug flag

    if DEBUG_MODE:
        print(f"DEBUG: Debug mode enabled. Player: {player_name}", file=sys.stderr)

    no_player_count = 0
    # Scrolling generator state
    scroll_generator = None
    last_title_for_scroll = None
    
    while True:
        output_text = f" {no_player_icon} Initializing... "
        tooltip_text = "Player status initializing..."
        status_class = "stopped"

        if check_player_available(player_name):
            no_player_count = 0 
            
            playback_status_val = get_playing_status(player_name).lower()
            loop_status_val = get_loop_status(player_name).lower()
            is_shuffling_val = get_shuffle_status(player_name)

            if playback_status_val == "stopped" or not playback_status_val:
                icon = no_player_icon 
                output_text = f" {icon} {sanitize_markup(player_name)} Stopped "
                tooltip_text = f"Player {sanitize_markup(player_name)} is stopped."
                status_class = "stopped"
            else: # Playing or Paused
                try:
                    metadata = get_all_metadata(player_name)
                    current_pos_sec = get_current_position_seconds(player_name)

                    title = metadata.get("title", "Unknown Title")
                    artist = metadata.get("artist", "Unknown Artist")
                    album = metadata.get("album", "Unknown Album")
                    # Album art removed
                    length_us = metadata.get("length_us", 0)
                    # current_position_us = metadata.get("position_us", 0) # Removed

                    icon = playing_icon if playback_status_val == "playing" else paused_icon
                    status_class = "playing" if playback_status_val == "playing" else "paused"

                    length_seconds = length_us // 1000000
                    length_display = f"{length_seconds//60}:{length_seconds%60:02d}"
                    
                    # Use current_pos_sec directly (it's already in seconds)
                    # Ensure it's an integer for formatting if it was float
                    pos_seconds_int = int(current_pos_sec) 
                    position_display = f"{pos_seconds_int//60}:{pos_seconds_int%60:02d}"

                    title_display = title
                    if len(title) > SCROLL_TEXT_LENGTH:
                        if scroll_generator is None or title != last_title_for_scroll:
                            scroll_generator = scroll_text(title)
                            last_title_for_scroll = title
                        try: title_display = next(scroll_generator)
                        except StopIteration: 
                            scroll_generator = scroll_text(title)
                            title_display = next(scroll_generator)
                    else: scroll_generator = None
                    
                    if loop_status_val == "track":
                        looping_icon_val = loop_icon
                        loop_status_text = "Track"
                    elif loop_status_val == "playlist":
                        looping_icon_val = playlist_loop
                        loop_status_text = "Playlist"
                    else: 
                        looping_icon_val = not_loop_icon
                        loop_status_text = "Off"
                    
                    shuffling_icon_val = shuffle_icon if is_shuffling_val else not_shuffle_icon
                    shuffle_status_text = "On" if is_shuffling_val else "Off"
                    
                    player_icon_tooltip = "󱁫"
                    if player_name.lower() == "spotify": player_icon_tooltip = "󰓇"
                    elif "YoutubeMusic" in player_name.lower(): player_icon_tooltip = ""
                    elif "youtube" in player_name.lower(): player_icon_tooltip = "󰗃"
                    elif "chrome" in player_name.lower(): player_icon_tooltip = ""
                    elif "firefox" in player_name.lower(): player_icon_tooltip = "󰈹"
                    elif "mpv" in player_name.lower(): player_icon_tooltip = "󰝚"
                    elif "vlc" in player_name.lower(): player_icon_tooltip = "󰕼"
                    
                    volume_val = get_player_volume(player_name)
                    volume_display = f"{int(volume_val * 100)}%" if volume_val is not None else "N/A"
                    
                    tooltip_lines = [f"<span color='{PRIMARY_COLOR}'><b>{player_icon_tooltip} {sanitize_markup(player_name)} Media Player</b></span>", ""]
                    tooltip_lines.extend([
                        f" ├─ Title: {sanitize_markup(title)}", f" ├─ Volume: {volume_display}", f" ├─ Artist: {sanitize_markup(artist)}", f" └─ Album: {sanitize_markup(album)}", "",
                        f" ├─ Time: {position_display}/{length_display}", f" ├─ Loop: {loop_status_text}", f" └─ Shuffle: {shuffle_status_text}",
                        
                    ])
                    tooltip_text = "\n".join(tooltip_lines)
                    
                    output_text = (f" {icon} {sanitize_markup(title_display)} "
                                 f"[{position_display}/{length_display}] {volume_display} {looping_icon_val} {shuffling_icon_val} ")
                except Exception as e:
                    # This error is if metadata fetching or string formatting fails, assumes player status was ok
                    icon = paused_icon # Default to paused if playing status was ok but other things failed
                    if playback_status_val == "playing": icon = playing_icon
                    output_text = f" {icon} Player Info Error " 
                    tooltip_text = f"Error getting details for {sanitize_markup(player_name)}: {sanitize_markup(str(e))}"
                    status_class = "error"
        else: # Player not available
            no_player_count += 1 
            # If player is not running after multiple checks, exit
            if no_player_count > 3:
                output = {"text": "", "tooltip": "Player not running", "class": "stopped"}
                print(json.dumps(output))
                sys.stdout.flush()
                sys.exit(0)
            output_text = f" {no_player_icon} No media player "
            tooltip_text = f"Player '{sanitize_markup(player_name)}' not found or not responsive."
            status_class = "stopped"
            
        output = {"text": output_text, "tooltip": tooltip_text, "class": status_class}
        print(json.dumps(output))
        sys.stdout.flush()
        
        # Album art cleanup removed
        
        # Sleep: faster if scrolling, slower if needed
        if no_player_count > 5:
            time.sleep(3)  # Less frequent when no players are active
        else:
            # Faster updates when title is scrolling
            if scroll_generator is not None:
                time.sleep(SCROLL_INTERVAL)
            else:
                time.sleep(0.5)
        

if __name__ == "__main__":
    main()