#!/bin/python3
# this is a Waybar Widget for controlling media players with playlist info
import subprocess
import json
import time
import sys
import random
import math
import os
import tempfile
import threading
import shutil

# Standard colors for all scripts - updated with lighter primary color
PRIMARY_COLOR = "#48A3FF"     # Lighter blue color that's more visible
WHITE_COLOR = "#FFFFFF"       # White text color
WARNING_COLOR = "#ff9a3c"     # Orange warning color from CSS .yellow 
CRITICAL_COLOR = "#dc2f2f"    # Red critical color from CSS .red
NEUTRAL_COLOR = "#FFFFFF"     # White for normal text
HEADER_COLOR = "#48A3FF"      # Lighter blue for section headers

# Use "any" to detect any available player instead of hardcoding "spotify"
player = "spotify"

# Restore ALL original icons
no_player_icon = "󰝛"  # Icon when no player is available
playing_icon = ""     # Original playing icon
paused_icon = ""      # Original paused icon
loop_icon = "󰑘"       # Original loop icon
playlist_loop = "󰑖"   # Original playlist loop icon
not_loop_icon = "󰑗"   # Original not loop icon
shuffle_icon = "󰒟"    # Original shuffle icon (restored!)
not_shuffle_icon = "󰒞" # Original not shuffle icon

# Check if cava is installed
HAS_CAVA = shutil.which("cava") is not None

# Cleaner visualizer settings
VISUALIZER_BARS = 16       # Number of bars
VISUALIZER_HEIGHT = 8       # Height in characters
current_visualizer = None   # Store current visualizer
cava_process = None         # Store cava process

# Temporary config for cava
CAVA_CONFIG = """
[general]
bars = 16
framerate = 60
[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 8
"""
# Scrolling text settings
SCROLL_TEXT_LENGTH = 20  # Number of characters for title scroll window
SCROLL_INTERVAL = 0.2   # Seconds between scroll steps

def scroll_text(text, length=SCROLL_TEXT_LENGTH):
    text = text.ljust(length)
    scrolling = text + ' | ' + text[:length]
    for i in range(len(scrolling) - length + 1):
        yield scrolling[i:i+length]

def start_cava():
    """Start cava in the background and return process"""
    if not HAS_CAVA:
        return None
        
    try:
        # Create temp config
        fd, config_path = tempfile.mkstemp(prefix="waybar_cava_")
        with os.fdopen(fd, 'w') as f:
            f.write(CAVA_CONFIG)
        
        # Start cava process
        process = subprocess.Popen(
            ["cava", "-p", config_path],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL
        )
        return process
    except Exception:
        return None

def get_cava_visualizer(cava_proc):
    """Get visualizer output from cava"""
    if not cava_proc:
        return None
        
    try:
        # Read exactly one frame of cava output
        line = cava_proc.stdout.readline().decode('utf-8').strip()
        if not line:
            return None
            
        # Parse values
        values = [int(x) for x in line.split(';') if x]
        
        # Build the visualizer
        visualizer = []
        for h in range(VISUALIZER_HEIGHT, 0, -1):
            row = ""
            for val in values:
                if val >= h:
                    row += "█"
                else:
                    row += " "
            visualizer.append(row)
            
        return "\n".join(visualizer)
    except Exception:
        return None

def get_simple_visualizer():
    """Generate a simple text-based audio visualizer"""
    global current_visualizer
    
    # Create simple wave-like pattern
    visualizer = []
    
    # Generate values that look like a sound wave
    values = []
    for i in range(VISUALIZER_BARS):
        # Create a wave pattern
        center_dist = abs(i - VISUALIZER_BARS/2) / (VISUALIZER_BARS/2)
        base_height = VISUALIZER_HEIGHT * 0.5  # Base height in middle
        var_height = VISUALIZER_HEIGHT * 0.3   # Variable component
        
        # Create a smooth wave pattern with some randomness
        wave = base_height * (1 - center_dist*0.7) + random.random() * var_height
        values.append(int(wave))
    
    # Build the visualizer
    for h in range(VISUALIZER_HEIGHT, 0, -1):
        row = ""
        for val in values:
            if val >= h:
                row += "█"
            else:
                row += " "
        visualizer.append(row)
        
    current_visualizer = "\n".join(visualizer)
    return current_visualizer

def get_visualizer():
    """Get the best available visualizer"""
    global cava_process
    
    # Try using cava if available
    if HAS_CAVA:
        if not cava_process or cava_process.poll() is not None:
            cava_process = start_cava()
            
        if cava_process:
            vis = get_cava_visualizer(cava_process)
            if vis:
                return vis
    
    # Fall back to simple visualizer
    return get_simple_visualizer()

def check_player_available():
    """Check if the specified media player is available"""
    try:
        # Check if the specified player is available
        check = subprocess.run(
            ["playerctl", f"--player={player}", "status"], 
            capture_output=True, 
            text=True, 
            timeout=1
        )
        # If we don't get an error, player is available
        return check.returncode == 0
    except Exception:
        return False

def get_title():
    """Get the title of the current track"""
    try:
        title = subprocess.run(
            ["playerctl", f"--player={player}", "metadata", "xesam:title"],
            capture_output=True,
            text=True,
            timeout=1
        )
        return title.stdout.strip() or "Unknown Title"
    except Exception:
        return "Unknown Title"

def get_artist():
    """Get the artist of the current track"""
    try:
        artist = subprocess.run(
            ["playerctl", f"--player={player}", "metadata", "xesam:artist"],
            capture_output=True,
            text=True,
            timeout=1
        )
        return artist.stdout.strip() or "Unknown Artist"
    except Exception:
        return "Unknown Artist"

def get_album():
    """Get the album of the current track"""
    try:
        album = subprocess.run(
            ["playerctl", f"--player={player}", "metadata", "xesam:album"],
            capture_output=True,
            text=True,
            timeout=1
        )
        return album.stdout.strip() or "Unknown Album"
    except Exception:
        return "Unknown Album"

def get_album_art():
    """Get album art URL"""
    try:
        art = subprocess.run(
            ["playerctl", f"--player={player}", "metadata", "mpris:artUrl"],
            capture_output=True,
            text=True,
            timeout=1
        )
        return art.stdout.strip()
    except Exception:
        return ""

def get_playing():
    """Get the play/pause status"""
    try:
        status = subprocess.run(
            ["playerctl", f"--player={player}", "status"],
            capture_output=True,
            text=True,
            timeout=1
        )
        if status.stdout.strip().lower() == "playing":
            return playing_icon
        else:
            return paused_icon
    except Exception:
        return paused_icon

def get_position():
    """Get the current position in the track"""
    try:
        pos = subprocess.run(
            ["playerctl", f"--player={player}", "position"],
            capture_output=True,
            text=True,
            timeout=1
        )
        seconds = int(float(pos.stdout.strip()))
        return f"{seconds//60}:{seconds%60:02d}"
    except Exception:
        return "0:00"

def get_length():
    """Get the length of the current track"""
    try:
        length = subprocess.run(
            ["playerctl", f"--player={player}", "metadata", "mpris:length"],
            capture_output=True,
            text=True,
            timeout=1
        )
        # Convert from microseconds to seconds
        seconds = int(int(length.stdout.strip()) / 1000000)
        return f"{seconds//60}:{seconds%60:02d}"
    except Exception:
        return "0:00"

def get_loop():
    """Get loop status"""
    try:
        loop = subprocess.run(
            ["playerctl", f"--player={player}", "loop"],
            capture_output=True,
            text=True,
            timeout=1
        )
        loop_status = loop.stdout.strip().lower()
        if loop_status == "track":
            return loop_icon
        elif loop_status == "playlist":
            return playlist_loop
        else:
            return not_loop_icon
    except Exception:
        return not_loop_icon

def get_shuffle():
    """Get shuffle status"""
    try:
        shuffle = subprocess.run(
            ["playerctl", f"--player={player}", "shuffle"],
            capture_output=True,
            text=True,
            timeout=1
        )
        if shuffle.stdout.strip().lower() == "true" or shuffle.stdout.strip() == "on" or shuffle.stdout.strip() == "On":
            return shuffle_icon
        else:
            return not_shuffle_icon
    except Exception:
        return not_shuffle_icon

def sanitize_markup(text):
    """Escape characters that would break pango markup"""
    if text is None:
        return ""
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("'", "&#39;").replace('"', "&quot;")

def get_and_process_album_art():
    """Get and process album art for display in tooltip"""
    try:
        # Get art URL
        art_url = get_album_art()
        if not art_url:
            return None

        # Create cache directory if it doesn't exist
        cache_dir = os.path.expanduser("~/.cache/waybar-player")
        os.makedirs(cache_dir, exist_ok=True)
        
        # Generate a filename based on the URL hash
        art_filename = os.path.join(cache_dir, f"cover_{hash(art_url) % 10000}.jpg")
        
        # Only download if file doesn't exist or is old
        if not os.path.exists(art_filename) or (time.time() - os.path.getmtime(art_filename)) > 3600:
            if art_url.startswith("file://"):
                # Local file, just copy or symlink it
                local_path = art_url[7:]  # Remove file:// prefix
                shutil.copy(local_path, art_filename)
            else:
                # Remote URL, download it
                subprocess.run(["curl", "-s", "-o", art_filename, art_url], timeout=2)
        
        # Return path if file exists and is not empty
        if os.path.exists(art_filename) and os.path.getsize(art_filename) > 0:
            return art_filename
        
        return None
    except Exception:
        return None

def cleanup_old_album_art():
    """Clean up old album art files"""
    try:
        cache_dir = os.path.expanduser("~/.cache/waybar-player")
        if not os.path.exists(cache_dir):
            return
            
        # Keep only the 20 most recent files
        files = [os.path.join(cache_dir, f) for f in os.listdir(cache_dir)]
        files.sort(key=os.path.getmtime, reverse=True)
        
        # Delete older files
        for old_file in files[20:]:
            os.remove(old_file)
    except Exception:
        pass

def get_dominant_color(image_path):
    try:
        from PIL import Image
        import numpy as np
        
        # Open image and resize for faster processing
        img = Image.open(image_path).resize((100, 100))
        # Convert to numpy array
        colors = np.array(img)
        # Reshape the array to be 2D
        pixels = colors.reshape(-1, 3)
        # Get the most common color
        from collections import Counter
        counter = Counter(map(tuple, pixels))
        most_common = counter.most_common(1)[0][0]
        # Convert to hex
        return '#{:02x}{:02x}{:02x}'.format(most_common[0], most_common[1], most_common[2])
    except Exception:
        return PRIMARY_COLOR

def main():
    no_player_count = 0
    art_cleanup_counter = 0
    # Scrolling generator state
    scroll_generator = None
    last_title = None
    
    while True:
        try:
            # Simple direct check if player is available 
            player_available = check_player_available()
            
            if player_available:
                no_player_count = 0
                
                try:
                    icon = get_playing()
                    title = get_title()
                    # Scrolling title if too long
                    if len(title) > SCROLL_TEXT_LENGTH:
                        if scroll_generator is None or title != last_title:
                            scroll_generator = scroll_text(title)
                            last_title = title
                        try:
                            title_display = next(scroll_generator)
                        except StopIteration:
                            scroll_generator = scroll_text(title)
                            title_display = next(scroll_generator)
                    else:
                        # Short titles: use as-is without padding
                        title_display = title
                        scroll_generator = None
                    artist = get_artist()
                    album = get_album()
                    
                    
                    try:
                        position = get_position()
                        length = get_length()
                    except Exception as e:
                        position = "0:00"
                        length = "0:00"
                        
                    try:
                        looping = get_loop()
                        shuffling = get_shuffle()
                    except Exception as e:
                        looping = not_loop_icon
                        shuffling = not_shuffle_icon

                    # Format loop status text
                    if looping == loop_icon:
                        loop_status = "Track"
                    elif looping == playlist_loop:
                        loop_status = "Playlist"
                    else:
                        loop_status = "Off"
                    
                    # Format shuffle status text
                    shuffle_status = "On" if shuffling == shuffle_icon else "Off"
                    
                     # Add brackets around the output text for consistency
                    # Build display text with scrolling title
                    output_text = (
                        f" {icon} {sanitize_markup(title_display)} - {sanitize_markup(artist)} [{position}/{length}] {looping} {shuffling} "
                    )
                    
                    # Player-specific icon
                    player_icon = "󱁫"  # Default music player icon
                    if player.lower() == "spotify":
                        player_icon = "󰓇"  # Spotify icon
                    elif "YoutubeMusic" in player.lower():
                        player_icon = ""  # YouTube icon
                    elif "youtube" in player.lower():
                        player_icon = "󰗃"  # YouTube icon
                    elif "chrome" in player.lower():
                        player_icon = ""  # Chrome icon
                    elif "firefox" in player.lower():
                        player_icon = ""  # Firefox icon``
                    elif "mpv" in player.lower():
                        player_icon = "󰝚"  # MPV icon
                    elif "vlc" in player.lower():
                        player_icon = "󰕼"  # VLC icon
                    
                    # Get album art
                    art_path = get_and_process_album_art()

                    # Build tooltip without attempting to embed the image
                    if art_path:
                        tooltip_text = (
                            f"<span color='{PRIMARY_COLOR}'><b>{player_icon} {sanitize_markup(player)} Media Player</b></span>\n\n"
                            f"<span color='{PRIMARY_COLOR}'>♫ Album Art Available</span>\n\n"
                            f" ├─ Title: {sanitize_markup(title)}\n"
                            f" ├─ Artist: {sanitize_markup(artist)}\n"
                            f" └─ Album: {sanitize_markup(album)}\n"
                            f"\n"
                            f" ├─ Time: {position}/{length}\n"
                            f" ├─ Loop: {loop_status}\n"
                            f" └─ Shuffle: {shuffle_status}"
                        )
                    else:
                        # Standard tooltip without art
                        tooltip_text = (
                            f"<span color='{PRIMARY_COLOR}'><b>{player_icon} {sanitize_markup(player)} Media Player</b></span>\n\n"
                            f" ├─ Title: {sanitize_markup(title)}\n"
                            f" ├─ Artist: {sanitize_markup(artist)}\n"
                            f" └─ Album: {sanitize_markup(album)}\n"
                            f"\n"
                            f" ├─ Time: {position}/{length}\n"
                            f" ├─ Loop: {loop_status}\n"
                            f" └─ Shuffle: {shuffle_status}"
                        )
                    
                    # Add class based on playing status
                    status_class = "playing" if icon == playing_icon else "paused"
                    
                except Exception as e:
                    output_text = f" {paused_icon} Media player paused "
                    tooltip_text = f"Media player detected but error: {str(e)}"
                    status_class = "paused"
            else:
                output_text = f" {no_player_icon} No media playing "
                tooltip_text = "No active media player detected"
                status_class = "stopped"
                
                # Increase sleep time when no player is available
                no_player_count += 1
            
            # Include class in output for CSS styling
            output = {"text": output_text, "tooltip": tooltip_text, "class": status_class}
            print(json.dumps(output))
            sys.stdout.flush()
            
            # Call cleanup every hour (based on counter)
            art_cleanup_counter += 1
            if art_cleanup_counter >= 3600:
                cleanup_old_album_art()
                art_cleanup_counter = 0
            
            # Sleep: faster if scrolling, slower if needed
            if no_player_count > 5:
                time.sleep(3)  # Less frequent when no players are active
            else:
                # Faster updates when title is scrolling
                if scroll_generator is not None:
                    time.sleep(SCROLL_INTERVAL)
                else:
                    time.sleep(1)
                
        except Exception as e:
            # Handle any unexpected errors to keep the widget running
            print(json.dumps({
                "text": f" {no_player_icon} Error ",
                "tooltip": "Player error occurred",
                "class": "error"
            }))
            sys.stdout.flush()
            time.sleep(5)  # Wait before trying again


if __name__ == "__main__":
    try:
        main()
    finally:
        # Clean up cava process if it exists
        if cava_process and cava_process.poll() is None:
            cava_process.terminate()