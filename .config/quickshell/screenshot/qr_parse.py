#!/usr/bin/env python3
import sys
import xml.etree.ElementTree as ET
import re

try:
    xml_data = sys.stdin.read()
    if not xml_data.strip():
        sys.exit(0)
    root = ET.fromstring(xml_data)
    ns = {"zbar": "http://zbar.sourceforge.net/2008/barcode"}
    for symbol in root.findall(".//zbar:symbol", ns):
        data_elem = symbol.find("zbar:data", ns)
        data = data_elem.text if data_elem is not None and data_elem.text else ""
        polygon = symbol.find("zbar:polygon", ns)
        if polygon is not None:
            points_attr = polygon.get("points", "")
            coords = re.findall(r"([+-]?[0-9]+),([+-]?[0-9]+)", points_attr)
            if len(coords) >= 2:
                xs = [int(c[0]) for c in coords]
                ys = [int(c[1]) for c in coords]
                x, y = min(xs), min(ys)
                w, h = max(xs) - x, max(ys) - y
                print(f"{x}|{y}|{w}|{h}|{data}")
except:
    pass
