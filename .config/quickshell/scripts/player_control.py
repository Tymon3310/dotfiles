#!/usr/bin/env python3
import sys
import os
import subprocess
import socket
import json

SOURCE_FILE = "/tmp/active_media_source"
IPC_SOCKET = "/tmp/mpv-radio-ipc"
STREAM_URL = "https://ic1.smcdn.pl/6030-1.mp3"
VOLUME_FILE = "/tmp/radio_volume"

def get_saved_volume():
    try:
        if os.path.exists(VOLUME_FILE):
            with open(VOLUME_FILE, "r") as f:
                return int(f.read().strip())
    except:
        pass
    return 60  # default to 60%

def save_radio_volume():
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.settimeout(0.1)
        s.connect(IPC_SOCKET)
        s.sendall(json.dumps({"command": ["get_property", "volume"]}).encode() + b"\n")
        res = json.loads(s.recv(1024).decode().splitlines()[0])
        s.close()
        vol = res.get("data")
        if vol is not None:
            with open(VOLUME_FILE, "w") as f:
                f.write(str(int(vol)))
    except:
        pass

def get_active_source():
    try:
        if os.path.exists(SOURCE_FILE):
            with open(SOURCE_FILE, "r") as f:
                src = f.read().strip().lower()
                if src in ("spotify", "radio"):
                    return src
    except:
        pass
    return "spotify"

def set_active_source(src):
    try:
        with open(SOURCE_FILE, "w") as f:
            f.write(src)
    except Exception as e:
        sys.stderr.write(f"Error writing source file: {e}\n")

def is_mpv_running():
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.settimeout(0.1)
        s.connect(IPC_SOCKET)
        s.close()
        return True
    except:
        return False

def send_mpv_command(cmd):
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.settimeout(0.2)
        s.connect(IPC_SOCKET)
        s.sendall((json.dumps({"command": cmd}) + "\n").encode())
        res = s.recv(4096).decode()
        s.close()
        return True
    except Exception as e:
        sys.stderr.write(f"Error sending mpv command: {e}\n")
        return False

def start_radio():
    if is_mpv_running():
        return
    vol = get_saved_volume()
    try:
        # Launch mpv detached with saved volume
        subprocess.Popen([
            "mpv",
            "--no-video",
            f"--volume={vol}",
            f"--input-ipc-server={IPC_SOCKET}",
            STREAM_URL
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    except Exception as e:
        sys.stderr.write(f"Error starting mpv: {e}\n")

def stop_radio():
    # Attempt clean exit first
    if is_mpv_running():
        send_mpv_command(["quit"])
    # Just in case, kill any leftover process
    try:
        subprocess.run(["pkill", "-f", f"input-ipc-server={IPC_SOCKET}"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except:
        pass

def main():
    args = sys.argv[1:]
    if not args:
        print("Usage: player_control.py <command> [args...]")
        sys.exit(1)
        
    cmd = args[0]
    source = get_active_source()
    
    if cmd == "toggle-source":
        if source == "spotify":
            # Switch to radio
            # Pause spotify
            subprocess.run(["playerctl", "--player=spotify", "pause"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            set_active_source("radio")
            start_radio()
            print("Switched to radio")
        else:
            # Switch to spotify
            stop_radio()
            set_active_source("spotify")
            # Play spotify
            subprocess.run(["playerctl", "--player=spotify", "play"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            print("Switched to spotify")
            
    elif source == "radio":
        # Handle commands for radio stream
        if cmd == "play-pause":
            if is_mpv_running():
                stop_radio()
                print("Radio stopped")
            else:
                start_radio()
                print("Radio started")
        elif cmd == "volume":
            if len(args) > 1:
                val = args[1] # e.g. "0.05+" or "0.05-"
                if "+" in val:
                    send_mpv_command(["cycle", "volume", "5"])
                elif "-" in val:
                    send_mpv_command(["cycle", "volume", "-5"])
                import time
                time.sleep(0.05)
                save_radio_volume()
        elif cmd in ("next", "previous"):
            # Restart stream
            stop_radio()
            import time
            time.sleep(0.5)
            start_radio()
            print("Radio restarted")
        elif cmd == "position":
            if len(args) > 1:
                try:
                    import time
                    pos = float(args[1])
                    start_time = time.time() - pos
                    with open("/tmp/radio_position_offset", "w") as f:
                        f.write(str(start_time))
                    print(f"Set radio track start time offset to: {start_time}")
                except Exception as e:
                    sys.stderr.write(f"Error setting radio position: {e}\n")
        
    else:
        # Handle commands for Spotify
        if cmd == "play-pause":
            subprocess.run(["playerctl", "--player=spotify", "play-pause"])
        elif cmd == "volume":
            if len(args) > 1:
                subprocess.run(["playerctl", "--player=spotify", "volume", args[1]])
        elif cmd == "next":
            subprocess.run(["playerctl", "--player=spotify", "next"])
        elif cmd == "previous":
            subprocess.run(["playerctl", "--player=spotify", "previous"])
        elif cmd == "shuffle":
            subprocess.run(["playerctl", "--player=spotify", "shuffle", "Toggle"])
        elif cmd == "loop":
            subprocess.run(["playerctl", "--player=spotify", "loop", "Toggle"])
        elif cmd == "position":
            if len(args) > 1:
                subprocess.run(["playerctl", "--player=spotify", "position", args[1]])

if __name__ == "__main__":
    main()
