#!/usr/bin/python3
# filepath: ~/dotfiles/.config/waybar/scripts/usage.py

import json
import os
import glob
import argparse
import psutil
import time
import re

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

GPU_CLOCK_PP_CUR_STATE = "/sys/class/drm/card*/device/pp_cur_state"
GPU_CLOCK_PP_DPM = "/sys/class/drm/card*/device/pp_dpm_sclk"
GPU_CLOCK_FREQ_INPUT_PATTERNS = [
    "/sys/class/drm/card*/device/hwmon/hwmon*/freq*_input"
]

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

def get_amd_gpu_processes():
    """Get AMD GPU processes using fdinfo interface (kernel >= 5.14)"""
    
    def get_process_gpu_data():
        """Get GPU data for all processes at a single point in time"""
        processes = {}
        try:
            for pid_dir in os.listdir('/proc'):
                if not pid_dir.isdigit():
                    continue
                    
                pid = int(pid_dir)
                fdinfo_dir = f'/proc/{pid}/fdinfo'
                
                if not os.path.exists(fdinfo_dir):
                    continue
                    
                try:
                    for fd in os.listdir(fdinfo_dir):
                        fdinfo_path = os.path.join(fdinfo_dir, fd)
                        
                        try:
                            with open(fdinfo_path, 'r') as f:
                                content = f.read()
                                
                            if 'drm-driver:' in content and 'amdgpu' in content:
                                total_usage = 0
                                vram_usage = 0
                                
                                for line in content.split('\n'):
                                    if line.startswith('drm-engine-'):
                                        parts = line.split(':')
                                        if len(parts) == 2:
                                            try:
                                                usage_ns = int(parts[1].strip().split()[0])
                                                total_usage += usage_ns
                                            except (ValueError, IndexError):
                                                continue
                                    elif line.startswith('drm-memory-vram:'):
                                        parts = line.split(':')
                                        if len(parts) == 2:
                                            try:
                                                vram_kib = int(parts[1].strip().split()[0])
                                                vram_usage = vram_kib * 1024
                                            except (ValueError, IndexError):
                                                continue
                                
                                if total_usage > 0:
                                    try:
                                        proc = psutil.Process(pid)
                                        processes[pid] = {
                                            'name': proc.name(),
                                            'memory_percent': proc.memory_percent(),
                                            'gpu_usage_ns': total_usage,
                                            'vram_usage_bytes': vram_usage
                                        }
                                    except (psutil.NoSuchProcess, psutil.AccessDenied):
                                        pass
                                break
                                        
                        except (OSError, PermissionError):
                            continue
                            
                except (OSError, PermissionError):
                    continue
                    
        except OSError:
            pass
            
        return processes
    
    # Get initial measurements
    initial_data = get_process_gpu_data()
    if not initial_data:
        return []
    
    # Wait for a short interval
    time.sleep(0.5)
    
    # Get second measurements
    final_data = get_process_gpu_data()
    
    # Calculate GPU usage percentages
    result_processes = []
    interval_ns = 0.5 * 1_000_000_000  # 0.5 seconds in nanoseconds
    
    for pid in initial_data:
        if pid in final_data:
            initial = initial_data[pid]
            final = final_data[pid]
            
            # Calculate GPU usage delta
            gpu_time_delta = final['gpu_usage_ns'] - initial['gpu_usage_ns']
            
            # Convert to percentage (time used / time available * 100)
            gpu_usage_percent = (gpu_time_delta / interval_ns) * 100
            
            # Clamp to reasonable values (0-100%)
            gpu_usage_percent = max(0, min(100, gpu_usage_percent))
            
            if gpu_usage_percent > 0.1 or final['vram_usage_bytes'] > 0:  # Include if using GPU or VRAM
                result_processes.append({
                    'pid': pid,
                    'name': final['name'],
                    'memory_percent': final['memory_percent'],
                    'gpu_usage_percent': gpu_usage_percent,
                    'vram_usage_bytes': final['vram_usage_bytes']
                })
        
    return result_processes

def read_file_value(path):
    """Read numeric value from file"""
    if not path or not os.path.exists(path):
        return None
    
    try:
        with open(path, 'r') as f:
            return int(f.read().strip())
    except (IOError, ValueError):
        return None


def get_gpu_clock_speed_mhz():
    """Best-effort read of current GPU clock in MHz for AMD GPUs."""
    # Try pp_cur_state first; it explicitly reports current sclk in MHz.
    cur_state_path = find_path(GPU_CLOCK_PP_CUR_STATE)
    if cur_state_path:
        try:
            with open(cur_state_path, "r", encoding="utf-8", errors="ignore") as f:
                for line in f:
                    match = re.search(r"sclk:\s*(\d+)\s*mhz", line, re.IGNORECASE)
                    if match:
                        return float(match.group(1))
        except OSError:
            pass

    # Fallback to pp_dpm_sclk: current state marked with '*'.
    dpm_path = find_path(GPU_CLOCK_PP_DPM)
    if dpm_path:
        try:
            with open(dpm_path, "r", encoding="utf-8", errors="ignore") as f:
                active_line = None
                for line in f:
                    if "*" in line:
                        active_line = line
                        break
                if active_line:
                    match = re.search(r"(\d+)\s*mhz", active_line, re.IGNORECASE)
                    if match:
                        return float(match.group(1))
        except OSError:
            pass

    # Lastly, inspect hwmon frequency inputs, matching labels that look like GPU clocks.
    for pattern in GPU_CLOCK_FREQ_INPUT_PATTERNS:
        for freq_path in glob.glob(pattern):
            base_dir = os.path.dirname(freq_path)
            label_path = freq_path.replace("_input", "_label")
            label = ""
            if os.path.exists(label_path):
                try:
                    with open(label_path, "r", encoding="utf-8", errors="ignore") as label_file:
                        label = label_file.read().strip().lower()
                except OSError:
                    label = ""

            if label and not any(keyword in label for keyword in ("sclk", "gfx", "core", "gpu")):
                continue  # Skip unrelated frequency sensors

            try:
                with open(freq_path, "r", encoding="utf-8", errors="ignore") as freq_file:
                    raw_value = freq_file.read().strip()
                if not raw_value:
                    continue
                freq_value = float(raw_value)
            except (OSError, ValueError):
                continue

            if freq_value <= 0:
                continue

            # Determine units: hwmon typically reports Hz; some boards use kHz.
            if freq_value > 1_000_000:  # Hz -> MHz
                return freq_value / 1_000_000.0
            if freq_value > 1_000:       # kHz -> MHz
                return freq_value / 1_000.0
            return freq_value  # Assume already MHz

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
    except psutil.Error: # More specific error for psutil
        current_freq = None
    
    # Get load averages
    try:
        load1, load5, load15 = os.getloadavg()
    except OSError: # More specific error for os.getloadavg()
        load1, load5, load15 = None, None, None
    
    # Format output for Waybar with conditional formatting for high usage
    if overall > 90:
        output = {
            "text": f"<span size='large' rise='-1000'>󰍛</span>\u00A0 <span color='{CRITICAL_COLOR}'>{overall:.1f}%</span> ",
            "tooltip": f"<span color='{PRIMARY_COLOR}'>󰍛 CPU Usage: {overall:.1f}%</span>\n\n",
            "class": "critical"
        }
    elif overall > 70:
        output = {
            "text": f"<span size='large' rise='-1000'>󰍛</span>\u00A0 <span color='{WARNING_COLOR}'>{overall:.1f}%</span> ",
            "tooltip": f"<span color='{PRIMARY_COLOR}'>󰍛 CPU Usage: {overall:.1f}%</span>\n\n",
            "class": "high"
        }
    else:
        output = {
            "text": f"<span size='large' rise='-1000'>󰍛</span>\u00A0 {overall:.1f}% ",
            "tooltip": f"<span color='{PRIMARY_COLOR}'>󰍛 CPU Usage: {overall:.1f}%</span>\n\n",
            "class": "normal"
        }
    
    # Add core-by-core information
    output["tooltip"] += f"<span color='{PRIMARY_COLOR}'>󰘚 Per-Core Usage:</span>\n"
    
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
                color = CRITICAL_COLOR  # Red for high usage
            elif usage > 70:
                color = WARNING_COLOR  # Orange for medium-high
            elif usage > 50:
                color = PRIMARY_COLOR  # Yellow for medium
            else:
                color = NEUTRAL_COLOR  # Green for low
                
            core_texts.append(f"Core {core_num}: <span color='{color}'>{usage:.1f}%</span>")
        
        output["tooltip"] += core_line + " | ".join(core_texts) + "\n"
    
    # Add frequency information if available
    if current_freq:
        output["tooltip"] += f"\n<span color='{PRIMARY_COLOR}'>󰓅 CPU Frequency:</span> {current_freq/1000:.2f} GHz\n"
    
    # Add load average information
    if load1 is not None:
        output["tooltip"] += f"\n<span color='{PRIMARY_COLOR}'>󱘲 Load Average:</span>\n"
        output["tooltip"] += f" ├─ 1 min: {load1:.2f}\n"
        output["tooltip"] += f" ├─ 5 min: {load5:.2f}\n"
        output["tooltip"] += f" └─ 15 min: {load15:.2f}\n"
    
    # Add process count
    output["tooltip"] += f"\n<span color='{PRIMARY_COLOR}'>󰅵 Processes:</span> {len(psutil.pids())}\n"
    
    # Get top CPU consuming processes
    processes = []
    
    try:
        # First method: iterate through processes and get CPU usage
        for proc in psutil.process_iter(['pid', 'name']):
            try:
                proc_info = proc.info
                # Get CPU usage for this specific process
                cpu_usage = proc.cpu_percent()  # This sets up monitoring
                if cpu_usage > 0.01:  # Include any measurable CPU usage
                    proc_info['cpu_percent'] = cpu_usage
                    processes.append(proc_info)
            except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
                pass
                
        # If we don't have enough processes, wait and try again
        if len(processes) < 3:
            time.sleep(0.1)  # Short wait for CPU measurements
            processes.clear()
            
            for proc in psutil.process_iter(['pid', 'name']):
                try:
                    proc_info = proc.info
                    cpu_usage = proc.cpu_percent()  # Get updated CPU usage
                    if cpu_usage > 0.01:
                        proc_info['cpu_percent'] = cpu_usage
                        processes.append(proc_info)
                except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
                    pass
    except Exception:
        pass

    # Sort by CPU usage and get top 5
    top_processes = sorted(processes, key=lambda x: x.get('cpu_percent', 0), reverse=True)[:5]

    if top_processes:
        output["tooltip"] += f"\n<span color='{PRIMARY_COLOR}'>󰍛 Top CPU Processes:</span>\n"
        for i, proc in enumerate(top_processes):
            prefix = " └─ " if i == len(top_processes) - 1 else " ├─ "
            try:
                cpu_use = proc.get('cpu_percent', 0)
                # Color-code the CPU usage
                if cpu_use > 50:
                    color = CRITICAL_COLOR
                elif cpu_use > 25:
                    color = WARNING_COLOR
                elif cpu_use > 10:
                    color = PRIMARY_COLOR
                else:
                    color = NEUTRAL_COLOR
                
                output["tooltip"] += f"{prefix}{proc['name']} (PID: {proc['pid']}): <span color='{color}'>{cpu_use:.1f}%</span>\n"
            except (KeyError, TypeError):
                pass
    
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
    
    # Format output for Waybar with conditional formatting for high usage
    if usage is not None:
        if usage > 90:
            output = {
                "text": f"<span size='large' rise='-2000'>󰢮</span>\u00A0 <span color='{CRITICAL_COLOR}'>{usage}%</span> ",
                "tooltip": f"<span color='{PRIMARY_COLOR}'>󰢮 GPU Usage: {usage}%</span>\n",
                "class": "critical"
            }
        elif usage > 70:
            output = {
                "text": f"<span size='large' rise='-2000'>󰢮</span>\u00A0 <span color='{WARNING_COLOR}'>{usage}%</span> ",
                "tooltip": f"<span color='{PRIMARY_COLOR}'>󰢮 GPU Usage: {usage}%</span>\n",
                "class": "high"
            }
        else:
            output = {
                "text": f"<span size='large' rise='-2000'>󰢮</span>\u00A0 {usage}% ",
                "tooltip": f"<span color='{PRIMARY_COLOR}'>󰢮 GPU Usage: {usage}%</span>\n",
                "class": "normal"
            }
        
        # Add memory information if available
        if mem_percent is not None:
            output["tooltip"] += f"\n<span color='{PRIMARY_COLOR}'>󰍹 VRAM Usage:</span>\n"
            output["tooltip"] += f" ├─ Used: {mem_used_gib:.2f} GiB\n"
            output["tooltip"] += f" ├─ Total: {mem_total_gib:.2f} GiB\n"
            output["tooltip"] += f" └─ Percentage: {mem_percent:.1f}%\n"

        clock_mhz = get_gpu_clock_speed_mhz()
        if clock_mhz is not None:
            output["tooltip"] += f"\n<span color='{PRIMARY_COLOR}'>󰾆 GPU Clock:</span> {clock_mhz:.0f} MHz\n"
            
        # Try to get GPU processes (AMD fdinfo first, then fallbacks)
        gpu_processes_found = False
        
        # Try AMD GPU processes first using fdinfo interface (like nvtop)
        try:
            amd_processes = get_amd_gpu_processes()
            if amd_processes:
                output["tooltip"] += f"\n<span color='{PRIMARY_COLOR}'>󰢮 GPU Processes (AMD fdinfo):</span>\n"
                gpu_processes_found = True
                
                # Sort by GPU usage percentage first, then by VRAM usage
                amd_processes.sort(key=lambda x: (x['gpu_usage_percent'], x['vram_usage_bytes']), reverse=True)
                amd_processes = amd_processes[:5]
                
                for i, proc in enumerate(amd_processes):
                    prefix = " └─ " if i == len(amd_processes) - 1 else " ├─ "
                    
                    # Color-code based on GPU usage percentage
                    gpu_percent = proc['gpu_usage_percent']
                    if gpu_percent > 80:
                        gpu_color = CRITICAL_COLOR
                    elif gpu_percent > 50:
                        gpu_color = WARNING_COLOR
                    elif gpu_percent > 10:
                        gpu_color = PRIMARY_COLOR
                    else:
                        gpu_color = NEUTRAL_COLOR
                    
                    # Show VRAM usage if available
                    vram_display = ""
                    if proc['vram_usage_bytes'] > 0:
                        vram_mib = proc['vram_usage_bytes'] / (1024 * 1024)
                        if vram_mib > 1000:  # > 1 GiB
                            vram_display = f", {vram_mib/1024:.1f} GiB VRAM"
                        else:
                            vram_display = f", {vram_mib:.0f} MiB VRAM"
                    
                    output["tooltip"] += f"{prefix}{proc['name']} (PID: {proc['pid']}): <span color='{gpu_color}'>{gpu_percent:.1f}% GPU</span>{vram_display}\n"
                    
        except Exception:
            # AMD fdinfo detection failed, continue to other methods
            pass
        
        # Fallback to NVIDIA if AMD didn't work and no processes found yet
        if not gpu_processes_found:
            try:
                import pynvml
                pynvml.nvmlInit()
                device_count = pynvml.nvmlDeviceGetCount()
                
                if device_count > 0:
                    handle = pynvml.nvmlDeviceGetHandleByIndex(0)  # First GPU
                    processes = pynvml.nvmlDeviceGetRunningProcesses(handle)
                    
                    if processes:
                        output["tooltip"] += f"\n<span color='{PRIMARY_COLOR}'>󰢮 GPU Processes (NVIDIA):</span>\n"
                        gpu_processes_found = True
                        
                        # Sort by memory usage and limit to top 5
                        sorted_procs = sorted(processes, key=lambda x: x.usedGpuMemory, reverse=True)[:5]
                        
                        for i, proc in enumerate(sorted_procs):
                            prefix = " └─ " if i == len(sorted_procs) - 1 else " ├─ "
                            try:
                                # Get process name from PID
                                ps_proc = psutil.Process(proc.pid)
                                proc_name = ps_proc.name()
                                
                                # Convert memory to MiB
                                mem_mib = proc.usedGpuMemory / (1024 * 1024)
                                
                                # Color-code based on memory usage
                                if mem_mib > 1000:  # > 1 GiB
                                    color = CRITICAL_COLOR
                                elif mem_mib > 500:  # > 500 MiB
                                    color = WARNING_COLOR
                                elif mem_mib > 100:  # > 100 MiB
                                    color = PRIMARY_COLOR
                                else:
                                    color = NEUTRAL_COLOR
                                
                                output["tooltip"] += f"{prefix}{proc_name} (PID: {proc.pid}): <span color='{color}'>{mem_mib:.0f} MiB</span>\n"
                            except (psutil.NoSuchProcess, psutil.AccessDenied):
                                output["tooltip"] += f"{prefix}PID {proc.pid}: <span color='{NEUTRAL_COLOR}'>{mem_mib:.0f} MiB</span>\n"
                                
            except ImportError:
                # pynvml not available, skip NVIDIA GPU process info
                pass
            except Exception:
                # Other GPU-related errors, skip silently
                pass
        
        # If no GPU processes found through either method, try generic approach
        if not gpu_processes_found:
            try:
                # Look for processes that commonly use GPU
                gpu_process_names = ['firefox', 'chrome', 'chromium', 'blender', 'davinci-resolve', 
                                   'obs', 'steam', 'gamemode', 'mangohud', 'vulkan', 'opengl']
                
                gpu_procs = []
                for proc in psutil.process_iter(['pid', 'name', 'memory_percent']):
                    try:
                        proc_info = proc.info
                        proc_name = proc_info['name'].lower()
                        
                        # Check if process name contains common GPU-using keywords
                        if any(gpu_name in proc_name for gpu_name in gpu_process_names):
                            gpu_procs.append(proc_info)
                    except (psutil.NoSuchProcess, psutil.AccessDenied):
                        continue
                
                if gpu_procs:
                    # Sort by memory usage and limit to top 5
                    gpu_procs.sort(key=lambda x: x['memory_percent'], reverse=True)
                    gpu_procs = gpu_procs[:5]
                    
                    output["tooltip"] += f"\n<span color='{PRIMARY_COLOR}'>󰢮 Potential GPU Processes:</span>\n"
                    
                    for i, proc in enumerate(gpu_procs):
                        prefix = " └─ " if i == len(gpu_procs) - 1 else " ├─ "
                        mem_use = proc['memory_percent']
                        
                        # Color-code based on memory usage
                        if mem_use > 10:
                            color = CRITICAL_COLOR
                        elif mem_use > 5:
                            color = WARNING_COLOR
                        elif mem_use > 1:
                            color = PRIMARY_COLOR
                        else:
                            color = NEUTRAL_COLOR
                        
                        output["tooltip"] += f"{prefix}{proc['name']} (PID: {proc['pid']}): <span color='{color}'>{mem_use:.1f}%</span>\n"
                        
            except Exception:
                pass
    else:
        output = {
            "text": f"<span size='large'>󰢮</span>\u00A0 N/A ",
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

    # Initialize output dictionary with the base tooltip
    output = {
        "tooltip": f"<span color='{PRIMARY_COLOR}'> Memory Usage: {memory.percent}%</span>\n\n"
    }

    # Set text and class based on memory usage
    if memory.percent > 90:
        output["text"] = f"<span size='large' rise='-2000'></span> <span color='{CRITICAL_COLOR}'>{memory.percent}%</span> "
        output["class"] = "critical"
    elif memory.percent > 70:
        output["text"] = f"<span size='large' rise='-2000'></span> <span color='{WARNING_COLOR}'>{memory.percent}%</span> "
        output["class"] = "high"
    else:
        output["text"] = f"<span size='large' rise='-2000'></span> {memory.percent}% "
        output["class"] = "normal"

    # Add RAM details
    output["tooltip"] += f"<span color='{PRIMARY_COLOR}'>󰘚 RAM:</span>\n"
    output["tooltip"] += f" ├─ Used: {mem_used_gib:.2f} GiB\n"
    output["tooltip"] += f" ├─ Total: {mem_total_gib:.2f} GiB\n"
    output["tooltip"] += f" └─ Available: {mem_available_gib:.2f} GiB\n"

    # Add swap details
    if swap_total_gib > 0:
        output["tooltip"] += f"\n<span color='{PRIMARY_COLOR}'>󰓡 Swap:</span>\n"
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
        output["tooltip"] += f"\n<span color='{PRIMARY_COLOR}'>󰅵 Top Memory Processes:</span>\n"
        for i, proc in enumerate(top_processes):
            prefix = " └─ " if i == len(top_processes) - 1 else " ├─ "
            try:
                mem_use = proc['memory_percent']
                # Color-code the memory usage
                if mem_use > 10:
                    color = CRITICAL_COLOR
                elif mem_use > 5:
                    color = WARNING_COLOR
                elif mem_use > 1:
                    color = PRIMARY_COLOR
                else:
                    color = NEUTRAL_COLOR
                
                output["tooltip"] += f"{prefix}{proc['name']} (PID: {proc['pid']}): <span color='{color}'>{mem_use:.1f}%</span>\n"
            except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess): # More specific exception handling here
                pass
    
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