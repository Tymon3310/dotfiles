#!/usr/bin/python3
import json
import sys
import os
import glob
import argparse
import time

UPDATE_INTERVAL = 2
PRIMARY_COLOR = "#48A3FF"
WARNING_COLOR = "#ff9a3c"
CRITICAL_COLOR = "#dc2f2f"
NEUTRAL_COLOR = "#FFFFFF"

CPU_PATTERNS = ["/sys/class/hwmon/hwmon*/temp*_input", "/sys/devices/platform/coretemp.*/hwmon/hwmon*/temp1_input"]
GPU_PATTERNS = ["/sys/class/drm/card*/device/hwmon/hwmon*/temp1_input", "/sys/class/hwmon/hwmon*/device/hwmon*/temp1_input"]

class TempMonitor:
    def __init__(self, device_type):
        self.device_type = device_type
        self.sensor_path = None
        self.crit_path = None
        self.crit_temp = 95.0
        self.find_sensors()

    def find_path(self, patterns):
        for pattern in patterns:
            paths = glob.glob(pattern)
            if paths: return paths[0]
        return None

    def find_sensors(self):
        patterns = CPU_PATTERNS if self.device_type == 'cpu' else GPU_PATTERNS
        self.sensor_path = self.find_path(patterns)
        if self.sensor_path:
            crit_try = self.sensor_path.replace("_input", "_crit")
            if os.path.exists(crit_try):
                self.crit_path = crit_try
                try:
                    with open(self.crit_path, 'r') as f: self.crit_temp = int(f.read().strip()) / 1000.0
                except: pass

    def get_temp(self):
        if not self.sensor_path: return None
        try:
            with open(self.sensor_path, 'r') as f: return int(f.read().strip()) / 1000.0
        except: return None

    def run(self):
        while True:
            temp = self.get_temp()
            if temp is None:
                self.find_sensors()
                temp = self.get_temp()

            if temp is None:
                print(json.dumps({"text": "N/A", "class": "error"}), flush=True)
            else:
                warning_temp = self.crit_temp - 15
                critical_temp = self.crit_temp - 5
                if temp >= critical_temp: color = CRITICAL_COLOR; css = "critical"
                elif temp >= warning_temp: color = WARNING_COLOR; css = "high"
                else: color = NEUTRAL_COLOR; css = "normal"

                icon = "" 
                label = "CPU" if self.device_type == 'cpu' else "GPU"
                text = f"<span color='{color}'>{icon} {temp:.1f}°C</span>"
                tooltip = f"<span color='{PRIMARY_COLOR}'>󰔏 {label} Temperature:</span>\n"
                tooltip += f" ├─ Current: {temp:.1f}°C\n"
                tooltip += f" └─ Critical: {self.crit_temp:.1f}°C"
                print(json.dumps({"text": text, "tooltip": tooltip, "class": css}), flush=True)
            time.sleep(UPDATE_INTERVAL)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('device', choices=['cpu', 'gpu'], help='Device to monitor')
    args = parser.parse_args()
    try:
        monitor = TempMonitor(args.device)
        monitor.run()
    except KeyboardInterrupt:
        sys.exit(0)