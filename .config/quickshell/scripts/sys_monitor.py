#!/usr/bin/env python3
import json
import sys
import time
import psutil
import os

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

def main():
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
            
            # CPU & Memory
            cpu = psutil.cpu_percent(interval=None)
            mem = psutil.virtual_memory().percent
            
            # GPU Stats
            gpu = 0
            vram_used = 0
            vram_total = 0
            
            gpu_str = read_file(GPU_USAGE_PATH)
            if gpu_str and gpu_str.isdigit():
                gpu = int(gpu_str)
                
            used_str = read_file(GPU_MEM_USED)
            total_str = read_file(GPU_MEM_TOTAL)
            if used_str and used_str.isdigit():
                vram_used = int(used_str)
            if total_str and total_str.isdigit():
                vram_total = int(total_str)
                
            print(json.dumps({
                "cpu": cpu,
                "ram": mem,
                "gpu": gpu,
                "vram_used_gib": vram_used / 1024 / 1024 / 1024,
                "vram_total_gib": vram_total / 1024 / 1024 / 1024,
                "net_rx": format_speed(rx_speed),
                "net_tx": format_speed(tx_speed)
            }), flush=True)
            
        except KeyboardInterrupt:
            break
        except Exception as e:
            print(json.dumps({"error": str(e)}), flush=True)

if __name__ == "__main__":
    main()
