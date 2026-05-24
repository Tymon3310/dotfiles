#!/usr/bin/env python3
import json
import sys
import time
import psutil
import os
import re
import subprocess
import glob

GPU_USAGE_PATH = "/sys/class/drm/card1/device/gpu_busy_percent"
GPU_MEM_TOTAL = "/sys/class/drm/card1/device/mem_info_vram_total"
GPU_MEM_USED = "/sys/class/drm/card1/device/mem_info_vram_used"

def read_file(path):
    try:
        with open(path, 'r') as f:
            return f.read().strip()
    except:
        return None

def format_speed(bytes_per_sec):
    if bytes_per_sec < 1024:
        return f"{bytes_per_sec:.0f} B/s"
    elif bytes_per_sec < 1024 * 1024:
        return f"{bytes_per_sec / 1024:.1f} KB/s"
    else:
        return f"{bytes_per_sec / 1024 / 1024:.1f} MB/s"

def get_gpu_stats():
    # Defaults
    gpu = 0
    vram_used = 0
    vram_total = 0
    gpu_sclk = 0
    gpu_mclk = 0
    gpu_temp = 0.0
    gpu_temp_junction = 0.0
    gpu_temp_mem = 0.0
    gpu_procs = []
    
    # Try amdgpu_top JSON first
    amdgpu_ok = False
    try:
        res = subprocess.run(["amdgpu_top", "-J", "-n", "1", "-s", "1ms"], capture_output=True, text=True, timeout=0.8)
        if res.returncode == 0:
            data = json.loads(res.stdout)
            if isinstance(data, dict) and "devices" in data and len(data["devices"]) > 0:
                device = data["devices"][0]
                fdinfo = device.get("fdinfo", {})
                gpu_activity = device.get("gpu_activity", {})
                gpu_metrics = device.get("gpu_metrics", {})
                
                # GPU Usage
                gpu = gpu_activity.get("GFX", {}).get("value", 0) if gpu_activity.get("GFX") else 0
                
                # Clocks & Temp
                gpu_sclk = gpu_metrics.get("current_gfxclk", 0)
                gpu_mclk = gpu_metrics.get("current_uclk", 0)
                gpu_temp = gpu_metrics.get("temperature_edge") or 0.0
                gpu_temp_junction = gpu_metrics.get("temperature_hotspot") or 0.0
                gpu_temp_mem = gpu_metrics.get("temperature_mem") or 0.0
                
                procs = []
                for pid_str, info in fdinfo.items():
                    name = info.get("name", "Unknown")
                    usage = info.get("usage", {})
                    if "usage" in usage:
                        usage = usage["usage"]
                    vram = usage.get("VRAM", {}).get("value", 0) if usage.get("VRAM") else 0
                    gfx = usage.get("GFX", {}).get("value", 0) if usage.get("GFX") else 0
                    procs.append({
                        "pid": int(pid_str),
                        "name": name,
                        "vram_mb": vram,
                        "gpu": gfx
                    })
                # Sort by VRAM
                procs.sort(key=lambda x: x["vram_mb"], reverse=True)
                gpu_procs = procs[:6]
                amdgpu_ok = True
    except Exception as e:
        sys.stderr.write(f"amdgpu_top error: {e}\n")
        
    # Fallback to sysfs for global stats
    if not amdgpu_ok:
        gpu_str = read_file(GPU_USAGE_PATH)
        if gpu_str and gpu_str.isdigit():
            gpu = int(gpu_str)
        
        # Clocks
        try:
            with open("/sys/class/drm/card1/device/pp_dpm_sclk", "r") as f:
                for line in f:
                    if "*" in line:
                        match = re.search(r'(\d+)Mhz', line)
                        if match:
                            gpu_sclk = int(match.group(1))
            with open("/sys/class/drm/card1/device/pp_dpm_mclk", "r") as f:
                for line in f:
                    if "*" in line:
                        match = re.search(r'(\d+)Mhz', line)
                        if match:
                            gpu_mclk = int(match.group(1))
        except:
            pass
            
        # Temp
        try:
            paths = glob.glob("/sys/class/drm/card1/device/hwmon/hwmon*/temp1_input")
            if paths:
                with open(paths[0], "r") as f:
                    gpu_temp = int(f.read().strip()) / 1000.0
        except:
            pass

    # Fallback/Supplemental temperature check using psutil for amdgpu
    try:
        temps = psutil.sensors_temperatures()
        if "amdgpu" in temps:
            for entry in temps["amdgpu"]:
                if entry.label == "edge" and not gpu_temp:
                    gpu_temp = entry.current
                elif entry.label == "junction" and not gpu_temp_junction:
                    gpu_temp_junction = entry.current
                elif entry.label == "mem" and not gpu_temp_mem:
                    gpu_temp_mem = entry.current
    except:
        pass
            
    # Read VRAM sizes from sysfs (always available and accurate)
    used_str = read_file(GPU_MEM_USED)
    total_str = read_file(GPU_MEM_TOTAL)
    if used_str and used_str.isdigit():
        vram_used = int(used_str)
    if total_str and total_str.isdigit():
        vram_total = int(total_str)
        
    return {
        "gpu": gpu,
        "vram_used_gib": vram_used / 1024 / 1024 / 1024,
        "vram_total_gib": vram_total / 1024 / 1024 / 1024,
        "gpu_sclk": gpu_sclk,
        "gpu_mclk": gpu_mclk,
        "gpu_temp": gpu_temp,
        "gpu_temp_junction": gpu_temp_junction,
        "gpu_temp_mem": gpu_temp_mem,
        "gpu_procs": gpu_procs
    }

def get_cpu_temp():
    try:
        temps = psutil.sensors_temperatures()
        for key in ["zenpower", "k10temp", "coretemp"]:
            if key in temps:
                for entry in temps[key]:
                    if entry.label in ["Tdie", "Tctl", "Package id 0"]:
                        return entry.current
        for key in ["zenpower", "k10temp", "coretemp"]:
            if key in temps and len(temps[key]) > 0:
                return temps[key][0].current
        for key in temps:
            if "cpu" in key.lower() and len(temps[key]) > 0:
                return temps[key][0].current
    except:
        pass
    return 0.0

_proc_cache = {}

def get_top_procs(limit=6):
    global _proc_cache
    cpu_procs = []
    mem_procs = []
    all_procs = []
    
    # Get active PIDs
    try:
        pids = psutil.pids()
    except:
        return [], []
        
    new_cache = {}
    for pid in pids:
        if pid == 0:
            continue
        if pid in _proc_cache:
            proc = _proc_cache[pid]
        else:
            try:
                proc = psutil.Process(pid)
                # Initialize baseline CPU percentage
                proc.cpu_percent()
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                continue
        new_cache[pid] = proc
        
    _proc_cache = new_cache
    
    # Gather metrics
    for pid, proc in _proc_cache.items():
        try:
            cpu = proc.cpu_percent()
            mem = proc.memory_info()
            name = proc.name()
            all_procs.append({
                "pid": pid,
                "name": name,
                "cpu": cpu,
                "mem_mb": mem.rss / 1024 / 1024
            })
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            pass
            
    # Sort by CPU
    top_cpu = sorted(all_procs, key=lambda p: p["cpu"], reverse=True)[:limit]
    cpu_procs = [{"pid": p["pid"], "name": p["name"], "cpu": p["cpu"]} for p in top_cpu]
    
    # Sort by memory
    top_mem = sorted(all_procs, key=lambda p: p["mem_mb"], reverse=True)[:limit]
    mem_procs = [{"pid": p["pid"], "name": p["name"], "mem_mb": p["mem_mb"]} for p in top_mem]
    
    return cpu_procs, mem_procs

import threading

ping_results = {
    "gateway": -1.0,
    "cloudflare": -1.0,
    "google": -1.0
}

def get_default_gateway():
    try:
        with open("/proc/net/route") as fh:
            for line in fh:
                fields = line.strip().split()
                if len(fields) > 7 and fields[1] == '00000000' and fields[7] == '00000000':
                    gateway_hex = fields[2]
                    parts = [int(gateway_hex[i:i+2], 16) for i in range(0, 8, 2)]
                    parts.reverse()
                    return ".".join(map(str, parts))
    except:
        pass
    return "192.168.1.1"

def do_ping(ip):
    try:
        start = time.time()
        res = subprocess.run(["ping", "-c", "1", "-W", "1", ip], capture_output=True, timeout=1.2)
        if res.returncode == 0:
            match = re.search(r"time=([\d\.]+)\s*ms", res.stdout.decode('utf-8', errors='ignore'))
            if match:
                return float(match.group(1))
            return (time.time() - start) * 1000.0
    except:
        pass
    return -1.0

def ping_worker():
    global ping_results
    gateway_ip = get_default_gateway()
    while True:
        ping_results["gateway"] = do_ping(gateway_ip)
        ping_results["cloudflare"] = do_ping("1.1.1.1")
        ping_results["google"] = do_ping("8.8.8.8")
        time.sleep(2)

def main():
    t = threading.Thread(target=ping_worker, daemon=True)
    t.start()
    try:
        old_net = psutil.net_io_counters()
        old_time = time.time()
    except Exception as e:
        sys.stderr.write(f"Net counters error: {e}\n")
        old_net = None
        old_time = time.time()
        
    psutil.cpu_percent(interval=None)
    
    while True:
        try:
            time.sleep(2)
            current_time = time.time()
            dt = current_time - old_time
            if dt <= 0:
                dt = 1.0
                
            # Net speeds
            rx_speed = 0.0
            tx_speed = 0.0
            try:
                new_net = psutil.net_io_counters()
                if old_net and new_net:
                    rx_speed = (new_net.bytes_recv - old_net.bytes_recv) / dt
                    tx_speed = (new_net.bytes_sent - old_net.bytes_sent) / dt
                old_net = new_net
            except:
                pass
            old_time = current_time
            
            cpu = psutil.cpu_percent(interval=None)
            vm = psutil.virtual_memory()
            mem = vm.percent
            swap = psutil.swap_memory()
            
            # Per-core stats
            cpu_cores = psutil.cpu_percent(percpu=True)
            
            # CPU Frequency
            cpu_ghz = 0.0
            try:
                freq = psutil.cpu_freq()
                if freq:
                    cpu_ghz = freq.current / 1000.0
            except:
                pass
                
            # Top CPU and RAM processes
            cpu_p, mem_p = get_top_procs(limit=6)
            
            # GPU Stats (from amdgpu_top / sysfs)
            gpu_data = get_gpu_stats()
            
            output = {
                "cpu": cpu,
                "ram": mem,
                "ram_used_gib": (vm.total - vm.available) / 1024 / 1024 / 1024,
                "ram_total_gib": vm.total / 1024 / 1024 / 1024,
                "swap": swap.percent,
                "swap_used_gib": swap.used / 1024 / 1024 / 1024,
                "swap_total_gib": swap.total / 1024 / 1024 / 1024,
                "gpu": gpu_data["gpu"],
                "vram_used_gib": gpu_data["vram_used_gib"],
                "vram_total_gib": gpu_data["vram_total_gib"],
                "net_rx": format_speed(rx_speed),
                "net_tx": format_speed(tx_speed),
                "cpu_cores": cpu_cores,
                "cpu_ghz": cpu_ghz,
                "cpu_procs": cpu_p,
                "mem_procs": mem_p,
                "gpu_procs": gpu_data["gpu_procs"],
                "gpu_sclk": gpu_data["gpu_sclk"],
                "gpu_mclk": gpu_data["gpu_mclk"],
                "gpu_temp": gpu_data["gpu_temp"],
                "gpu_temp_junction": gpu_data["gpu_temp_junction"],
                "gpu_temp_mem": gpu_data["gpu_temp_mem"],
                "cpu_temp": get_cpu_temp(),
                "ping_gateway": ping_results["gateway"],
                "ping_cloudflare": ping_results["cloudflare"],
                "ping_google": ping_results["google"]
            }
            
            print(json.dumps(output), flush=True)
            
        except KeyboardInterrupt:
            break
        except Exception as e:
            print(json.dumps({"error": str(e)}), flush=True)

if __name__ == "__main__":
    main()
