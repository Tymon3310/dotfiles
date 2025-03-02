#!/usr/bin/python3
# filepath: /home/tymon/dotfiles/.config/waybar/scripts/power.py

import json
import sys
import os
import glob
from pathlib import Path

# Configuration
CPU_POWER_PATH = "/sys/class/hwmon/hwmon4/power1_input"
GPU_POWER_PATH = "/sys/class/drm/card1/device/hwmon/hwmon3/power1_average"
TOTAL_POWER_FORMAT = " {total:.1f}W "
DETAILED_FORMAT = "CPU: {cpu:.1f}W | GPU: {gpu:.1f}W"

# Fallback paths using glob patterns
CPU_POWER_PATTERNS = [
    "/sys/class/hwmon/hwmon*/power1_input",
    "/sys/devices/platform/amd_energy/energy*_input"
]

GPU_POWER_PATTERNS = [
    "/sys/class/drm/card*/device/hwmon/hwmon*/power1_average", 
    "/sys/class/hwmon/hwmon*/device/power1_average"
]

def find_path(patterns):
    """Find existing file path from a list of glob patterns"""
    for pattern in patterns:
        paths = glob.glob(pattern)
        if paths:
            return paths[0]
    return None

def read_power_file(path):
    """Read power value from file in microwatts and return in watts"""
    if not os.path.exists(path):
        return 0.0
    
    try:
        with open(path, 'r') as f:
            value = int(f.read().strip())
            # Convert from microwatts to watts
            return value / 1000000.0
    except (IOError, ValueError):
        return 0.0

def main():
    # Find paths if defaults don't exist
    if not os.path.exists(CPU_POWER_PATH):
        cpu_path = find_path(CPU_POWER_PATTERNS)
    else:
        cpu_path = CPU_POWER_PATH
        
    if not os.path.exists(GPU_POWER_PATH):
        gpu_path = find_path(GPU_POWER_PATTERNS)
    else:
        gpu_path = GPU_POWER_PATH
    
    # Read power values
    cpu_power = read_power_file(cpu_path) if cpu_path else 0.0
    gpu_power = read_power_file(gpu_path) if gpu_path else 0.0
    total_power = cpu_power + gpu_power
    
    # Prepare output
    output = {
        "text": TOTAL_POWER_FORMAT.format(total=total_power),
        "tooltip": f"<span color='#8bd5ca'>󰹬 Power Consumption:</span>\n"
                  f" ├─ CPU: {cpu_power:.1f}W ({cpu_power/total_power*100:.1f}% of total)\n"
                  f" ├─ GPU: {gpu_power:.1f}W ({gpu_power/total_power*100:.1f}% of total)\n"
                  f" └─ Total: {total_power:.1f}W\n\n"
                  f"<span color='#f4b8e4'>Source:</span>\n"
                  f" ├─ CPU: {cpu_path or 'Not found'}\n"
                  f" └─ GPU: {gpu_path or 'Not found'}"
    }
    
    # If any power sources failed, show warning in tooltip
    if not cpu_path or not gpu_path:
        missing = []
        if not cpu_path:
            missing.append("CPU")
        if not gpu_path:
            missing.append("GPU")
        output["tooltip"] += f"\n\n<span color='#f38ba8'>⚠ Warning: {', '.join(missing)} power sensor not found</span>"
    
    # Print JSON output for Waybar
    print(json.dumps(output))

if __name__ == "__main__":
    main()