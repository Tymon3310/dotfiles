#!/usr/bin/python3
import json
import glob
import os

PRIMARY_COLOR = "#48A3FF"
WARNING_COLOR = "#ff9a3c"
CRITICAL_COLOR = "#dc2f2f"

def get_val(path):
    try:
        with open(path, 'r') as f: return int(f.read().strip()) / 1000000.0
    except: return 0.0

def scan_sensors():
    paths = {}
    for hwmon in glob.glob("/sys/class/hwmon/hwmon*"):
        try:
            with open(f"{hwmon}/name", 'r') as f: name = f.read().strip()
            if name in ['k10temp', 'zenpower']:
                if os.path.exists(f"{hwmon}/power1_input"): paths['cpu'] = f"{hwmon}/power1_input"
            if name == 'amdgpu':
                if os.path.exists(f"{hwmon}/power1_average"): paths['gpu'] = f"{hwmon}/power1_average"
                elif os.path.exists(f"{hwmon}/power1_input"): paths['gpu'] = f"{hwmon}/power1_input"
        except: continue
    return paths

def main():
    paths = scan_sensors()
    cpu_w = get_val(paths.get('cpu', ''))
    gpu_w = get_val(paths.get('gpu', ''))
    other_w = 40 + 25 + 45 
    total_w = cpu_w + gpu_w + other_w
    
    if total_w > 320: text = f"<span color='{CRITICAL_COLOR}'> {total_w:.0f}W</span>"; css = "critical"
    elif total_w > 200: text = f"<span color='{WARNING_COLOR}'> {total_w:.0f}W</span>"; css = "warning"
    else: text = f" {total_w:.0f}W"; css = "normal"

    tooltip = f"<span color='{PRIMARY_COLOR}'>Power Usage:</span>\n"
    tooltip += f" ├─ CPU: {cpu_w:.1f}W\n"
    tooltip += f" ├─ GPU: {gpu_w:.1f}W\n"
    tooltip += f" └─ Total: {total_w:.1f}W (est)"

    print(json.dumps({"text": text, "tooltip": tooltip, "class": css}))

if __name__ == "__main__":
    main()