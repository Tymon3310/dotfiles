#!/usr/bin/env python3
"""Find QR codes and barcodes in an image. Prints x|y|width|height|data per code."""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
from concurrent.futures import ThreadPoolExecutor

import numpy as np
from PIL import Image, ImageFilter

DEBUG = bool(os.environ.get("QR_DEBUG"))
MAX_CANDIDATES = 400
WORKERS = min(8, os.cpu_count() or 4)


def log(msg):
    if DEBUG:
        print(f"[qr] {msg}", file=sys.stderr, flush=True)


# --- Variants ----------------------------------------------------------------
# A variant is a gray uint8 image plus how to map points back to the original:
# p / scale + offset (sx/sy allow non-uniform scaling for stretched barcodes).
# linear=True restricts decoding to 1D barcodes.

class Variant:
    __slots__ = ("name", "img", "sx", "sy", "ox", "oy", "binarizers", "linear")

    def __init__(self, name, img, scale=1.0, ox=0, oy=0, binarizers=("local",),
                 sx=None, sy=None, linear=False):
        self.name = name
        self.img = np.ascontiguousarray(img, dtype=np.uint8)
        self.sx = sx or scale
        self.sy = sy or scale
        self.ox = ox
        self.oy = oy
        self.binarizers = binarizers
        self.linear = linear

    def to_original(self, xs, ys):
        return ([x / self.sx + self.ox for x in xs],
                [y / self.sy + self.oy for y in ys])


def dominant_background_mask(rgb):
    """Mask of pixels close to the most common colour, if it covers enough of the image."""
    q = (rgb >> 3).astype(np.int32)
    key = (q[..., 0] << 10) | (q[..., 1] << 5) | q[..., 2]
    counts = np.bincount(key.ravel(), minlength=1 << 15)
    bg = int(counts.argmax())
    if counts[bg] < 0.08 * key.size:
        return None, None
    color = np.array([(bg >> 10) * 8 + 4, ((bg >> 5) & 31) * 8 + 4, (bg & 31) * 8 + 4])
    dist = np.abs(rgb.astype(np.int16) - color).max(axis=2)
    return dist <= 10, color


def pad_white(arr, pad):
    return np.pad(arr, pad, mode="constant", constant_values=255)


def nearest_upscale(arr, factor):
    return np.repeat(np.repeat(arr, factor, axis=0), factor, axis=1)


def connected_boxes(occ, cell):
    """Bounding boxes (x, y, w, h, filled_area) of 4-connected regions in a cell grid."""
    gh, gw = occ.shape
    labels = np.zeros(occ.shape, dtype=bool)
    boxes = []
    ys, xs = np.nonzero(occ)
    for sy, sx in zip(ys.tolist(), xs.tolist()):
        if labels[sy, sx]:
            continue
        labels[sy, sx] = True
        stack = [(sy, sx)]
        y0 = y1 = sy
        x0 = x1 = sx
        n = 0
        while stack:
            cy, cx = stack.pop()
            n += 1
            if cy < y0: y0 = cy
            if cy > y1: y1 = cy
            if cx < x0: x0 = cx
            if cx > x1: x1 = cx
            for ny, nx in ((cy - 1, cx), (cy + 1, cx), (cy, cx - 1), (cy, cx + 1)):
                if 0 <= ny < gh and 0 <= nx < gw and occ[ny, nx] and not labels[ny, nx]:
                    labels[ny, nx] = True
                    stack.append((ny, nx))
        boxes.append((x0 * cell, y0 * cell, (x1 - x0 + 1) * cell, (y1 - y0 + 1) * cell,
                      n * cell * cell))
    return boxes


def cell_sum(arr, cell):
    gh, gw = arr.shape[0] // cell, arr.shape[1] // cell
    return arr[:gh * cell, :gw * cell].reshape(gh, cell, gw, cell).sum(axis=(1, 3))


def morph(mask, *ops):
    """Apply 3x3 'max'/'min' filters in sequence to a boolean grid."""
    img = Image.fromarray((mask * 255).astype(np.uint8))
    for op in ops:
        img = img.filter(ImageFilter.MaxFilter(3) if op == "max" else ImageFilter.MinFilter(3))
    return np.asarray(img) > 0


def find_candidate_boxes(gray, cell=4):
    """Locate dense, high-contrast blobs (code-like regions)."""
    h, w = gray.shape
    pil = Image.fromarray(gray)
    grad = (np.asarray(pil.filter(ImageFilter.MaxFilter(3))).astype(np.int16)
            - np.asarray(pil.filter(ImageFilter.MinFilter(3))))
    occ = cell_sum(grad > 60, cell) > 0.25 * cell * cell
    # Close gaps between modules, then open to cut thin card borders/underlines
    # that would merge a code into a big sparse blob
    occ = morph(occ, "max", "min", "min", "max")

    out = []
    for x, y, bw, bh, area in connected_boxes(occ, cell):
        if bw < 16 or bh < 10:
            continue
        if area < 0.3 * bw * bh:
            continue
        # Whole-screen sized blobs are just busy UI; the full-image passes cover them
        if bw * bh > 0.25 * w * h:
            continue
        out.append((x, y, bw, bh))
    out.sort(key=lambda b: -min(b[2], b[3]))
    return out[:MAX_CANDIDATES]


def find_bar_boxes(gray, cell=4):
    """Locate 1D barcode regions: cells where edges run strongly in one direction.

    QR/DataMatrix modules have edges both ways, so barcodes don't merge into them.
    Returns (x, y, w, h, orientation) with orientation 'v' (vertical bars) or 'h'.
    """
    g = gray.astype(np.int16)
    dx = np.zeros_like(g)
    dy = np.zeros_like(g)
    dx[:, 1:] = np.abs(np.diff(g, axis=1))
    dy[1:, :] = np.abs(np.diff(g, axis=0))
    sx, sy = cell_sum(dx, cell), cell_sum(dy, cell)
    strong = cell * cell * 25
    out = []
    for orient, a, b in (("v", sx, sy), ("h", sy, sx)):
        occ = (a > strong) & (a > 3 * b)
        # Bridge wide bars/gaps across the bar direction only
        occ = morph(occ, "max", "min")
        for x, y, bw, bh, area in connected_boxes(occ, cell):
            along, across = (bw, bh) if orient == "v" else (bh, bw)
            if along < 24 or across < 8 or area < 0.4 * bw * bh:
                continue
            # Whole region must be directional too (2D code modules can look
            # one-directional per cell, but not over the whole box)
            bx, by = sx[y // cell:(y + bh) // cell, x // cell:(x + bw) // cell].sum(), \
                sy[y // cell:(y + bh) // cell, x // cell:(x + bw) // cell].sum()
            ratio = bx / max(by, 1) if orient == "v" else by / max(bx, 1)
            if ratio < 4:
                continue
            out.append((x, y, bw, bh, orient))
    out.sort(key=lambda b: -b[2] * b[3])
    return out[:MAX_CANDIDATES // 4]


def barcode_spam(gray, box, idx):
    """Throw a pile of 1D-specific variants at a barcode region.

    Bars are made vertical (transposing if needed), then the crop is stretched
    at several scales/interpolations and decoded with linear formats only.
    Column-averaging collapses noise/JPEG/overlapping text into a clean
    synthetic barcode.
    """
    x, y, bw, bh, orient = box
    h, w = gray.shape
    m = 6
    x0, y0, x1, y1 = max(0, x - m), max(0, y - m), min(w, x + bw + m), min(h, y + bh + m)
    crop = gray[y0:y1, x0:x1]
    transposed = orient == "h"
    if transposed:
        crop = crop.T

    ch, cw = crop.shape
    col_avg = np.tile(crop.mean(axis=0), (max(24, ch), 1))
    out = []
    pad = 30
    for kind, src in (("raw", crop), ("avg", col_avg)):
        src_img = Image.fromarray(np.clip(src, 0, 255).astype(np.uint8))
        for fx in (2, 3, 4, 6):
            for interp_name, interp in (("n", Image.NEAREST), ("c", Image.BICUBIC)):
                tw, th = cw * fx, max(48, src.shape[0] * 2)
                big = pad_white(np.asarray(src_img.resize((tw, th), interp)), pad)
                ry = th / src.shape[0]
                if transposed:
                    big = big.T
                    sx, sy, ox, oy = ry, fx, x0 - pad / ry, y0 - pad / fx
                else:
                    sx, sy, ox, oy = fx, ry, x0 - pad / fx, y0 - pad / ry
                out.append(Variant(f"bar{idx}_{kind}{fx}{interp_name}", big, sx=sx, sy=sy,
                                   ox=ox, oy=oy, linear=True,
                                   binarizers=("local", "global", "fixed")))
    return out


def build_variants(rgb):
    gray = np.asarray(Image.fromarray(rgb).convert("L"))
    h, w = gray.shape
    variants = [
        Variant("gray", gray, binarizers=("local", "global", "fixed")),
    ]

    bg_mask, bg_color = dominant_background_mask(rgb)
    if bg_mask is not None:
        log(f"dominant background {bg_color.tolist()} covers {bg_mask.mean():.0%}")
        whitened = gray.copy()
        whitened[bg_mask] = 255
        variants.append(Variant("bg_white", whitened, binarizers=("local", "global")))
    else:
        whitened = gray

    # Coloured codes: darkest channel separates saturated modules from white,
    # brightest channel separates light-on-saturated (e.g. white on blue).
    variants.append(Variant("min_chan", rgb.min(axis=2)))
    variants.append(Variant("max_chan", rgb.max(axis=2)))

    if max(h, w) <= 2600:
        variants.append(Variant("up2", nearest_upscale(gray, 2), scale=2.0))

    # Candidate crops
    boxes = find_candidate_boxes(gray)
    log(f"{len(boxes)} candidate regions")
    for i, (x, y, bw, bh) in enumerate(boxes):
        m = max(4, min(bw, bh) // 12)
        x0, y0 = max(0, x - m), max(0, y - m)
        x1, y1 = min(w, x + bw + m), min(h, y + bh + m)
        crop = whitened[y0:y1, x0:x1]
        pad = max(12, min(x1 - x0, y1 - y0) // 8)
        crop = pad_white(crop, pad)
        side = min(x1 - x0, y1 - y0)
        factor = 3 if side < 80 else 2 if side < 350 else 1
        if factor > 1:
            crop = nearest_upscale(crop, factor)
        variants.append(Variant(f"blob{i}", crop, scale=float(factor),
                                ox=x0 - pad, oy=y0 - pad,
                                binarizers=("local", "global")))

    bars = find_bar_boxes(gray)
    log(f"{len(bars)} barcode regions")
    for i, box in enumerate(bars):
        variants.extend(barcode_spam(gray, box, i))
    return variants


# --- Decoders ------------------------------------------------------------------
# Each returns a list of (xs[4], ys[4], text, format) in variant coordinates.

def zxing_module_decoder():
    try:
        import zxingcpp
    except ImportError:
        return None
    B = zxingcpp.Binarizer
    bmap = {"local": B.LocalAverage, "global": B.GlobalHistogram, "fixed": B.FixedThreshold}
    F = zxingcpp.BarcodeFormat
    linear = getattr(F, "AllLinear", None) or getattr(F, "LinearCodes", None)

    def decode(variant):
        out = []
        kw = {"formats": linear} if variant.linear and linear is not None else {}
        for b in variant.binarizers:
            try:
                results = zxingcpp.read_barcodes(variant.img, binarizer=bmap[b], **kw)
            except Exception as e:
                log(f"zxingcpp error on {variant.name}: {e}")
                continue
            for r in results:
                if not r.valid or not r.text:
                    continue
                p = r.position
                pts = (p.top_left, p.top_right, p.bottom_right, p.bottom_left)
                out.append(([q.x for q in pts], [q.y for q in pts], r.text, str(r.format)))
        return out

    return "zxingcpp", lambda variants: run_parallel(decode, variants)


def zxing_cli_decoder():
    exe = shutil.which("ZXingReader")
    if not exe:
        return None

    def decode_all(variants):
        tmp = tempfile.mkdtemp(prefix="qrscan-")
        try:
            paths = {}
            def save(i_v):
                i, v = i_v
                path = os.path.join(tmp, f"{i}.png")
                Image.fromarray(v.img).save(path, compress_level=0)
                return path
            with ThreadPoolExecutor(WORKERS) as ex:
                for (i, v), path in zip(enumerate(variants), ex.map(save, enumerate(variants))):
                    paths[path] = v

            # One ZXingReader process per (binarizer, format set, chunk of files)
            jobs = []
            for b in ("local", "global", "fixed"):
                for linear in (False, True):
                    files = [p for p, v in paths.items()
                             if b in v.binarizers and v.linear == linear]
                    fmt = ["-formats", "AllLinear"] if linear else []
                    n = max(1, min(WORKERS, len(files) // 8 or 1))
                    for k in range(n):
                        chunk = files[k::n]
                        if chunk:
                            jobs.append([exe, "-json", "-binarizer", b, *fmt, *chunk])

            def run(cmd):
                try:
                    return subprocess.run(cmd, capture_output=True, text=True, timeout=20).stdout
                except Exception as e:
                    log(f"ZXingReader failed: {e}")
                    return ""

            results = []
            with ThreadPoolExecutor(WORKERS) as ex:
                for stdout in ex.map(run, jobs):
                    for line in stdout.splitlines():
                        try:
                            r = json.loads(line)
                        except ValueError:
                            continue
                        v = paths.get(r.get("FilePath"))
                        text = r.get("Text")
                        if v is None or not text or r.get("Error"):
                            continue
                        try:
                            pts = [tuple(map(int, p.split("x"))) for p in r["Position"].split()]
                        except (KeyError, ValueError):
                            continue
                        results.append((v, [p[0] for p in pts], [p[1] for p in pts],
                                        text, r.get("Format", "")))
            return results
        finally:
            shutil.rmtree(tmp, ignore_errors=True)

    return "ZXingReader", decode_all


def run_parallel(decode, variants):
    results = []
    with ThreadPoolExecutor(WORKERS) as ex:
        for v, res in zip(variants, ex.map(decode, variants)):
            for xs, ys, text, fmt in res:
                results.append((v, xs, ys, text, fmt))
    return results


def wechat_decoder():
    try:
        import cv2
        detector = cv2.wechat_qrcode.WeChatQRCode()
    except Exception:
        return None

    def decode(variant):
        try:
            texts, points = detector.detectAndDecode(variant.img)
        except Exception:
            return []
        out = []
        for text, pts in zip(texts, points):
            if text:
                out.append((pts[:, 0].tolist(), pts[:, 1].tolist(), text, "QRCode"))
        return out

    # The CNN is slow; only feed it the whole-image views at native scale.
    def decode_all(variants):
        return run_parallel(decode, [v for v in variants if v.name in ("gray", "bg_white")])

    return "wechat", decode_all


def zbar_decoder():
    try:
        from pyzbar import pyzbar
    except ImportError:
        pyzbar = None

    if pyzbar is not None:
        def decode(variant):
            out = []
            try:
                for obj in pyzbar.decode(variant.img):
                    text = obj.data.decode("utf-8", "replace")
                    if text and obj.polygon:
                        out.append(([p.x for p in obj.polygon], [p.y for p in obj.polygon],
                                    text, obj.type))
            except Exception:
                pass
            return out
        return "pyzbar", lambda variants: run_parallel(decode, variants)

    exe = shutil.which("zbarimg")
    if not exe:
        return None

    import re
    import xml.etree.ElementTree as ET
    ns = {"z": "http://zbar.sourceforge.net/2008/barcode"}

    def decode(variant):
        buf = tempfile.SpooledTemporaryFile()
        Image.fromarray(variant.img).save(buf, format="PNG", compress_level=1)
        buf.seek(0)
        try:
            xml = subprocess.run([exe, "-q", "--xml", "--set", "enable=1", "-"], stdin=buf,
                                 capture_output=True, text=True, timeout=10).stdout
            root = ET.fromstring(xml) if xml.strip() else None
        except Exception:
            return []
        out = []
        for sym in (root.findall(".//z:symbol", ns) if root is not None else []):
            data = sym.find("z:data", ns)
            poly = sym.find("z:polygon", ns)
            if data is None or not data.text or poly is None:
                continue
            coords = re.findall(r"([+-]?\d+),([+-]?\d+)", poly.get("points", ""))
            if coords:
                out.append(([int(c[0]) for c in coords], [int(c[1]) for c in coords],
                            data.text, sym.get("type", "")))
        return out

    return "zbarimg", lambda variants: run_parallel(decode, variants)


# --- Merging -------------------------------------------------------------------

def merge(detections, img_w, img_h):
    """Deduplicate by text + overlap. Keeps the tightest box per code."""
    boxes = []
    for v, xs, ys, text, fmt in detections:
        oxs, oys = v.to_original(xs, ys)
        x0, x1 = max(0, min(oxs)), min(img_w, max(oxs))
        y0, y1 = max(0, min(oys)), min(img_h, max(oys))
        # Linear barcodes report a thin line; give them some height
        if y1 - y0 < 6:
            cy = (y0 + y1) / 2
            y0, y1 = max(0, cy - 8), min(img_h, cy + 8)
        if x1 - x0 < 6:
            cx = (x0 + x1) / 2
            x0, x1 = max(0, cx - 8), min(img_w, cx + 8)
        boxes.append([x0, y0, x1, y1, text, fmt])

    # Area ascending so the tightest box for a code wins
    boxes.sort(key=lambda b: (b[2] - b[0]) * (b[3] - b[1]))
    unique = []
    for b in boxes:
        dupe = False
        for u in unique:
            if u[4] != b[4]:
                continue
            ix = max(0, min(b[2], u[2]) - max(b[0], u[0]))
            iy = max(0, min(b[3], u[3]) - max(b[1], u[1]))
            small = min((b[2] - b[0]) * (b[3] - b[1]), (u[2] - u[0]) * (u[3] - u[1]))
            if ix * iy > 0.4 * small:
                dupe = True
                break
        if not dupe:
            unique.append(b)
    unique.sort(key=lambda b: (b[1], b[0]))
    return unique


def escape(text):
    return text.replace("\\", "\\\\").replace("\n", "\\n").replace("\r", "\\r")


def main():
    t0 = time.time()
    if len(sys.argv) < 2:
        print("usage: qr.py <image>", file=sys.stderr)
        return 2
    path = sys.argv[1]
    try:
        img = Image.open(path)
        img.load()
    except Exception as e:
        print(f"qr.py: cannot read {path}: {e}", file=sys.stderr)
        return 1
    if img.mode in ("RGBA", "LA", "P"):
        # Composite transparency onto white so transparent quiet zones stay light
        img = img.convert("RGBA")
        bg = Image.new("RGBA", img.size, (255, 255, 255, 255))
        img = Image.alpha_composite(bg, img)
    rgb = np.asarray(img.convert("RGB"))
    h, w = rgb.shape[:2]

    variants = build_variants(rgb)
    log(f"{len(variants)} variants built in {time.time() - t0:.2f}s ({w}x{h})")

    primary = zxing_module_decoder() or zxing_cli_decoder()
    decoders = [d for d in (primary, wechat_decoder()) if d]
    if not primary:
        fallback = zbar_decoder()
        if fallback:
            decoders.append(fallback)
    if not decoders:
        print("qr.py: no decoder available (install zxing-cpp, opencv-contrib or zbar)",
              file=sys.stderr)
        return 1

    detections = []
    for name, decode_all in decoders:
        t = time.time()
        res = decode_all(variants)
        log(f"{name}: {len(res)} raw detections in {time.time() - t:.2f}s")
        detections.extend(res)

    codes = merge(detections, w, h)
    log(f"{len(codes)} unique codes, total {time.time() - t0:.2f}s")
    for x0, y0, x1, y1, text, fmt in codes:
        print(f"{int(x0)}|{int(y0)}|{int(round(x1 - x0))}|{int(round(y1 - y0))}|{escape(text)}",
              flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
