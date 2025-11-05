#!/usr/bin/python3
# filepath: ~/dotfiles/.config/waybar/scripts/temp.py

import json
import sys
import os
import glob
import argparse

# Configuration
CPU_TEMP_PATH = "/sys/class/hwmon/hwmon4/temp2_input"
GPU_TEMP_PATH = "/sys/class/drm/card1/device/hwmon/hwmon3/temp1_input"

# Temperature Offsets for Warnings (degrees Celsius)
CPU_CRITICAL_OFFSET = 5  # Degrees below critical to trigger 'critical' state
CPU_WARNING_OFFSET = 15  # Degrees below critical to trigger 'warning/high' state
GPU_CRITICAL_OFFSET = 10 # Degrees below critical to trigger 'critical' state for GPU
GPU_WARNING_OFFSET = 20  # Degrees below critical to trigger 'warning/high' state for GPU

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

# Standard colors for all scripts - updated with lighter primary color
PRIMARY_COLOR = "#48A3FF"     # Lighter blue color that's more visible
WHITE_COLOR = "#FFFFFF"       # White text color
WARNING_COLOR = "#ff9a3c"     # Orange warning color from CSS .yellow 
CRITICAL_COLOR = "#dc2f2f"    # Red critical color from CSS .red
NEUTRAL_COLOR = "#FFFFFF"     # White for normal text
HEADER_COLOR = "#48A3FF"      # Lighter blue for section headers

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
    # Default critical temperature if _crit file is not found or unreadable
    DEFAULT_CPU_CRITICAL_TEMP = 95.0
    critical_temp = DEFAULT_CPU_CRITICAL_TEMP

    # Find path if default doesn't exist
    cpu_path_to_read = CPU_TEMP_PATH
    if not os.path.exists(CPU_TEMP_PATH):
        cpu_path_to_read = find_path(CPU_TEMP_PATTERNS)
    
    # Read temperature value
    temp = read_temp_file(cpu_path_to_read)
    
    # Try to read critical temperature from corresponding _crit file
    if cpu_path_to_read:
        cpu_crit_path = cpu_path_to_read.replace("_input", "_crit")
        dynamic_critical_temp_val = read_temp_file(cpu_crit_path)
        if dynamic_critical_temp_val is not None:
            critical_temp = dynamic_critical_temp_val
    
    # Read additional sensors
    additional_temps = {}
    additional_temps_crits = {} # To store found critical temperatures for additional CPU sensors

    for name, pattern in CPU_ADDITIONAL_PATTERNS.items():
        path = find_path(pattern)
        if path:
            value = read_temp_file(path)
            if value:
                additional_temps[name] = value
                # Try to find critical temp for this additional CPU sensor
                sensor_crit_path = path.replace("_input", "_crit")
                dynamic_sensor_crit = read_temp_file(sensor_crit_path)
                if dynamic_sensor_crit is not None:
                    additional_temps_crits[name] = dynamic_sensor_crit
    
    # critical_temp is now dynamic or default (for the main sensor)
    
    # Format output for Waybar with conditional formatting for high temps
    if temp is not None:
        # CPU temperature formatting
        if temp > critical_temp - CPU_CRITICAL_OFFSET:  # Within critical offset
            output = {
                "text": f"<span color='{CRITICAL_COLOR}'>{temp:.1f}°C</span>",
                "tooltip": f"<span color='{PRIMARY_COLOR}'>󰔏 CPU Temperature:</span>\n",
                "class": "critical"
            }
        elif temp > critical_temp - CPU_WARNING_OFFSET:  # Within warning offset
            output = {
                "text": f"<span color='{WARNING_COLOR}'>{temp:.1f}°C</span>",
                "tooltip": f"<span color='{PRIMARY_COLOR}'>󰔏 CPU Temperature:</span>\n",
                "class": "high"
            }
        else:
            output = {
                "text": f"{temp:.1f}°C",
                "tooltip": f"<span color='{PRIMARY_COLOR}'>󰔏 CPU Temperature:</span>\n",
                "class": "normal"
            }
        
        # Add core temperature to tooltip
        output["tooltip"] += f" ├─ Core: {temp:.1f}°C\n"
        
        # Add additional sensors to tooltip
        if additional_temps:
            for i, (name, value) in enumerate(additional_temps.items()):
                crit_val_str = ""
                crit_temp_for_sensor = additional_temps_crits.get(name)
                if crit_temp_for_sensor is not None:
                    crit_val_str = f" (Crit: {crit_temp_for_sensor:.1f}°C)"
                
                if i == len(additional_temps) - 1:
                    output["tooltip"] += f" └─ {name.capitalize()}: {value:.1f}°C{crit_val_str}\n"
                else:
                    output["tooltip"] += f" ├─ {name.capitalize()}: {value:.1f}°C{crit_val_str}\n"
        else:
            output["tooltip"] += f" └─ Critical Threshold: {critical_temp:.1f}°C\n"
        
        # Only show high temperature warning when temperature is actually high
        if temp > critical_temp - CPU_WARNING_OFFSET:  # Only show warning for high temperatures
            output["tooltip"] += f"\n<span color='{CRITICAL_COLOR}'>⚠ High: CPU temp near/above threshold ({critical_temp:.1f}°C)!</span>"
    else:
        output = {
            "text": f" N/A ",
            "tooltip": "CPU temperature sensor not found",
            "class": "error"
        }
    
    return output

def get_gpu_temp():
    # Default critical temperatures
    DEFAULT_GPU_EDGE_CRITICAL_TEMP = 95.0
    DEFAULT_GPU_JUNCTION_CRITICAL_TEMP = 110.0

    # Find path for main GPU temperature (edge)
    gpu_edge_path_to_read = GPU_TEMP_PATH
    if not os.path.exists(GPU_TEMP_PATH):
        gpu_edge_path_to_read = find_path(GPU_TEMP_PATTERNS)
    
    # Read main GPU temperature value (edge)
    temp = read_temp_file(gpu_edge_path_to_read) # This is edge_temp
    
    # Determine critical temperature for the edge sensor
    actual_edge_critical_temp = DEFAULT_GPU_EDGE_CRITICAL_TEMP
    if gpu_edge_path_to_read:
        gpu_edge_crit_path = gpu_edge_path_to_read.replace("_input", "_crit")
        dynamic_edge_crit = read_temp_file(gpu_edge_crit_path)
        if dynamic_edge_crit is not None:
            actual_edge_critical_temp = dynamic_edge_crit
        else:
            # Fallback to _emergency for edge sensor
            gpu_edge_emergency_path = gpu_edge_path_to_read.replace("_input", "_emergency")
            dynamic_edge_emergency = read_temp_file(gpu_edge_emergency_path)
            if dynamic_edge_emergency is not None:
                actual_edge_critical_temp = dynamic_edge_emergency
    
    # Read additional sensors and their critical temperatures
    additional_temps = {}
    additional_temps_crits = {} # To store found critical temperatures

    for name, pattern in GPU_ADDITIONAL_PATTERNS.items():
        path = find_path(pattern)
        if path:
            value = read_temp_file(path)
            if value:
                additional_temps[name] = value
                # Try to find critical temp for this additional sensor (crit then emergency)
                sensor_crit_path = path.replace("_input", "_crit")
                dynamic_sensor_crit = read_temp_file(sensor_crit_path)
                if dynamic_sensor_crit is not None:
                    additional_temps_crits[name] = dynamic_sensor_crit
                else:
                    sensor_emergency_path = path.replace("_input", "_emergency")
                    dynamic_sensor_emergency = read_temp_file(sensor_emergency_path)
                    if dynamic_sensor_emergency is not None:
                        additional_temps_crits[name] = dynamic_sensor_emergency
    
    # Determine the temperature and critical threshold to use for overall warnings
    temp_for_warning_comparison = temp # Default to edge temp
    critical_temp_for_warning = actual_edge_critical_temp # Default to edge crit temp
    warning_source_name = "Edge"

    junction_temp_value = additional_temps.get("junction")
    if junction_temp_value is not None:
        temp_for_warning_comparison = junction_temp_value
        warning_source_name = "Junction"
        # Use dynamic junction critical temp if found, else default
        critical_temp_for_warning = additional_temps_crits.get("junction", DEFAULT_GPU_JUNCTION_CRITICAL_TEMP)
    
    # Format output for Waybar
    if temp is not None: # temp is edge_temp, always display this
        # Conditional formatting based on temp_for_warning_comparison and critical_temp_for_warning
        if temp_for_warning_comparison is not None and temp_for_warning_comparison > critical_temp_for_warning - GPU_CRITICAL_OFFSET:
            output = {
                "text": f"<span color='{CRITICAL_COLOR}'>{temp:.1f}°C</span>", # Display edge temp
                "tooltip": f"<span color='{PRIMARY_COLOR}'>󰔏 GPU Temperature:</span>\n",
                "class": "critical"
            }
        elif temp_for_warning_comparison is not None and temp_for_warning_comparison > critical_temp_for_warning - GPU_WARNING_OFFSET:
            output = {
                "text": f"<span color='{WARNING_COLOR}'>{temp:.1f}°C</span>", # Display edge temp
                "tooltip": f"<span color='{PRIMARY_COLOR}'>󰔏 GPU Temperature:</span>\n",
                "class": "high"
            }
        else:
            output = {
                "text": f"{temp:.1f}°C", # Display edge temp
                "tooltip": f"<span color='{PRIMARY_COLOR}'>󰔏 GPU Temperature:</span>\n",
                "class": "normal"
            }
        
        # Add edge temperature to tooltip with its critical value
        output["tooltip"] += f" ├─ Edge: {temp:.1f}°C (Crit: {actual_edge_critical_temp:.1f}°C)\n"
        
        # Add additional sensors to tooltip with their critical values if found
        if additional_temps:
            num_additional = len(additional_temps)
            count = 0
            for name, value in additional_temps.items():
                count += 1
                prefix = "├─" if count < num_additional else "└─"
                crit_val = additional_temps_crits.get(name)
                crit_info_str = f" (Crit: {crit_val:.1f}°C)" if crit_val is not None else ""
                output["tooltip"] += f" {prefix} {name.capitalize()}: {value:.1f}°C{crit_info_str}\n"
        # If no additional_temps, the tooltip for Edge already shows its critical temp.
        
        # Add high temperature warning, specifying source and threshold
        if temp_for_warning_comparison is not None and temp_for_warning_comparison > critical_temp_for_warning - GPU_CRITICAL_OFFSET: # Check for "critical" level
            output["tooltip"] += f"\n<span color='{CRITICAL_COLOR}'>⚠ High: GPU {warning_source_name} temp near/above threshold ({critical_temp_for_warning:.1f}°C)!</span>"
    else:
        output = {
            "text": f"N/A",
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