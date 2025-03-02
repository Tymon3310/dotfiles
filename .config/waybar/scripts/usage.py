#!/usr/bin/python3
# filepath: /home/tymon/dotfiles/.config/waybar/scripts/usage.py

import json
import sys
import os
import glob
import argparse
import time
import psutil
from pathlib import Path

# Configuration
GPU_USAGE_PATH = "/sys/class/drm/card1/device/gpu_busy_percent"
GPU_MEMORY_TOTAL = "/sys/class/drm/card1/device/mem_info_vram_total"
GPU_MEMORY_USED = "/sys/class/drm/card1/device/mem_info_vram_used"

# Fallback paths using glob patterns
GPU_USAGE_PATTERNS = [
    "/sys/class/drm/card*/device/gpu_busy_percent",
    "/sys/class/hwmon/hwmon*/device/gpu_busy_percent"
]

GPU_MEMORY_TOTAL_PATTERNS = [
    "/sys/class/drm/card*/device/mem_info_vram_total",
    "/sys/class/hwmon/hwmon*/device/mem_info_vram_total"
]

GPU_MEMORY_USED_PATTERNS = [
    "/sys/class/drm/card*/device/mem_info_vram_used",
    "/sys/class/hwmon/hwmon*/device/mem_info_vram_used"
]

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

def read_file_value(path):
    """Read numeric value from file"""
    if not path or not os.path.exists(path):
        return None
    
    try:
        with open(path, 'r') as f:
            return int(f.read().strip())
    except (IOError, ValueError):
        return None

def get_cpu_usage():
    """Get detailed CPU usage information"""
    # Get per-core CPU usage
    per_core = psutil.cpu_percent(interval=0.1, percpu=True)
    # Get overall CPU usage
    overall = psutil.cpu_percent(interval=0.1)
    
    # Get CPU frequency
    try:
        freq = psutil.cpu_freq()
        current_freq = freq.current if freq else None
    except Exception:
        current_freq = None
    
    # Get load averages
    try:
        load1, load5, load15 = os.getloadavg()
    except Exception:
        load1, load5, load15 = None, None, None
    
    # Format output for Waybar
    output = {
        "text": f"<span size='large' rise='-2000'>󰻠</span> {overall:.1f}% ",
        "tooltip": f"<span color='#8bd5ca'>󰻠 CPU Usage: {overall:.1f}%</span>\n\n"
    }
    
    # Add core-by-core information
    output["tooltip"] += "<span color='#f4b8e4'>󰘚 Per-Core Usage:</span>\n"
    
    cores_per_row = 4
    core_rows = [per_core[i:i+cores_per_row] for i in range(0, len(per_core), cores_per_row)]
    
    for i, row in enumerate(core_rows):
        if i < len(core_rows) - 1:
            core_line = " ├─ "
        else:
            core_line = " └─ "
            
        core_texts = []
        for j, usage in enumerate(row):
            core_num = i * cores_per_row + j
            # Color-code the usage
            if usage > 90:
                color = "#f38ba8"  # Red for high usage
            elif usage > 70:
                color = "#fab387"  # Orange for medium-high
            elif usage > 50:
                color = "#f9e2af"  # Yellow for medium
            else:
                color = "#a6e3a1"  # Green for low
                
            core_texts.append(f"Core {core_num}: <span color='{color}'>{usage:.1f}%</span>")
        
        output["tooltip"] += core_line + " | ".join(core_texts) + "\n"
    
    # Add frequency information if available
    if current_freq:
        output["tooltip"] += f"\n<span color='#89b4fa'>󰓅 CPU Frequency:</span> {current_freq/1000:.2f} GHz\n"
    
    # Add load average information
    if load1 is not None:
        output["tooltip"] += f"\n<span color='#89b4fa'>󱘲 Load Average:</span>\n"
        output["tooltip"] += f" ├─ 1 min: {load1:.2f}\n"
        output["tooltip"] += f" ├─ 5 min: {load5:.2f}\n"
        output["tooltip"] += f" └─ 15 min: {load15:.2f}\n"
    
    # Add process count
    output["tooltip"] += f"\n<span color='#89b4fa'>󰅵 Processes:</span> {len(psutil.pids())}\n"
    
    # Add class based on usage
    if overall > 90:
        output["class"] = "critical"
    elif overall > 70:
        output["class"] = "warning"
    else:
        output["class"] = "normal"
    
    return output

def get_gpu_usage():
    """Get detailed GPU usage information"""
    # Find path if default doesn't exist
    if not os.path.exists(GPU_USAGE_PATH):
        usage_path = find_path(GPU_USAGE_PATTERNS)
    else:
        usage_path = GPU_USAGE_PATH
    
    # Read GPU usage
    usage = read_file_value(usage_path)
    
    # Find memory paths
    if not os.path.exists(GPU_MEMORY_TOTAL):
        mem_total_path = find_path(GPU_MEMORY_TOTAL_PATTERNS)
    else:
        mem_total_path = GPU_MEMORY_TOTAL
    
    if not os.path.exists(GPU_MEMORY_USED):
        mem_used_path = find_path(GPU_MEMORY_USED_PATTERNS)
    else:
        mem_used_path = GPU_MEMORY_USED
    
    # Read memory values
    mem_total = read_file_value(mem_total_path)
    mem_used = read_file_value(mem_used_path)
    
    # Calculate memory usage percentage
    if mem_total and mem_used:
        mem_percent = (mem_used / mem_total) * 100
        # Convert to GiB
        mem_total_gib = mem_total / (1024 * 1024 * 1024)
        mem_used_gib = mem_used / (1024 * 1024 * 1024)
    else:
        mem_percent = None
        mem_total_gib = None
        mem_used_gib = None
    
    # Format output for Waybar
    if usage is not None:
        output = {
            "text": f"<span size='x-large' rise='-2000'>󰢮</span>\u00A0\u00A0 {usage}% ",
            "tooltip": f"<span color='#f4b8e4'>󰢮 GPU Usage: {usage}%</span>\n"
        }
        
        # Add memory information if available
        if mem_percent is not None:
            output["tooltip"] += f"\n<span color='#89b4fa'>󰍛 VRAM Usage:</span>\n"
            output["tooltip"] += f" ├─ Used: {mem_used_gib:.2f} GiB\n"
            output["tooltip"] += f" ├─ Total: {mem_total_gib:.2f} GiB\n"
            output["tooltip"] += f" └─ Percentage: {mem_percent:.1f}%\n"
        
        # Add class based on usage
        if usage > 90:
            output["class"] = "critical"
        elif usage > 70:
            output["class"] = "warning"
        else:
            output["class"] = "normal"
    else:
        output = {
            "text": f"<span size='x-large' rise='-2000'>󰢮</span>\u00A0\u00A0 N/A ",
            "tooltip": "GPU usage sensor not found",
            "class": "error"
        }
    
    return output

def get_memory_usage():
    """Get detailed memory usage information"""
    # Get memory information
    memory = psutil.virtual_memory()
    swap = psutil.swap_memory()
    
    # Calculate values in GiB
    mem_total_gib = memory.total / (1024 * 1024 * 1024)
    mem_used_gib = memory.used / (1024 * 1024 * 1024)
    mem_available_gib = memory.available / (1024 * 1024 * 1024)
    
    swap_total_gib = swap.total / (1024 * 1024 * 1024)
    swap_used_gib = swap.used / (1024 * 1024 * 1024)
    
    # Format output for Waybar
    output = {
        "text": f"<span size='x-large' rise='-2000'>󰍛</span>\u00A0 {memory.percent}% ",
        "tooltip": f"<span color='#8bd5ca'>󰍛 Memory Usage: {memory.percent}%</span>\n\n"
    }
    
    # Add RAM details
    output["tooltip"] += "<span color='#f4b8e4'>󰘚 RAM:</span>\n"
    output["tooltip"] += f" ├─ Used: {mem_used_gib:.2f} GiB\n"
    output["tooltip"] += f" ├─ Total: {mem_total_gib:.2f} GiB\n"
    output["tooltip"] += f" └─ Available: {mem_available_gib:.2f} GiB\n"
    
    # Add swap details
    if swap_total_gib > 0:
        output["tooltip"] += f"\n<span color='#89b4fa'>󰓡 Swap:</span>\n"
        output["tooltip"] += f" ├─ Used: {swap_used_gib:.2f} GiB ({swap.percent}%)\n"
        output["tooltip"] += f" └─ Total: {swap_total_gib:.2f} GiB\n"
    
    # Get top memory consuming processes
    processes = []
    for proc in psutil.process_iter(['pid', 'name', 'memory_percent']):
        try:
            processes.append(proc.info)
        except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
            pass
    
    # Sort by memory usage and get top 5
    top_processes = sorted(processes, key=lambda x: x['memory_percent'], reverse=True)[:5]
    
    if top_processes:
        output["tooltip"] += f"\n<span color='#f5c2e7'>󰅵 Top Memory Processes:</span>\n"
        for i, proc in enumerate(top_processes):
            prefix = " └─ " if i == len(top_processes) - 1 else " ├─ "
            try:
                mem_use = proc['memory_percent']
                # Color-code the memory usage
                if mem_use > 10:
                    color = "#f38ba8"  # Red
                elif mem_use > 5:
                    color = "#fab387"  # Orange
                elif mem_use > 1:
                    color = "#f9e2af"  # Yellow
                else:
                    color = "#a6e3a1"  # Green
                
                output["tooltip"] += f"{prefix}{proc['name']} (PID: {proc['pid']}): <span color='{color}'>{mem_use:.1f}%</span>\n"
            except:
                pass
    
    # Add class based on usage
    if memory.percent > 90:
        output["class"] = "critical"
    elif memory.percent > 70:
        output["class"] = "warning"
    else:
        output["class"] = "normal"
    
    return output

def main():
    # Parse command line arguments
    parser = argparse.ArgumentParser(description='Get CPU, GPU or memory usage for Waybar')
    parser.add_argument('device', choices=['cpu', 'gpu', 'memory'], help='Device/resource to get usage for')
    args = parser.parse_args()
    
    # Get usage for specified device
    if args.device == 'cpu':
        output = get_cpu_usage()
    elif args.device == 'gpu':
        output = get_gpu_usage()
    else:  # memory
        output = get_memory_usage()
    
    # Print JSON output for Waybar
    print(json.dumps(output))

if __name__ == "__main__":
    main()