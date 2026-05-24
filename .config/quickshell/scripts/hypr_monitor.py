#!/usr/bin/env python3
import json
import os
import socket
import subprocess
import sys
import time

def run_cmd(cmd):
    try:
        res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        return res.stdout
    except Exception as e:
        sys.stderr.write(f"Cmd error {cmd}: {e}\n")
        return ""

def get_state():
    try:
        workspaces_raw = run_cmd(["hyprctl", "-j", "workspaces"])
        monitors_raw = run_cmd(["hyprctl", "-j", "monitors"])
        active_window_raw = run_cmd(["hyprctl", "-j", "activewindow"])
        
        if not workspaces_raw or not monitors_raw:
            return None
            
        workspaces = json.loads(workspaces_raw)
        monitors = json.loads(monitors_raw)
        
        active_window = None
        if active_window_raw:
            try:
                aw = json.loads(active_window_raw)
                if aw and "class" in aw:
                    active_window = aw
            except Exception as e:
                pass
                
        state = {}
        for mon in monitors:
            mon_name = mon["name"]
            mon_id = mon["id"]
            active_ws = mon["activeWorkspace"]
            active_ws_id = active_ws["id"]
            active_ws_name = active_ws["name"]
            
            # Filter workspaces on this monitor and ignore special workspaces (id < 0)
            mon_workspaces = [ws for ws in workspaces if ws["monitor"] == mon_name and ws["id"] > 0]
            
            # Ensure the active workspace is included even if it has 0 windows
            has_active = any(ws["id"] == active_ws_id for ws in mon_workspaces)
            if not has_active and active_ws_id > 0:
                mon_workspaces.append({
                    "id": active_ws_id,
                    "name": active_ws_name,
                    "windows": 0,
                    "focused": True
                })
            else:
                # Mark active workspace as focused
                for ws in mon_workspaces:
                    if ws["id"] == active_ws_id:
                        ws["focused"] = True
                    else:
                        ws["focused"] = False
            
            # Filter: show only focused workspace or workspaces with active windows (windows > 0)
            filtered_ws = [ws for ws in mon_workspaces if ws.get("focused") or ws.get("windows", 0) > 0]
            
            # Sort workspaces by ID
            filtered_ws.sort(key=lambda x: x["id"])
            
            # Find active window for this monitor
            mon_active_window = None
            if active_window and active_window.get("monitor") == mon_id:
                mon_active_window = {
                    "title": active_window.get("title", ""),
                    "class": active_window.get("class", "")
                }
                
            state[mon_name] = {
                "active_workspace": active_ws_id,
                "active_window": mon_active_window,
                "workspaces": filtered_ws,
                "focused": mon.get("focused", False)
            }
        return state
    except Exception as e:
        return {"error": str(e)}

def main():
    signature = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if not signature:
        sys.stderr.write("HYPRLAND_INSTANCE_SIGNATURE not found in environment.\n")
        # Output fallback and exit
        sys.exit(1)

    xdg_runtime_dir = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    socket_path = f"{xdg_runtime_dir}/hypr/{signature}/.socket2.sock"
    if not os.path.exists(socket_path):
        socket_path = f"/tmp/hypr/{signature}/.socket2.sock"
    
    # 1. Print initial state
    initial_state = get_state()
    if initial_state:
        print(json.dumps(initial_state), flush=True)
    
    # 2. Main socket listening loop
    while True:
        try:
            if not os.path.exists(socket_path):
                time.sleep(2)
                continue
                
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.connect(socket_path)
            
            # Keep track of last printed state to avoid duplicate output
            last_state = initial_state
            
            # Read buffer
            buffer = ""
            while True:
                data = s.recv(4096)
                if not data:
                    break
                    
                buffer += data.decode("utf-8", errors="ignore")
                while "\n" in buffer:
                    line, buffer = buffer.split("\n", 1)
                    # We have an event, let's wait a tiny bit to let state settle
                    time.sleep(0.03)
                    # Fetch state
                    current_state = get_state()
                    if current_state and current_state != last_state:
                        print(json.dumps(current_state), flush=True)
                        last_state = current_state
                        
        except KeyboardInterrupt:
            break
        except Exception as e:
            sys.stderr.write(f"Socket connection error: {e}\n")
            time.sleep(2)

if __name__ == "__main__":
    main()
