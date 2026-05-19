#!/usr/bin/env python3
import time

def get_cpu_times():
    with open('/proc/stat', 'r') as f:
        lines = f.readlines()
    cores = {}
    for line in lines:
        if line.startswith('cpu') and line[3].isdigit():
            parts = line.split()
            core_id = parts[0]
            idle = float(parts[4])
            total = sum(float(x) for x in parts[1:])
            cores[core_id] = (idle, total)
    return cores

t1 = get_cpu_times()
time.sleep(0.5)
t2 = get_cpu_times()

for core_id in sorted(t2.keys(), key=lambda x: int(x[3:])):
    prev_idle, prev_total = t1[core_id]
    idle, total = t2[core_id]
    
    diff_idle = idle - prev_idle
    diff_total = total - prev_total
    
    usage = 100 * (1 - diff_idle / diff_total)
    print(f"{core_id}:{usage:.1f}")
