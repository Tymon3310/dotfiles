#!/usr/bin/python3
import json
import sys
import os
import argparse
import psutil
import time
import re
import glob

UPDATE_INTERVAL = 2
PRIMARY_COLOR = "#48A3FF"
WHITE_COLOR = "#FFFFFF"
WARNING_COLOR = "#ff9a3c"
CRITICAL_COLOR = "#dc2f2f"
NEUTRAL_COLOR = "#FFFFFF"

GPU_USAGE_PATH = "/sys/class/drm/card1/device/gpu_busy_percent"
GPU_MEM_TOTAL = "/sys/class/drm/card1/device/mem_info_vram_total"
GPU_MEM_USED = "/sys/class/drm/card1/device/mem_info_vram_used"
GPU_CLOCK_PATH = "/sys/class/drm/card1/device/pp_dpm_sclk"

class SystemMonitor:
    def __init__(self, mode):
        self.mode = mode
        self.gpu_prev_state = {}
        self.gpu_prev_time = 0
        self.cpu_prev_state = {} 
        self.cpu_prev_time = time.time()
        
        self.cached_gpu_procs = []
        psutil.cpu_percent(interval=None)

    def read_file(self, path):
        try:
            with open(path, 'r') as f: return f.read().strip()
        except: return None

    def get_top_cpu_procs(self):
        current_time = time.time()
        time_delta = current_time - self.cpu_prev_time
        if time_delta < 0.1: time_delta = 0.1
        
        new_cpu_state = {}
        procs = []

        for p in psutil.process_iter(['pid', 'name', 'cpu_times']):
            try:
                t = p.info['cpu_times']
                total_time = t.user + t.system
                new_cpu_state[p.pid] = total_time
                
                if p.pid in self.cpu_prev_state:
                    diff = total_time - self.cpu_prev_state[p.pid]
                    usage = (diff / time_delta) * 100
                    if usage > 0.5:
                        procs.append({'name': p.info['name'], 'pid': p.pid, 'cpu_percent': usage})
            except: continue
        
        self.cpu_prev_state = new_cpu_state
        self.cpu_prev_time = current_time
        return sorted(procs, key=lambda x: x['cpu_percent'], reverse=True)[:5]

    def get_top_mem_procs(self):
        procs = []
        for p in psutil.process_iter(['pid', 'name', 'memory_percent']):
            try:
                if p.info['memory_percent'] > 0.5:
                    procs.append(p.info)
            except: continue
        return sorted(procs, key=lambda x: x['memory_percent'], reverse=True)[:5]

    def get_top_gpu_procs(self):
        current_time = time.time_ns()
        current_state = {}
        results = []
        time_delta = current_time - self.gpu_prev_time
        if time_delta <= 0: time_delta = 1

        try:
            pids = [pid for pid in os.listdir('/proc') if pid.isdigit()]
            for pid in pids:
                try:
                    fd_dir = f'/proc/{pid}/fdinfo'
                    if not os.path.exists(fd_dir): continue
                    usage_ns = 0
                    mem_bytes = 0
                    for fd in os.listdir(fd_dir):
                        try:
                            with open(f'{fd_dir}/{fd}', 'r') as f:
                                content = f.read()
                                if 'drm-driver: amdgpu' in content:
                                    m = re.search(r'drm-memory-vram:\s*(\d+)', content)
                                    if m: mem_bytes += int(m.group(1)) * 1024
                                    m = re.search(r'drm-engine-.*:\s*(\d+)', content)
                                    if m: usage_ns += int(m.group(1))
                        except: continue

                    if usage_ns > 0 or mem_bytes > 0:
                        current_state[pid] = usage_ns
                        load_pct = 0.0
                        if pid in self.gpu_prev_state:
                            prev_ns = self.gpu_prev_state[pid]
                            load_pct = ((usage_ns - prev_ns) / time_delta) * 100
                        if load_pct > 0.5 or mem_bytes > 0:
                            try:
                                name = psutil.Process(int(pid)).name()
                                results.append({"name": name, "usage": load_pct, "mem": mem_bytes})
                            except: pass
                except: continue
        except: pass

        self.gpu_prev_state = current_state
        self.gpu_prev_time = current_time
        return sorted(results, key=lambda x: x['usage'], reverse=True)[:5]

    def get_cpu_data(self):
        total = psutil.cpu_percent(interval=None)
        per_core = psutil.cpu_percent(interval=None, percpu=True)
        freq = psutil.cpu_freq().current if psutil.cpu_freq() else 0
        load = os.getloadavg()
        top_procs = self.get_top_cpu_procs()

        if total > 90:
            text = f" <span color='{CRITICAL_COLOR}'>{total:.1f}%</span>"
            css = "critical"
        elif total > 70:
            text = f" <span color='{WARNING_COLOR}'>{total:.1f}%</span>"
            css = "high"
        else:
            text = f" {total:.1f}%"
            css = "normal"

        tt = f"<span color='{PRIMARY_COLOR}'>󰍛 CPU Usage: {total:.1f}%</span>\n"
        tt += f"<span color='{PRIMARY_COLOR}'>󰘚 Per-Core:</span>\n"
        rows = [per_core[i:i+4] for i in range(0, len(per_core), 4)]
        for i, row in enumerate(rows):
            row_str = []
            for j, core in enumerate(row):
                c_idx = i*4 + j
                col = CRITICAL_COLOR if core > 90 else WARNING_COLOR if core > 70 else NEUTRAL_COLOR
                row_str.append(f"C{c_idx}:<span color='{col}'>{core:2.0f}%</span>")
            tt += " " + " ".join(row_str) + "\n"

        tt += f"\n<span color='{PRIMARY_COLOR}'>󰓅 Freq:</span> {freq/1000:.2f}GHz"
        tt += f"   <span color='{PRIMARY_COLOR}'>󱘲 Load:</span> {load[0]:.2f}\n"

        if top_procs:
            tt += f"\n<span color='{PRIMARY_COLOR}'>󰍛 Top Processes:</span>\n"
            for p in top_procs:
                col = CRITICAL_COLOR if p['cpu_percent'] > 50 else WARNING_COLOR if p['cpu_percent'] > 25 else NEUTRAL_COLOR
                tt += f" ├─ {p['name']}: <span color='{col}'>{p['cpu_percent']:.1f}%</span>\n"

        return {"text": text, "tooltip": tt, "class": css}

    def get_gpu_data(self):
        try: usage = int(self.read_file(GPU_USAGE_PATH) or 0)
        except: usage = 0
        try: 
            mem_used = int(self.read_file(GPU_MEM_USED) or 0)
            mem_total = int(self.read_file(GPU_MEM_TOTAL) or 1)
        except: mem_used, mem_total = 0, 1
        clock = 0
        content = self.read_file(GPU_CLOCK_PATH)
        if content:
            m = re.search(r"(\d+)\s*Mhz\s*\*", content)
            if m: clock = int(m.group(1))
        top_procs = self.get_top_gpu_procs()

        if usage > 90:
            text = f"GPU:<span color='{CRITICAL_COLOR}'>{usage}%</span>"
            css = "critical"
        elif usage > 70:
            text = f"GPU:<span color='{WARNING_COLOR}'>{usage}%</span>"
            css = "high"
        else:
            text = f"GPU:{usage}%"
            css = "normal"

        tt = f"<span color='{PRIMARY_COLOR}'>󰢮 GPU Usage: {usage}%</span>\n"
        tt += f" ├─ Clock: {clock} MHz\n"
        tt += f" └─ VRAM: {mem_used/1024/1024/1024:.1f}GiB / {mem_total/1024/1024/1024:.1f}GiB ({(mem_used/mem_total)*100:.0f}%)\n"

        if top_procs:
            tt += f"\n<span color='{PRIMARY_COLOR}'>󰢮 Top Processes:</span>\n"
            for p in top_procs:
                col = CRITICAL_COLOR if p['usage'] > 80 else NEUTRAL_COLOR
                mem_str = f"({p['mem']/1024/1024:.0f}MiB)" if p['mem'] > 0 else ""
                tt += f" ├─ {p['name']}: <span color='{col}'>{p['usage']:.0f}%</span> {mem_str}\n"

        return {"text": text, "tooltip": tt, "class": css}

    def get_mem_data(self):
        mem = psutil.virtual_memory()
        swap = psutil.swap_memory()
        top_procs = self.get_top_mem_procs()

        if mem.percent > 90:
            text = f"<span color='{CRITICAL_COLOR}'>{mem.percent}%</span>"
            css = "critical"
        elif mem.percent > 70:
            text = f"<span color='{WARNING_COLOR}'>{mem.percent}%</span>"
            css = "high"
        else:
            text = f"{mem.percent}%"
            css = "normal"

        tt = f"<span color='{PRIMARY_COLOR}'>RAM Usage: {mem.percent}%</span>\n"
        tt += f" ├─ Used: {mem.used/1024/1024/1024:.1f}GiB\n"
        tt += f" └─ Total: {mem.total/1024/1024/1024:.1f}GiB\n"
        if swap.total > 0:
            tt += f"\n<span color='{PRIMARY_COLOR}'>󰓡 Swap: {swap.percent}%</span>\n"
        if top_procs:
            tt += f"\n<span color='{PRIMARY_COLOR}'>󰅵 Top Processes:</span>\n"
            for p in top_procs:
                col = CRITICAL_COLOR if p['memory_percent'] > 10 else NEUTRAL_COLOR
                tt += f" ├─ {p['name']}: <span color='{col}'>{p['memory_percent']:.1f}%</span>\n"

        return {"text": text, "tooltip": tt, "class": css}

    def run(self):
        while True:
            try:
                if self.mode == 'cpu': output = self.get_cpu_data()
                elif self.mode == 'gpu': output = self.get_gpu_data()
                elif self.mode == 'memory': output = self.get_mem_data()
                elif self.mode == 'combined':
                    c = self.get_cpu_data()
                    m = self.get_mem_data()
                    output = {"text": f"{c['text']} {m['text']}", "tooltip": c['tooltip'] + "\n\n" + m['tooltip'], "class": "normal"}
                print(json.dumps(output), flush=True)
            except Exception as e:
                print(json.dumps({"text": "Err", "tooltip": str(e)}), flush=True)
            time.sleep(UPDATE_INTERVAL)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('device', choices=['cpu', 'gpu', 'memory', 'combined'])
    args = parser.parse_args()
    try:
        monitor = SystemMonitor(args.device)
        monitor.run()
    except KeyboardInterrupt:
        sys.exit(0)