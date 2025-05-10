#!/usr/bin/python3
# filepath: /home/tymon/dotfiles/.config/waybar/scripts/power.py

import json
import sys
import os
import glob
import re
import subprocess

# Configuration
# CPU_POWER_PATH = "/sys/class/hwmon/hwmon4/power1_input" # Unused
# GPU_POWER_PATH = "/sys/class/drm/card1/device/hwmon/hwmon3/power1_average" # Unused
TOTAL_POWER_FORMAT = " {total:.1f}W"

# Power thresholds for color coding (in watts)
HIGH_POWER_THRESHOLD = 320  # Above this is considered high power consumption
MEDIUM_POWER_THRESHOLD = 280  # Above this is considered medium power consumption

# Percentage thresholds for component power imbalance
HIGH_PERCENT_THRESHOLD = 90  # Above this percentage is considered very imbalanced
MEDIUM_PERCENT_THRESHOLD = 75  # Above this percentage is considered moderately imbalanced

# Fallback paths using glob patterns
CPU_POWER_PATTERNS = [
    "/sys/class/hwmon/hwmon*/power1_input",
    "/sys/devices/platform/amd_energy/energy*_input"
]

GPU_POWER_PATTERNS = [
    "/sys/class/drm/card*/device/hwmon/hwmon*/power1_average", 
    "/sys/class/hwmon/hwmon*/device/power1_average"
]

# System power supply patterns
# POWER_SUPPLY_PATTERNS = [ # Removed unused constant
#     "/sys/class/power_supply/*/power_now",
#     "/sys/class/power_supply/*/current_now",
# ]

# NVMe drive power patterns
NVME_POWER_PATTERNS = [
    "/sys/class/hwmon/hwmon*/device/power*_input", 
    "/sys/class/nvme/nvme*/power/power_state"
]

# Additional configurations
CPU_POWER_SCALING = 1.2  # CPU reports about 80% of actual power (VRM losses, etc)
GPU_POWER_SCALING = 1.25  # GPU reports don't include VRAM, VRMs, fans

# Monitor Power Configuration
MONITORS = [
    {"name": "AOC (22\" 1080p 144Hz)", "power": 25},
    {"name": "LG (32\" 1440p 165Hz)", "power": 45}
]

PERIPHERALS_POWER = 10  # Keyboard, mouse, streamdeck, etc.
SYSTEM_BASE_POWER = 40  # Motherboard, RAM, fans, drives, etc.

# NVMe power state estimates (in watts)
NVME_LOW_POWER_STATE_WATTAGE = 0.5  # Estimate for low power state (e.g., state "1")
NVME_ACTIVE_POWER_STATE_WATTAGE = 3.0 # Estimate for active power state (e.g., state "0")

# Standard colors for all scripts - updated with lighter primary color
PRIMARY_COLOR = "#48A3FF"     # Lighter blue color that's more visible
WHITE_COLOR = "#FFFFFF"       # White text color
WARNING_COLOR = "#ff9a3c"     # Orange warning color from CSS .yellow 
CRITICAL_COLOR = "#dc2f2f"    # Red critical color from CSS .red
NEUTRAL_COLOR = "#FFFFFF"     # White for normal text
HEADER_COLOR = "#48A3FF"      # Lighter blue for section headers

def find_path(patterns):
    """Find existing file path from a list of glob patterns"""
    for pattern in patterns:
        paths = glob.glob(pattern)
        if paths:
            return paths[0]
    return None

def find_all_paths(patterns):
    """Find all existing file paths from a list of glob patterns"""
    result = []
    for pattern in patterns:
        paths = glob.glob(pattern)
        result.extend(paths)
    return result

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

def estimate_system_power():
    """Estimate total system power consumption using sensors command"""
    
    # Try to get power info from sensors command
    try:
        result = subprocess.run(['sensors'], capture_output=True, text=True)
        if result.returncode == 0:
            output = result.stdout
            
            # Look for zenpower specific values (AMD CPU)
            cpu_core_match = re.search(r"SVI2_P_Core:\s+(\d+\.\d+)\s+W", output)
            cpu_soc_match = re.search(r"SVI2_P_SoC:\s+(\d+\.\d+)\s+W", output)
            
            # Look for GPU PPT (AMD GPU)
            gpu_match = re.search(r"PPT:\s+(\d+\.\d+)\s+W", output)
            
            return {
                'cpu_core': float(cpu_core_match.group(1)) if cpu_core_match else 0.0,
                'cpu_soc': float(cpu_soc_match.group(1)) if cpu_soc_match else 0.0,
                'gpu': float(gpu_match.group(1)) if gpu_match else 0.0
            }
    except OSError as e:
        print(f"Error: {e}", file=sys.stderr)
        
    return {
        'cpu_core': 0.0,
        'cpu_soc': 0.0,
        'gpu': 0.0
    }

def get_nvme_power():
    """Get power consumption from NVMe drives"""
    total_nvme_power = 0.0
    nvme_paths = find_all_paths(NVME_POWER_PATTERNS)
    
    for path in nvme_paths:
        if "power_state" in path:
            # Handle text-based power states
            try:
                with open(path, 'r') as f:
                    state = f.read().strip()
                    # Rough estimates based on power states
                    if state == "1":  # Low power state
                        total_nvme_power += NVME_LOW_POWER_STATE_WATTAGE  # Use constant
                    elif state == "0":  # Active state
                        total_nvme_power += NVME_ACTIVE_POWER_STATE_WATTAGE  # Use constant
            except (IOError, ValueError):
                pass
        else:
            # Handle numerical power values
            total_nvme_power += read_power_file(path)
    
    return total_nvme_power

def main():
    # Get power values from sensors
    power_data = estimate_system_power()
    
    cpu_power_source_info = "sensors (Core + SoC)"
    gpu_power_source_info = "sensors (PPT)"

    # Set CPU power (core + SoC) with scaling
    cpu_power = (power_data['cpu_core'] + power_data['cpu_soc'])
    if cpu_power == 0.0:
        cpu_sysfs_path = find_path(CPU_POWER_PATTERNS)
        if cpu_sysfs_path:
            cpu_power_from_file = read_power_file(cpu_sysfs_path)
            if cpu_power_from_file > 0.0:
                cpu_power = cpu_power_from_file
                cpu_power_source_info = f"sysfs ({cpu_sysfs_path.split('/')[-2]}/{cpu_sysfs_path.split('/')[-1]})"
            else:
                cpu_power_source_info = "unavailable"
        else:
            cpu_power_source_info = "unavailable"
    cpu_power *= CPU_POWER_SCALING
    
    # Set GPU power with scaling
    gpu_power = power_data['gpu']
    if gpu_power == 0.0:
        gpu_sysfs_path = find_path(GPU_POWER_PATTERNS)
        if gpu_sysfs_path:
            gpu_power_from_file = read_power_file(gpu_sysfs_path)
            if gpu_power_from_file > 0.0:
                gpu_power = gpu_power_from_file
                gpu_power_source_info = f"sysfs ({gpu_sysfs_path.split('/')[-2]}/{gpu_sysfs_path.split('/')[-1]})"
            else:
                gpu_power_source_info = "unavailable"
        else:
            gpu_power_source_info = "unavailable"
    gpu_power *= GPU_POWER_SCALING
    
    # Get NVMe power if available
    nvme_power = get_nvme_power()
    
    # Calculate "other" power - this is everything else in the PC
    other_power = SYSTEM_BASE_POWER
    
    # Calculate total monitor power
    total_monitor_power = sum(monitor['power'] for monitor in MONITORS)

    # Calculate "external" power for peripherals
    external_power = total_monitor_power + PERIPHERALS_POWER
    
    # Calculate system power
    system_power = cpu_power + gpu_power + nvme_power + other_power
    total_power = system_power + external_power
    
    # Calculate percentages
    if total_power > 0:
        cpu_percent = (cpu_power / total_power) * 100
        gpu_percent = (gpu_power / total_power) * 100
        nvme_percent = (nvme_power / total_power) * 100
        other_percent = (other_power / total_power) * 100
    else:
        cpu_percent = gpu_percent = nvme_percent = other_percent = 0
    
    # Total power display
    if total_power > HIGH_POWER_THRESHOLD:
        power_text = f"<span color='{CRITICAL_COLOR}'> {TOTAL_POWER_FORMAT.format(total=total_power)}</span> "
        power_class = "critical"
    elif total_power > MEDIUM_POWER_THRESHOLD:
        power_text = f"<span color='{WARNING_COLOR}'> {TOTAL_POWER_FORMAT.format(total=total_power)}</span> "
        power_class = "high"
    else:
        power_text = f" {TOTAL_POWER_FORMAT.format(total=total_power)} "
        power_class = "normal"
    
    # Section headers
    tooltip = f"<span color='{PRIMARY_COLOR}'> Power Consumption:</span>\n"

    # CPU power with color
    if cpu_power == 0.0 and cpu_power_source_info == "unavailable":
        cpu_text = f"CPU: <span color='{WARNING_COLOR}'>Data unavailable</span>"
    elif cpu_percent > HIGH_PERCENT_THRESHOLD:
        cpu_text = f"<span color='{CRITICAL_COLOR}'>CPU: {cpu_power:.1f}W ({cpu_percent:.1f}%)</span>"
    elif cpu_percent > MEDIUM_PERCENT_THRESHOLD:
        cpu_text = f"<span color='{WARNING_COLOR}'>CPU: {cpu_power:.1f}W ({cpu_percent:.1f}%)</span>"
    else:
        cpu_text = f"CPU: {cpu_power:.1f}W ({cpu_percent:.1f}%)"
    
    # Format GPU power with color based on its percentage
    if gpu_power == 0.0 and gpu_power_source_info == "unavailable":
        gpu_text = f"GPU: <span color='{WARNING_COLOR}'>Data unavailable</span>"
    elif gpu_percent > HIGH_PERCENT_THRESHOLD:
        gpu_text = f"<span color='{CRITICAL_COLOR}'>GPU: {gpu_power:.1f}W ({gpu_percent:.1f}%)</span>"
    elif gpu_percent > MEDIUM_PERCENT_THRESHOLD:
        gpu_text = f"<span color='{WARNING_COLOR}'>GPU: {gpu_power:.1f}W ({gpu_percent:.1f}%)</span>"
    else:
        gpu_text = f"GPU: {gpu_power:.1f}W ({gpu_percent:.1f}%)"
    
    # Format NVMe power
    nvme_text = f"Storage: {nvme_power:.1f}W ({nvme_percent:.1f}%)"
    
    # Format Other power
    if other_power > 0:
        other_text = f"Other: {other_power:.1f}W ({other_percent:.1f}%)"
    else:
        other_text = "Other: N/A"
    
    # Prepare tooltip with colored components
    tooltip += f" ├─ {cpu_text}\n"
    tooltip += f" ├─ {gpu_text}\n"
    
    # Add NVMe if power detected
    if nvme_power > 0:
        tooltip += f" ├─ {nvme_text}\n"
        
    # Always show PC components
    tooltip += f" ├─ {other_text}\n"

    # Add external power with monitor details
    tooltip += f" ├─ Monitors: {total_monitor_power:.1f}W\n"
    for i, monitor in enumerate(MONITORS):
        connector = "└─" if i == len(MONITORS) - 1 else "├─"
        tooltip += f"    {connector} {monitor['name']}: {monitor['power']:.1f}W\n"
    tooltip += f" ├─ Peripherals: {PERIPHERALS_POWER:.1f}W\n"
    tooltip += f" ├─ <span color='#ff9a3c'>*estimated</span> External Power: {total_monitor_power + PERIPHERALS_POWER:.1f}W\n"
    tooltip += f" └─ Total: {total_power:.1f}W\n"
    
    # Source information
    tooltip += f"\n<span color='{PRIMARY_COLOR}'>Source:</span>\n"
    tooltip += f" ├─ CPU: {cpu_power_source_info}\n"
    tooltip += f" └─ GPU: {gpu_power_source_info}"
    
    # Prepare output
    output = {
        "text": power_text,
        "tooltip": tooltip,
        "class": power_class
    }
    
    # Print JSON output for Waybar
    print(json.dumps(output))

if __name__ == "__main__":
    main()