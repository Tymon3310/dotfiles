#!/usr/bin/env python3
import sys
import os
import subprocess
import cv2
import numpy as np

def detect_zbar_cli(image_path):
    results = []
    try:
        # Enable all symbologies. 
        # By default zbar might enable only some. 
        # --set enable=1 turns on everything. (Check manually if this works, otherwise use specific list?)
        # zbarimg --help says: --set <symbology>.enable --enable <symbology>
        # Let's try --set enable=1 to switch all on.
        # Actually zbarimg man page says "enable" is a config for "decoder".
        cmd = ["/usr/bin/zbarimg", "-q", "--xml", "--set", "enable=1", image_path]
        result = subprocess.run(cmd, capture_output=True, text=True)
        xml_data = result.stdout
        
        if not xml_data.strip():
            return []

        import xml.etree.ElementTree as ET
        import re
        
        try:
            root = ET.fromstring(xml_data)
            ns = {"zbar": "http://zbar.sourceforge.net/2008/barcode"}
            for symbol in root.findall(".//zbar:symbol", ns):
                data_elem = symbol.find("zbar:data", ns)
                data = data_elem.text if data_elem is not None and data_elem.text else ""
                if not data: continue
                
                polygon = symbol.find("zbar:polygon", ns)
                if polygon is not None:
                    points_attr = polygon.get("points", "")
                    coords = re.findall(r"([+-]?[0-9]+),([+-]?[0-9]+)", points_attr)
                    if len(coords) >= 2:
                        xs = [int(c[0]) for c in coords]
                        ys = [int(c[1]) for c in coords]
                        x, y = min(xs), min(ys)
                        w, h = max(xs) - x, max(ys) - y
                        results.append((x, y, w, h, data))
        except ET.ParseError:
            pass
            
    except Exception as e:
        pass
        
    return results

def apply_preprocessing_variants(img, lite=False):
    # Returns list of (name, image, transform_func)
    variants = []
    
    # helper for logging
    def log(msg):
        print(f"[DEBUG] {msg}", file=sys.stderr, flush=True)
    
    h_img, w_img = img.shape[:2]
    log(f"Assuming image size: {w_img}x{h_img}. Lite mode: {lite}")
    
    # helper for offset
    def add_offset(name, image, offx, offy):
        def tr(pts):
            pts[:, 0] += offx
            pts[:, 1] += offy
            return pts
        variants.append((name, image, tr))
    
    # helper for simple add
    def add(name, image):
        add_offset(name, image, 0, 0)
    
    # 0. Tiles (Original) - Crucial for localizing small codes
    # User might have small image with MANY codes (e.g. 300x200). 
    # Tiling helps isolate them. Lowering threshold to 100.
    if h_img > 100 or w_img > 100:
        th = int(h_img * 0.6)
        tw = int(w_img * 0.6)
        
        add_offset("tile_tl", img[0:th, 0:tw], 0, 0)
        add_offset("tile_tr", img[0:th, w_img-tw:w_img], w_img-tw, 0)
        add_offset("tile_bl", img[h_img-th:h_img, 0:tw], 0, h_img-th)
        add_offset("tile_br", img[h_img-th:h_img, w_img-tw:w_img], w_img-tw, h_img-th)
        
        cy, cx = h_img//2, w_img//2
        stx, sty = cx - tw//2, cy - th//2
        add_offset("tile_center", img[sty:sty+th, stx:stx+tw], stx, sty)

    # 1. Original (if color) and Grayscale
    if len(img.shape) == 3:
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        
        # In Lite mode, Fast Pass already scanned the full image (likely Original/Inverted).
        # So we SKIP Original/Gray/Channels/Inverted in Lite mode to save massive time.
        # We ONLY want Tiles (generated above) for MicroQR.
        if not lite:
            add("original", img)
            add("gray", gray)
            
            # Channel Split Removed for Speed. 
            # ZBar prefers Grayscale (added above). 
            # Splitting adds 3 full-res variants with low ROI.
    else:
        gray = img
        if not lite:
             add("gray", gray)
            
    # Lite Mode Pruning
    if lite:
        # Balanced Mode: Speed + Thoroughness
        # Tiles (Step 0) + Inverted (Step 1) + CLAHE (Step 2)
        # We skip only the very slow filters (Adaptive/Eroded).
        
        inverted = cv2.bitwise_not(gray)
        add("inverted", inverted)
        
        # CLAHE (Contrast) - Crucial for "thoroughness" on poor quality images
        clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8,8))
        enhanced = clahe.apply(gray)
        add("clahe", enhanced)
        
        # Sharpening (Helpful for fuzzy barcodes)
        kernel = np.array([[0, -1, 0], 
                           [-1, 5,-1], 
                           [0, -1, 0]])
        sharpened = cv2.filter2D(gray, -1, kernel)
        add("sharpened", sharpened)
        
        log(f"Generated {len(variants)} variants (Lite: Tiles + Inv + CLAHE + Sharp)")
        return variants

    # --- Full Mode Only ---
    
    # 2. Inverted
    inverted = cv2.bitwise_not(gray)
    add("inverted", inverted)
        
    # 3. CLAHE
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8,8))
    enhanced = clahe.apply(gray)
    add("clahe", enhanced)
    
    # 4. Binary Thresholding
    _, binary = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    add("binary", binary)
    
    # 4. Binary Thresholding
    _, binary = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    add("binary", binary)
    
    # Pruned: Adaptive, Erode, Rotations are too slow and rarely needed.
    # ZBar handles rotation natively.
    # Otsu usually covers Adaptive cases.
    
    # 5. Sharpening (Moved from Lite to be available in Full too? It's cheap)
    kernel = np.array([[0, -1, 0], 
                       [-1, 5,-1], 
                       [0, -1, 0]])
    sharpened = cv2.filter2D(gray, -1, kernel)
    add("sharpened", sharpened)

    log(f"Generated {len(variants)} variants")
    return variants

import time

def main():
    start_time = time.time()
    if len(sys.argv) < 2:
        print("Missing argument", file=sys.stderr)
        return
    print("SCRIPT_STARTED", file=sys.stderr)

    # helper for logging
    def log(msg):
        print(f"[DEBUG] {msg}", file=sys.stderr, flush=True)

    img_path = sys.argv[1]
    log(f"Starting improved_qr.py on {img_path}")
    
    # Notify user we started
    # Disabled by user request
    # try:
    #     subprocess.Popen(["notify-send", "QR Scan Started", "Searching for codes..."])
    # except:
    #     pass
    
    if not os.path.exists(img_path):
        log(f"Image does not exist: {img_path}")
        return

    # --- FAST PASS ---
    log("Starting Fast Pass (ZBar)...")
    candidates_zbar = detect_zbar_cli(img_path)
    
    all_candidates = []
    lite_mode = False
    
    if len(candidates_zbar) > 0:
         log(f"Fast Pass success: {len(candidates_zbar)} codes found. Continuing to Lite Deep Scan for difficult codes...")
         all_candidates.extend(candidates_zbar)
         lite_mode = True
    else:
         log("Fast Pass found 0 codes. Starting Full Deep Scan...")

    # --- DEEP SCAN ---
    log("Reading image with OpenCV...")
    original_img = cv2.imread(img_path)
    if original_img is None:
        if not all_candidates:
             return
        # If we have zbar results but opencv failed to read, print zbar and exit
        unique_results = []
        for r in all_candidates:
            x, y, w, h, data = r
            if w <= 0 or h <= 0: continue
            is_dupe = False
            for ur in unique_results:
                ux, uy, uw, uh, udata = ur
                if udata == data:
                     is_dupe = True
                     break
            if not is_dupe:
                unique_results.append(r)
        for r in unique_results:
            print(f"{r[0]}|{r[1]}|{r[2]}|{r[3]}|{r[4]}", flush=True)
        return

    variants = []
    
    # Upscaling Logic
    h, w = original_img.shape[:2]
    
    # If image is reasonably small, upscale the whole thing
    # Reverting to size limit for SPEED. 
    # Upscaling 4K -> 8K takes 4x CPU time, which makes it "slow".
    # --- Scaling & Tiling Logic ---
    # --- Scaling & Tiling Logic ---
    if h < 3500 and w < 3500: 
        # 1. Standard Single Monitor (e.g. 4K, 1440p)
        # Apply standard filters (Gray, Inverted, CLAHE, Binary, Sharp)
        variants = apply_preprocessing_variants(original_img, lite=lite_mode)
        
        # 1. Standard Single Monitor (e.g. 4K, 1440p)
        gray = cv2.cvtColor(original_img, cv2.COLOR_BGR2GRAY) if len(original_img.shape) == 3 else original_img
        
        # Micro-Image Handling (e.g. 225px thumbnail)
        # 2x is not enough. We need 4x.
        if h < 500 and w < 500:
             # Cubic for smooth edges
             upscaled_4 = cv2.resize(gray, (0,0), fx=4.0, fy=4.0, interpolation=cv2.INTER_CUBIC)
             def tr_scale_4(pts):
                 return pts * 0.25
             variants.append(("upscaled_4x_cubic", upscaled_4, tr_scale_4))
             
             # Nearest Neighbor for sharp edges (Critical for tiny 1D barcodes)
             # If the barcode is 1px wide lines, Cubic blurs them. Nearest keeps them sharp.
             upscaled_4_n = cv2.resize(gray, (0,0), fx=4.0, fy=4.0, interpolation=cv2.INTER_NEAREST)
             variants.append(("upscaled_4x_nearest", upscaled_4_n, tr_scale_4))
             
             # High-Res Threshold (Sharpen + Binarize)
             # Often critical for "noisy" small text/barcodes

             _, upscaled_bin = cv2.threshold(upscaled_4, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
             variants.append(("upscaled_4x_binary", upscaled_bin, tr_scale_4))
             
             # Upscaled Inverted (For tiny inverted codes like test_11)
             upscaled_4_inv = cv2.bitwise_not(upscaled_4)
             variants.append(("upscaled_4x_inverted", upscaled_4_inv, tr_scale_4))
             
             # Upscaled Adaptive (Final hail mary for weird lighting/circular codes)
             upscaled_adapt = cv2.adaptiveThreshold(upscaled_4, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, 25, 2)
             variants.append(("upscaled_4x_adaptive", upscaled_adapt, tr_scale_4))
             
             # Padded (For Borderless Codes - User Request)
             # ZBar requires a quiet zone. We artificially add a 20px white border.
             # We use the upscaled image to rely on its resolution.
             upscaled_padding = 50 # 50px on 4x upscale = ~12px on original
             upscaled_padded = cv2.copyMakeBorder(upscaled_4, upscaled_padding, upscaled_padding, upscaled_padding, upscaled_padding, cv2.BORDER_CONSTANT, value=[255,255,255])
             
             def make_tr_padded(pts):
                 # Shift points back by padding, then scale down
                 pts[:, 0] -= upscaled_padding
                 pts[:, 1] -= upscaled_padding
                 return pts * 0.25
                 
             variants.append(("upscaled_4x_padded", upscaled_padded, make_tr_padded))
             
             # Padded Inverted (For Borderless Inverted Codes)
             # Invert first, THEN pad with white.
             # This turns "White on Black (borderless)" into "Black on White (bordered)"
             upscaled_inv_padded = cv2.copyMakeBorder(upscaled_4_inv, upscaled_padding, upscaled_padding, upscaled_padding, upscaled_padding, cv2.BORDER_CONSTANT, value=[255,255,255])
             variants.append(("upscaled_4x_inv_padded", upscaled_inv_padded, make_tr_padded))
        
        # Standard 2x (Linear = Fast)
        upscaled = cv2.resize(gray, (0,0), fx=2.0, fy=2.0, interpolation=cv2.INTER_LINEAR)
        def tr_scale(pts):
            return pts * 0.5
        variants.append(("upscaled_2x", upscaled, tr_scale))


    elif w > 1800:
        # 2. Dual Monitor / Ultrawide / Wide Strip
        #    Optimization: CLEAR global variants. 
        #    We do NOT want to run AdaptiveThreshold/Rotations on a 5000px empty background.
        #    Trust the Tiled chunks for detection.
        variants = [] 
        
        gray = cv2.cvtColor(original_img, cv2.COLOR_BGR2GRAY) if len(original_img.shape) == 3 else original_img
        
        check_w = 1500
        n_chunks = int(w / check_w) + 1
        chunk_w = int(w / n_chunks)
        overlap = 200
        
        for i in range(n_chunks):
             x1 = max(0, i * chunk_w - overlap)
             x2 = min(w, (i + 1) * chunk_w + overlap)
             
             chunk_img = gray[:, x1:x2]
             
             # Add chunk (Original Resolution)
             # Offset logic inlined:
             def make_tr_chunk(parent_x):
                 def tr_c(pts):
                     pts[:, 0] += parent_x
                     return pts
                 return tr_c
             variants.append((f"chunk_{i}", chunk_img, make_tr_chunk(x1)))
             
             # Upscale CHUNK 2x (CUBIC = QUALITY)
             # Cubic is essential for crisp 1D barcode edges, Linear is too blurry.
             # OPTIMIZATION: Only upscale if height is small (< 900px).
             if chunk_img.shape[0] < 900:
                 chunk_up = cv2.resize(chunk_img, (0,0), fx=2.0, fy=2.0, interpolation=cv2.INTER_CUBIC)
                 
                 def make_tr_chunk_up(parent_x):
                     def tr_c_up(pts):
                         pts = pts * 0.5   # Undo 2x scale
                         pts[:, 0] += parent_x # Add chunk offset
                         return pts
                     return tr_c_up
                 
                 variants.append((f"chunk_{i}_up2", chunk_up, make_tr_chunk_up(x1)))

    else:
        # 3. Huge / Abnormal Ratio (Fallback)
        #    Upscale the internally generated tiles from Step 0.
        current_variants = list(variants)
        for name, v_img, transform in current_variants:
            if "tile" in name:
                ht, wt = v_img.shape[:2]
                if ht < 2500 and wt < 2500:
                    gray_tile = cv2.cvtColor(v_img, cv2.COLOR_BGR2GRAY) if len(v_img.shape) == 3 else v_img
                    upscaled_tile = cv2.resize(gray_tile, (wt*2, ht*2), interpolation=cv2.INTER_CUBIC)
                    
                    def make_tr(parent_tr):
                        def tr_tile_upscale(pts):
                            return parent_tr(pts * 0.5)
                        return tr_tile_upscale
                    
                    variants.append((f"{name}_upscaled", upscaled_tile, make_tr(transform)))


    
    log(f"Running detection on {len(variants)} variants...")
    
    # Initialize Detectors
    wechat_detector = None
    try:
        wechat_detector = cv2.wechat_qrcode.WeChatQRCode()
    except:
        pass
        
    std_detector = cv2.QRCodeDetector()
    
    # Check for pyzbar (Fastest)
    HAS_PYZBAR = False
    try:
        from pyzbar import pyzbar
        HAS_PYZBAR = True
        log("Native pyzbar library found. Using in-memory detection (Fast).")
    except ImportError:
        log("Native pyzbar not found. Falling back to zbarimg subprocess (Slow).")

    # Check for zxing-cpp (The "Omni" Detector - Aztec, DataMatrix, PDF417...)
    HAS_ZXING = False
    try:
        import zxingcpp
        HAS_ZXING = True
        log("Native zxing-cpp library found. Enabled support for Aztec/DataMatrix/PDF417.")
    except ImportError:
        log("Native zxing-cpp not found. Aztec/DataMatrix/PDF417 support limited.")



    # Deduplication
    unique_results = []
    
    # Helper to run zxing logic
    def detect_zxing_variant(image_numpy):
        res = []
        if HAS_ZXING:
            try:
                # zxingcpp.read_barcodes returns list of results
                results = zxingcpp.read_barcodes(image_numpy)
                for res_obj in results:
                     if not res_obj.text: continue
                     
                     data = res_obj.text
                     h, w = image_numpy.shape[:2]
                     x, y = 0, 0
                     
                     # Extract coordinates from position object
                     # It has top_left, top_right, bottom_left, bottom_right which are Points (x, y)
                     try:
                         pos = res_obj.position
                         # Collect all x and y
                         xs = [pos.top_left.x, pos.top_right.x, pos.bottom_right.x, pos.bottom_left.x]
                         ys = [pos.top_left.y, pos.top_right.y, pos.bottom_right.y, pos.bottom_left.y]
                         
                         x = min(xs)
                         y = min(ys)
                         w = max(xs) - x
                         h = max(ys) - y
                         
                         res.append((int(x), int(y), int(w), int(h), data))
                     except:
                         pass
            except Exception:
                pass
        return res

    # Helper to run zbar logic (Native or Subprocess)
    
    # Helper to run zbar logic (Native or Subprocess)
    def detect_zbar_variant(image_numpy):
        # image_numpy is BGR or Grayscale
        res = []
        
        # 1. Native PyZbar (Preferred)
        if HAS_PYZBAR:
            try:
                # pyzbar likes grayscale or RGB. OpenCV is BGR.
                # If grayscale (2 dims), good. If BGR (3 dims), convert or pass correctly?
                # pyzbar.decode handles numpy arrays.
                # It expects [0, 255].
                decoded_objects = pyzbar.decode(image_numpy)
                for obj in decoded_objects:
                    data = obj.data.decode("utf-8")
                    if not data: continue
                    
                    # Rect: obj.rect (left, top, width, height)
                    x, y, w, h = obj.rect.left, obj.rect.top, obj.rect.width, obj.rect.height
                    res.append((x, y, w, h, data))
                return res
            except Exception as e:
                # log(f"PyZbar error: {e}")
                pass

        # 2. Subprocess Fallback (If pyzbar missing OR if we want to double check? No, pyzbar is zbar wrapper)
        # Only run fallback if pyzbar is missing.
        else:
             try:
                success, encoded_img = cv2.imencode('.png', image_numpy)
                if success:
                    # Reuse the bytes detector we wrote earlier
                    # But we need to move it or call it? 
                    # Let's just inline the logic or rely on the previous function definition?
                    # The previous function `detect_zbar_bytes` is defined inside `main` below.
                    # Wait, we are inside `main`.
                    return detect_zbar_bytes(encoded_img.tobytes())
             except:
                pass
        return res

    # Helper to run zbar on variant bytes (Legacy Subprocess)
    def detect_zbar_bytes(img_bytes):
        res = []
        try:
            # --set enable=1 to support all codes
            cmd = ["/usr/bin/zbarimg", "-q", "--xml", "--set", "enable=1", "-"]
            result = subprocess.run(cmd, input=img_bytes, capture_output=True, text=True)
            xml_data = result.stdout
            if not xml_data.strip(): return []
            
            import xml.etree.ElementTree as ET
            import re
            try:
                root = ET.fromstring(xml_data)
                ns = {"zbar": "http://zbar.sourceforge.net/2008/barcode"}
                for symbol in root.findall(".//zbar:symbol", ns):
                    data_elem = symbol.find("zbar:data", ns)
                    data = data_elem.text if data_elem is not None and data_elem.text else ""
                    if not data: continue
                    
                    polygon = symbol.find("zbar:polygon", ns)
                    if polygon is not None:
                        points_attr = polygon.get("points", "")
                        coords = re.findall(r"([+-]?[0-9]+),([+-]?[0-9]+)", points_attr)
                        if len(coords) >= 2:
                            xs = [int(c[0]) for c in coords]
                            ys = [int(c[1]) for c in coords]
                            x, y = min(xs), min(ys)
                            w, h = max(xs) - x, max(ys) - y
                            res.append((x, y, w, h, data))
            except:
                pass
        except:
            pass
        return res
        res = []
        try:
            # --set enable=1 to support all codes
            cmd = ["/usr/bin/zbarimg", "-q", "--xml", "--set", "enable=1", "-"]
            result = subprocess.run(cmd, input=img_bytes, capture_output=True, text=True)
            xml_data = result.stdout
            if not xml_data.strip(): return []
            
            import xml.etree.ElementTree as ET
            import re
            try:
                root = ET.fromstring(xml_data)
                ns = {"zbar": "http://zbar.sourceforge.net/2008/barcode"}
                for symbol in root.findall(".//zbar:symbol", ns):
                    data_elem = symbol.find("zbar:data", ns)
                    data = data_elem.text if data_elem is not None and data_elem.text else ""
                    if not data: continue
                    
                    polygon = symbol.find("zbar:polygon", ns)
                    if polygon is not None:
                        points_attr = polygon.get("points", "")
                        coords = re.findall(r"([+-]?[0-9]+),([+-]?[0-9]+)", points_attr)
                        if len(coords) >= 2:
                            xs = [int(c[0]) for c in coords]
                            ys = [int(c[1]) for c in coords]
                            x, y = min(xs), min(ys)
                            w, h = max(xs) - x, max(ys) - y
                            res.append((x, y, w, h, data))
            except:
                pass
        except:
            pass
        return res

    # Parallel Detection
    import concurrent.futures
    import threading
    
    # Thread-safe collection
    # Actually, we can just collect results from futures.
    # But detectors might need to be thread-local or initialized inside?
    # PyZbar and ZXing are native calls, likely releasing GIL.
    # OpenCV detectors are objects.
    
    # Prepare detectors. 
    # To be safe, we should perhaps create detectors per thread or rely on them being reentrant.
    # cv2.QRCodeDetector is generally thread-safe for detectAndDecodeMulti?
    # cv2.wechat_qrcode.WeChatQRCode documentation says safe? 
    # Let's share them but put a lock around them if needed?
    # Or just instantiate them per thread? 
    # WeChat model loading is heavy, so sharing is preferred.
    # Let's assume standard opencv usage is thread-safe (it usually is for C++ backend).
    
    # We will define a processing function
    def process_single_variant(args):
        try:
            name, v_img, transform = args
            # log(f"Processing {name}")
            local_candidates = []
            
            # ZBar
            z_res = detect_zbar_variant(v_img)
            if z_res:
                for zr in z_res:
                     x, y, w, h, data = zr
                     pts = np.array([[x, y], [x+w, y], [x+w, y+h], [x, y+h]], dtype=float)
                     if transform: pts = transform(pts)
                     pts = pts.astype(int)
                     nx_min = np.min(pts[:, 0])
                     nx_max = np.max(pts[:, 0])
                     ny_min = np.min(pts[:, 1])
                     ny_max = np.max(pts[:, 1])
                     nw = nx_max - nx_min
                     nh = ny_max - ny_min
                     local_candidates.append((int(nx_min), int(ny_min), int(nw), int(nh), data))

            # ZXing
            zx_res = detect_zxing_variant(v_img)
            if zx_res:
                 for zxr in zx_res:
                     x, y, w, h, data = zxr
                     pts = np.array([[x, y], [x+w, y], [x+w, y+h], [x, y+h]], dtype=float)
                     if transform: pts = transform(pts)
                     pts = pts.astype(int)
                     nx_min = np.min(pts[:, 0])
                     nx_max = np.max(pts[:, 0])
                     ny_min = np.min(pts[:, 1])
                     ny_max = np.max(pts[:, 1])
                     nw = nx_max - nx_min
                     nh = ny_max - ny_min
                     local_candidates.append((int(nx_min), int(ny_min), int(nw), int(nh), data))

            # WeChat
            if wechat_detector:
                try:
                    h_v, w_v = v_img.shape[:2]
                    if h_v < 5000 and w_v < 5000:
                        res, points = wechat_detector.detectAndDecode(v_img)
                        if res:
                           for i_r, data in enumerate(res):
                                if not data: continue
                                pts = points[i_r].astype(float)
                                if transform: pts = transform(pts)
                                pts = pts.astype(int)
                                x_min, x_max = np.min(pts[:, 0]), np.max(pts[:, 0])
                                y_min, y_max = np.min(pts[:, 1]), np.max(pts[:, 1])
                                local_candidates.append((int(x_min), int(y_min), int(x_max-x_min), int(y_max-y_min), data))
                except: pass

            # Standard
            try:
                retval, decoded_info, points, _ = std_detector.detectAndDecodeMulti(v_img)
                if retval:
                    for i_r, data in enumerate(decoded_info):
                        if not data: continue
                        pts = points[i_r].astype(float)
                        if transform: pts = transform(pts)
                        pts = pts.astype(int)
                        x_min, x_max = np.min(pts[:, 0]), np.max(pts[:, 0])
                        y_min, y_max = np.min(pts[:, 1]), np.max(pts[:, 1])
                        local_candidates.append((int(x_min), int(y_min), int(x_max-x_min), int(y_max-y_min), data))
            except: pass
            


            return local_candidates
        except Exception as e:
            # log(f"Thread Error: {e}")
            return []

    # Prepare inputs
    # variants is list of (name, img, transform)
    
    log(f"Running detection on {len(variants)} variants using ThreadPool...")
    
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as executor:
        # Submit all tasks
        # Keep ORDER deterministic (ZBar variants first, etc)
        future_to_name = {executor.submit(process_single_variant, v): v[0] for v in variants}
        
        # Iterate keys (futures) in insertion order? dict preserves insertion order since Py3.7.
        # But safest is to iterate list of futures.
        futures_list = list(future_to_name.keys())
        
        for future in futures_list:
            try:
                # Wait for each in order
                res = future.result()
                all_candidates.extend(res)
            except Exception as exc:
                pass
                
    # Deduplication starts below...
    unique_results = []
    
    for r in all_candidates:
        x, y, w, h, data = r
        if w <= 0 or h <= 0: continue
        
        is_dupe = False
        for ur in unique_results:
            ux, uy, uw, uh, udata = ur
            
            # Text must match
            if udata == data:
                # Check center distance
                cx1 = x + w/2
                cy1 = y + h/2
                cx2 = ux + uw/2
                cy2 = uy + uh/2
                dist = (cx1 - cx2)**2 + (cy1 - cy2)**2
                
                # Check Overlap (IoU-ish)
                # If one box is roughly inside the other, or centers very close
                # 50px threshold (2500 sq px)
                if dist < 2500: 
                    is_dupe = True
                    break
                
                # Also check intersection
                # If they intersect significantly, they are the same code
                ix1 = max(x, ux)
                iy1 = max(y, uy)
                ix2 = min(x+w, ux+uw)
                iy2 = min(y+h, uy+uh)
                
                iw = max(0, ix2 - ix1)
                ih = max(0, iy2 - iy1)
                intersection = iw * ih
                
                area1 = w * h
                area2 = uw * uh
                
                # If overlap > 50% of the smaller box, it's a dupe
                if intersection > 0.5 * min(area1, area2):
                    is_dupe = True
                    break

        if not is_dupe:
            unique_results.append(r)

    elapsed = time.time() - start_time
    log(f"Deep Scan complete. Found total {len(unique_results)} unique codes. Took {elapsed:.2f}s")
    
    # Notify result
    # Disabled by user request
    # try:
    #     subprocess.Popen(["notify-send", "QR Scan Complete", f"Found {len(unique_results)} codes"])
    # except:
    #     pass

    for r in unique_results:
        print(f"{r[0]}|{r[1]}|{r[2]}|{r[3]}|{r[4]}", flush=True)

if __name__ == "__main__":
    main()
