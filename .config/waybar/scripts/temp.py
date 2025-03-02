#!/usr/bin/python3
# filepath: /home/tymon/dotfiles/.config/waybar/scripts/temp.py

import json
import sys
import os
import glob
import argparse
from pathlib import Path

# Configuration
CPU_TEMP_PATH = "/sys/class/hwmon/hwmon4/temp2_input"
GPU_TEMP_PATH = "/sys/class/drm/card1/device/hwmon/hwmon3/temp1_input"

# Fallback paths using glob patterns
CPU_TEMP_PATTERNS = [
    "/sys/class/hwmon/hwmon*/temp*_input",
    "/sys/devices/platform/coretemp.*/hwmon/hwmon*/temp1_input"
]

GPU_TEMP_PATTERNS = [
    "/sys/class/drm/card*/device/hwmon/hwmon*/temp1_input",
    "/sys/class/hwmon/hwmon*/device/hwmon*/temp1_input"
]

# Find additional sensors for details
CPU_ADDITIONAL_PATTERNS = {
    "tctl": "/sys/class/hwmon/hwmon*/temp1_input",
    "tccd1": "/sys/class/hwmon/hwmon*/temp3_input",
    "tccd2": "/sys/class/hwmon/hwmon*/temp4_input"
}

GPU_ADDITIONAL_PATTERNS = {
    "junction": "/sys/class/drm/card*/device/hwmon/hwmon*/temp2_input",
    "memory": "/sys/class/drm/card*/device/hwmon/hwmon*/temp3_input",
    "hotspot": "/sys/class/drm/card*/device/hwmon/hwmon*/temp4_input"
}

def find_path(patterns):
    """Find existing file path from a list of glob patterns"""
    if isinstance(patterns, str):
        paths = glob.glob(patterns)
        return paths[0] if paths else None
    
    for pattern in patterns:
        paths = glob.glob(pattern)
        if paths:
            return paths[0]
    return None

def read_temp_file(path):
    """Read temperature value from file in millidegrees and return in degrees Celsius"""
    if not path or not os.path.exists(path):
        return None
    
    try:
        with open(path, 'r') as f:
            value = int(f.read().strip())
            # Convert from millidegrees to degrees
            return value / 1000.0
    except (IOError, ValueError):
        return None

def get_cpu_temp():
    # Find path if default doesn't exist
    if not os.path.exists(CPU_TEMP_PATH):
        cpu_path = find_path(CPU_TEMP_PATTERNS)
    else:
        cpu_path = CPU_TEMP_PATH
    
    # Read temperature value
    temp = read_temp_file(cpu_path)
    
    # Read additional sensors
    additional_temps = {}
    for name, pattern in CPU_ADDITIONAL_PATTERNS.items():
        path = find_path(pattern)
        if path:
            value = read_temp_file(path)
            if value:
                additional_temps[name] = value
    
    # Critical temperature for AMD CPUs is typically around 95°C
    critical_temp = 95.0
    
    # Format output for Waybar
    if temp is not None:
        output = {
            "text": f" {temp:.1f}°C ",
            "tooltip": f"<span color='#8bd5ca'>󰔏 CPU Temperature:</span>\n"
                      f" ├─ Core: {temp:.1f}°C\n"
        }
        
        # Add additional sensors to tooltip
        if additional_temps:
            for i, (name, value) in enumerate(additional_temps.items()):
                if i == len(additional_temps) - 1:
                    output["tooltip"] += f" └─ {name.capitalize()}: {value:.1f}°C\n"
                else:
                    output["tooltip"] += f" ├─ {name.capitalize()}: {value:.1f}°C\n"
        else:
            output["tooltip"] += f" └─ Critical: {critical_temp}°C\n"
        
        # Add warning if temperature is high
        if temp > critical_temp - 10:
            output["tooltip"] += f"\n<span color='#f38ba8'>⚠ Warning: CPU temperature is high!</span>"
            output["class"] = "critical"
    else:
        output = {
            "text": " N/A ",
            "tooltip": "CPU temperature sensor not found",
            "class": "error"
        }
    
    return output

def get_gpu_temp():
    # Find path if default doesn't exist
    if not os.path.exists(GPU_TEMP_PATH):
        gpu_path = find_path(GPU_TEMP_PATTERNS)
    else:
        gpu_path = GPU_TEMP_PATH
    
    # Read temperature value
    temp = read_temp_file(gpu_path)
    
    # Read additional sensors
    additional_temps = {}
    for name, pattern in GPU_ADDITIONAL_PATTERNS.items():
        path = find_path(pattern)
        if path:
            value = read_temp_file(path)
            if value:
                additional_temps[name] = value
    
    # Critical temperature for AMD GPUs is typically around 110°C for junction
    critical_temp = 110.0 if "junction" in additional_temps else 95.0
    
    # Format output for Waybar
    if temp is not None:
        output = {
            "text": f" {temp:.1f}°C ",
            "tooltip": f"<span color='#f4b8e4'>󰔏 GPU Temperature:</span>\n"
                      f" ├─ Edge: {temp:.1f}°C\n"
        }
        
        # Add additional sensors to tooltip
        if additional_temps:
            for i, (name, value) in enumerate(additional_temps.items()):
                if i == len(additional_temps) - 1:
                    output["tooltip"] += f" └─ {name.capitalize()}: {value:.1f}°C\n"
                else:
                    output["tooltip"] += f" ├─ {name.capitalize()}: {value:.1f}°C\n"
        else:
            output["tooltip"] += f" └─ Critical: {critical_temp}°C\n"
        
        # Add warning if temperature is high
        junction_temp = additional_temps.get("junction", temp)
        if junction_temp > critical_temp - 10:
            output["tooltip"] += f"\n<span color='#f38ba8'>⚠ Warning: GPU temperature is high!</span>"
            output["class"] = "critical"
    else:
        output = {
            "text": " N/A ",
            "tooltip": "GPU temperature sensor not found",
            "class": "error"
        }
    
    return output

def main():
    # Parse command line arguments
    parser = argparse.ArgumentParser(description='Get CPU or GPU temperature for Waybar')
    parser.add_argument('device', choices=['cpu', 'gpu'], help='Device to get temperature for')
    args = parser.parse_args()
    
    # Get temperature for specified device
    if args.device == 'cpu':
        output = get_cpu_temp()
    else:
        output = get_gpu_temp()
    
    # Print JSON output for Waybar
    print(json.dumps(output))

if __name__ == "__main__":
    main()