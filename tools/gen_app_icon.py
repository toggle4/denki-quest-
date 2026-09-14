#!/usr/bin/env python3
"""アプリアイコン（1024x1024 PNG）を標準ライブラリだけで描画する。

再生成: python3 tools/gen_app_icon.py
"""
import struct
import zlib
from pathlib import Path

SIZE = 1024
OUT = Path(__file__).resolve().parent.parent / "DenkiQuest" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon.png"

NAVY_TOP = (27, 37, 80)
NAVY_BOTTOM = (12, 16, 40)
BOLT = (255, 214, 0)
BOLT_EDGE = (201, 151, 0)

# 稲妻の多角形（0..1 の座標）
BOLT_POLY = [(0.56, 0.12), (0.30, 0.56), (0.48, 0.56), (0.42, 0.88), (0.72, 0.42), (0.54, 0.42)]


def point_in_poly(x, y, poly):
    inside = False
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if (yi > y) != (yj > y):
            xcross = (xj - xi) * (y - yi) / (yj - yi) + xi
            if x < xcross:
                inside = not inside
        j = i
    return inside


def dist_to_segment(px, py, ax, ay, bx, by):
    dx, dy = bx - ax, by - ay
    if dx == dy == 0:
        return ((px - ax) ** 2 + (py - ay) ** 2) ** 0.5
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
    cx, cy = ax + t * dx, ay + t * dy
    return ((px - cx) ** 2 + (py - cy) ** 2) ** 0.5


def dist_to_poly_edge(x, y, poly):
    best = 1e9
    for i in range(len(poly)):
        ax, ay = poly[i]
        bx, by = poly[(i + 1) % len(poly)]
        best = min(best, dist_to_segment(x, y, ax, ay, bx, by))
    return best


def pixel(x, y):
    u, v = x / SIZE, y / SIZE
    t = v
    r = int(NAVY_TOP[0] * (1 - t) + NAVY_BOTTOM[0] * t)
    g = int(NAVY_TOP[1] * (1 - t) + NAVY_BOTTOM[1] * t)
    b = int(NAVY_TOP[2] * (1 - t) + NAVY_BOTTOM[2] * t)

    # 中央のやわらかい光
    d = ((u - 0.5) ** 2 + (v - 0.5) ** 2) ** 0.5
    glow = max(0.0, 1 - d / 0.45) ** 2 * 0.35
    r = int(r + (255 - r) * glow * 0.9)
    g = int(g + (232 - g) * glow * 0.9)
    b = int(b + (115 - b) * glow * 0.6)

    if point_in_poly(u, v, BOLT_POLY):
        edge = dist_to_poly_edge(u, v, BOLT_POLY)
        return BOLT_EDGE if edge < 0.012 else BOLT
    return (r, g, b)


def write_png(path, size, rows):
    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    raw = b"".join(b"\x00" + row for row in rows)
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    path.write_bytes(png)


rows = []
for y in range(SIZE):
    row = bytearray()
    for x in range(SIZE):
        row.extend(pixel(x, y))
    rows.append(bytes(row))
write_png(OUT, SIZE, rows)
print(f"wrote {OUT} ({OUT.stat().st_size} bytes)")
