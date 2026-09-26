#!/usr/bin/env python3
"""教材 F01〜F08 の図（SVG）を生成して Assets.xcassets/Figures/<name>.imageset に置く。

教材テキストの <!-- figure: 名前 --> で参照される図。数値は本文の例題とそろえてある。
Xcode の SVG レンダラは <text> を落とすことがあるので、数字・記号・英字も線で描く。
日本語は図に入れない（本文で説明する）。

色の決まり（全図共通）:
  電流 = 青、電圧 = 赤、電力・熱 = 橙、抵抗・配線 = 紺、補助線 = 灰

再生成: python3 tools/gen_lesson_figures.py
確認用の PNG（任意）: python3 tools/gen_lesson_figures.py --preview <出力フォルダ>
"""
import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FIG = ROOT / "DenkiQuest" / "Assets.xcassets" / "Figures"

INK = "#1B2550"
GRAY = "#8A93B0"
LINE = "#C9D0E3"
LIGHT = "#EEF1F8"
BLUE = "#2F6FDB"
BLUE_L = "#DCE8FB"
RED = "#E0533D"
RED_L = "#FBE3DE"
ORANGE = "#E8841F"
ORANGE_L = "#FDEBD6"
COPPER = "#D9822B"
COPPER_L = "#F6D9BA"
GREEN = "#1E9E6A"
GREEN_L = "#DDF3EA"
YEL = "#C99700"
YEL_L = "#FFF3C4"
WHITE = "#FFFFFF"

W, H = 420, 240

# ---------------------------------------------------------------------------
# 線で描く文字。座標は 幅 10 × 高さ 14（大文字の高さ）。y は下向き。
# ("dot", x, y) は塗りの点、("ring", x, y, r) は小さな輪。
# ---------------------------------------------------------------------------
G = {
    "0": [[(2, 0), (8, 0), (10, 2), (10, 12), (8, 14), (2, 14), (0, 12), (0, 2), (2, 0)]],
    "1": [[(2, 3), (5, 0), (5, 14)], [(2, 14), (8, 14)]],
    "2": [[(0, 3), (2, 0), (8, 0), (10, 2), (10, 5), (0, 14), (10, 14)]],
    "3": [[(0, 1), (3, 0), (8, 0), (10, 2), (10, 5), (8, 7), (4, 7)],
          [(8, 7), (10, 9), (10, 12), (8, 14), (2, 14), (0, 13)]],
    "4": [[(7, 14), (7, 0), (0, 10), (10, 10)]],
    "5": [[(10, 0), (1, 0), (0, 6), (7, 6), (10, 8), (10, 12), (8, 14), (2, 14), (0, 12)]],
    "6": [[(9, 1), (7, 0), (3, 0), (0, 3), (0, 11), (2, 14), (8, 14), (10, 12), (10, 9), (8, 7), (2, 7), (0, 9)]],
    "7": [[(0, 0), (10, 0), (4, 14)]],
    "8": [[(2, 0), (8, 0), (10, 2), (10, 5), (8, 7), (2, 7), (0, 5), (0, 2), (2, 0)],
          [(2, 7), (0, 9), (0, 12), (2, 14), (8, 14), (10, 12), (10, 9), (8, 7)]],
    "9": [[(10, 5), (8, 7), (2, 7), (0, 5), (0, 2), (2, 0), (8, 0), (10, 2), (10, 11), (7, 14), (3, 14), (1, 13)]],
    "A": [[(0, 14), (5, 0), (10, 14)], [(2, 9), (8, 9)]],
    "B": [[(0, 0), (0, 14), (8, 14), (10, 12), (10, 9), (8, 7), (0, 7)], [(0, 0), (8, 0), (10, 2), (10, 5), (8, 7)]],
    "C": [[(10, 2), (8, 0), (2, 0), (0, 2), (0, 12), (2, 14), (8, 14), (10, 12)]],
    "G": [[(10, 2), (8, 0), (2, 0), (0, 2), (0, 12), (2, 14), (8, 14), (10, 12), (10, 8), (6, 8)]],
    "I": [[(5, 0), (5, 14)], [(2, 0), (8, 0)], [(2, 14), (8, 14)]],
    "J": [[(3, 0), (10, 0)], [(7, 0), (7, 11), (5, 14), (2, 14), (0, 12)]],
    "L": [[(0, 0), (0, 14), (10, 14)]],
    "M": [[(0, 14), (0, 0), (5, 8), (10, 0), (10, 14)]],
    "P": [[(0, 14), (0, 0), (8, 0), (10, 2), (10, 5), (8, 7), (0, 7)]],
    "Q": [[(2, 0), (8, 0), (10, 2), (10, 12), (8, 14), (2, 14), (0, 12), (0, 2), (2, 0)], [(6, 10), (10, 15)]],
    "R": [[(0, 14), (0, 0), (7, 0), (10, 2), (10, 5), (7, 7), (0, 7)], [(6, 7), (10, 14)]],
    "S": [[(10, 2), (8, 0), (2, 0), (0, 2), (0, 5), (2, 7), (8, 7), (10, 9), (10, 12), (8, 14), (2, 14), (0, 12)]],
    "V": [[(0, 0), (5, 14), (10, 0)]],
    "W": [[(0, 0), (2.5, 14), (5, 5), (7.5, 14), (10, 0)]],
    "h": [[(0, 0), (0, 14)], [(0, 7), (3, 5), (7, 5), (9, 7), (9, 14)]],
    "k": [[(0, 0), (0, 14)], [(8, 5), (0, 10)], [(3, 8), (9, 14)]],
    "m": [[(0, 14), (0, 5)], [(0, 7), (2, 5), (4, 5), (5, 7), (5, 14)], [(5, 7), (7, 5), (9, 5), (10, 7), (10, 14)]],
    "r": [[(0, 14), (0, 5)], [(0, 8), (3, 5), (7, 5)]],
    "t": [[(3, 1), (3, 12), (5, 14), (8, 14)], [(0, 5), (7, 5)]],
    "μ": [[(0, 5), (0, 18)], [(0, 10), (2, 14), (6, 14), (8, 11)], [(8, 5), (8, 14)]],
    "ρ": [[(0, 18), (0, 8), (2, 5), (6, 5), (8, 7), (8, 12), (6, 14), (2, 14), (0, 12)]],
    "Ω": [[(0, 14), (3, 14), (3, 12), (0, 9), (0, 4), (3, 0), (7, 0), (10, 4), (10, 9), (7, 12), (7, 14), (10, 14)]],
    "=": [[(1, 5), (9, 5)], [(1, 9), (9, 9)]],
    "+": [[(5, 3), (5, 11)], [(1, 7), (9, 7)]],
    "-": [[(1, 7), (9, 7)]],
    "×": [[(2, 3), (8, 11)], [(8, 3), (2, 11)]],
    "÷": [[(1, 7), (9, 7)], ("dot", 5, 3.2), ("dot", 5, 10.8)],
    "/": [[(8, 0), (2, 14)]],
    ":": [("dot", 2, 4.5), ("dot", 2, 11.5)],
    ".": [("dot", 1.2, 13.3)],
    "(": [[(4, 0), (1, 4), (1, 10), (4, 14)]],
    ")": [[(0, 0), (3, 4), (3, 10), (0, 14)]],
    "[": [[(4, 0), (1, 0), (1, 14), (4, 14)]],
    "]": [[(0, 0), (3, 0), (3, 14), (0, 14)]],
    "≒": [[(1, 6), (9, 6)], [(1, 10), (9, 10)], ("dot", 2, 2.4), ("dot", 8, 13.6)],
    "→": [[(0, 7), (10, 7)], [(6, 3), (10, 7), (6, 11)]],
    "↑": [[(5, 14), (5, 0)], [(1, 4), (5, 0), (9, 4)]],
    "↓": [[(5, 0), (5, 14)], [(1, 10), (5, 14), (9, 10)]],
    "?": [[(1, 3), (3, 0), (7, 0), (9, 2), (9, 5), (5, 8), (5, 10)], ("dot", 5, 13.4)],
    "℃": [("ring", 1.8, 2, 1.8), [(13, 2), (11, 0), (7, 0), (5, 2), (5, 12), (7, 14), (11, 14), (13, 12)]],
    " ": [],
}
G["−"] = G["-"]

ADV = {
    "1": 8, "I": 10, ".": 3, ":": 4, "(": 5, ")": 5, "[": 5, "]": 5, " ": 5,
    "h": 9, "k": 9, "m": 10, "r": 7, "t": 8, "μ": 9, "ρ": 9, "℃": 14, "?": 9,
}
SPACING = 2.4  # 字間（グリフ単位）


def _layout(s):
    """文字列を (文字, 左端, 大きさの倍率, 縦ずれ) の並びにする。
    "_x" は x を下付き、"²" は上付きの 2。"""
    items = []
    x = 0.0
    i = 0
    while i < len(s):
        ch = s[i]
        if ch == "_" and i + 1 < len(s):
            sub = s[i + 1]
            sc = 0.62
            items.append((sub, x, sc, 0.55))
            x += ADV.get(sub, 10) * sc + SPACING * 0.6
            i += 2
            continue
        if ch == "²":
            sc = 0.6
            items.append(("2", x, sc, -0.12))
            x += ADV.get("2", 10) * sc + SPACING * 0.6
            i += 1
            continue
        if ch not in G:
            raise ValueError(f"グリフがない文字: {ch!r}（{s!r}）")
        items.append((ch, x, 1.0, 0.0))
        x += ADV.get(ch, 10) + SPACING
        i += 1
    return items, max(0.0, x - SPACING)


def text_width(s, size):
    return _layout(s)[1] * size / 14


def _glyph(ch, x, top, size, color, sw):
    u = size / 14
    out = []
    for stroke in G[ch]:
        if stroke and stroke[0] == "dot":
            _, px, py = stroke
            out.append(f'<circle cx="{x + px * u:.1f}" cy="{top + py * u:.1f}" r="{sw * 0.8:.2f}" fill="{color}"/>')
        elif stroke and stroke[0] == "ring":
            _, px, py, r = stroke
            out.append(f'<circle cx="{x + px * u:.1f}" cy="{top + py * u:.1f}" r="{r * u:.2f}" fill="none" '
                       f'stroke="{color}" stroke-width="{sw * 0.8:.2f}"/>')
        else:
            pts = " ".join(f"{x + px * u:.1f},{top + py * u:.1f}" for px, py in stroke)
            out.append(f'<polyline points="{pts}" fill="none" stroke="{color}" stroke-width="{sw:.2f}" '
                       f'stroke-linecap="round" stroke-linejoin="round"/>')
    return out


def text(s, x, y, size=14, color=INK, anchor="middle", bold=1.0):
    """s を描く。y は大文字の縦の中央。"""
    items, wu = _layout(s)
    u = size / 14
    width = wu * u
    x0 = x - width / 2 if anchor == "middle" else (x - width if anchor == "end" else x)
    top = y - size / 2
    sw = max(1.4, size * 0.13 * bold)
    out = []
    for ch, dx, sc, dy in items:
        out += _glyph(ch, x0 + dx * u, top + dy * size, size * sc, color, max(1.2, sw * (0.85 if sc < 1 else 1.0)))
    return "\n".join(out)


def formula(parts, x, y, size=16, anchor="middle", bold=1.0):
    """色つきの式。parts は (文字列, 色) の並び。"""
    total = sum(text_width(p, size) for p, _ in parts) + (len(parts) - 1) * SPACING * size / 14
    x0 = x - total / 2 if anchor == "middle" else (x - total if anchor == "end" else x)
    out = []
    for p, c in parts:
        out.append(text(p, x0, y, size, c, "start", bold))
        x0 += text_width(p, size) + SPACING * size / 14
    return "\n".join(out)


# ---------------------------------------------------------------------------
# 図形
# ---------------------------------------------------------------------------
def line(x1, y1, x2, y2, color=INK, w=3, dash=None):
    d = f' stroke-dasharray="{dash}"' if dash else ""
    return (f'<line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}" stroke="{color}" '
            f'stroke-width="{w}" stroke-linecap="round"{d}/>')


def poly(points, color=INK, w=3, fill="none", close=False, dash=None):
    pts = " ".join(f"{x:.1f},{y:.1f}" for x, y in points)
    tag = "polygon" if close else "polyline"
    d = f' stroke-dasharray="{dash}"' if dash else ""
    return (f'<{tag} points="{pts}" fill="{fill}" stroke="{color}" stroke-width="{w}" '
            f'stroke-linecap="round" stroke-linejoin="round"{d}/>')


def rect(x, y, w, h, fill=WHITE, stroke=INK, sw=3, rx=4, dash=None):
    d = f' stroke-dasharray="{dash}"' if dash else ""
    return (f'<rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" rx="{rx}" fill="{fill}" '
            f'stroke="{stroke}" stroke-width="{sw}"{d}/>')


def circle(cx, cy, r, fill=WHITE, stroke=INK, sw=3, dash=None):
    d = f' stroke-dasharray="{dash}"' if dash else ""
    return f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="{r:.1f}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"{d}/>'


def ellipse(cx, cy, rx, ry, fill=WHITE, stroke=INK, sw=3):
    return (f'<ellipse cx="{cx:.1f}" cy="{cy:.1f}" rx="{rx:.1f}" ry="{ry:.1f}" fill="{fill}" '
            f'stroke="{stroke}" stroke-width="{sw}"/>')


def dot(x, y, r=4.5, color=INK):
    return f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r}" fill="{color}"/>'


def arrow(x1, y1, x2, y2, color=BLUE, w=3, head=10):
    """(x1,y1) から (x2,y2) への矢印。"""
    ang = math.atan2(y2 - y1, x2 - x1)
    bx, by = x2 - math.cos(ang) * head * 0.8, y2 - math.sin(ang) * head * 0.8
    left = (x2 - math.cos(ang - 0.45) * head, y2 - math.sin(ang - 0.45) * head)
    right = (x2 - math.cos(ang + 0.45) * head, y2 - math.sin(ang + 0.45) * head)
    return line(x1, y1, bx, by, color, w) + poly([left, (x2, y2), right], color, 1, fill=color, close=True)


def darrow(x1, y1, x2, y2, color=INK, w=2, head=8):
    """両矢印（寸法線）。"""
    ang = math.atan2(y2 - y1, x2 - x1)

    def tip(tx, ty, a):
        return poly([(tx - math.cos(a - 0.45) * head, ty - math.sin(a - 0.45) * head), (tx, ty),
                     (tx - math.cos(a + 0.45) * head, ty - math.sin(a + 0.45) * head)], color, 1, fill=color, close=True)
    return line(x1, y1, x2, y2, color, w) + tip(x2, y2, ang) + tip(x1, y1, ang + math.pi)


def flow(x, y, direction, color=BLUE, s=9):
    """電線の上に置く電流の向き（塗りの三角）。direction: r / l / u / d"""
    pts = {
        "r": [(x - s * 0.7, y - s * 0.7), (x + s * 0.7, y), (x - s * 0.7, y + s * 0.7)],
        "l": [(x + s * 0.7, y - s * 0.7), (x - s * 0.7, y), (x + s * 0.7, y + s * 0.7)],
        "d": [(x - s * 0.7, y - s * 0.7), (x, y + s * 0.7), (x + s * 0.7, y - s * 0.7)],
        "u": [(x - s * 0.7, y + s * 0.7), (x, y - s * 0.7), (x + s * 0.7, y + s * 0.7)],
    }[direction]
    return poly(pts, color, 1, fill=color, close=True)


def res(cx, cy, vertical=False, length=50, thick=20, fill=WHITE, stroke=INK, label=None, lsize=11, lcolor=INK):
    """抵抗（JIS の四角）。label は箱の中に書く。"""
    w, h = (thick, length) if vertical else (length, thick)
    out = rect(cx - w / 2, cy - h / 2, w, h, fill, stroke, 3, 3)
    if label:
        out += text(label, cx, cy, lsize, lcolor)
    return out


def res_on(x1, y1, x2, y2, length=46, thick=18, fill=WHITE, color=INK):
    """(x1,y1)-(x2,y2) の線の途中に置く斜めの抵抗。両端の線も描く。"""
    mx, my = (x1 + x2) / 2, (y1 + y2) / 2
    ang = math.atan2(y2 - y1, x2 - x1)
    ux, uy = math.cos(ang), math.sin(ang)
    nx, ny = -uy, ux
    hl, ht = length / 2, thick / 2
    corners = [(mx - ux * hl - nx * ht, my - uy * hl - ny * ht), (mx + ux * hl - nx * ht, my + uy * hl - ny * ht),
               (mx + ux * hl + nx * ht, my + uy * hl + ny * ht), (mx - ux * hl + nx * ht, my - uy * hl + ny * ht)]
    return (line(x1, y1, mx - ux * hl, my - uy * hl, color) + line(mx + ux * hl, my + uy * hl, x2, y2, color)
            + poly(corners, color, 3, fill=fill, close=True))


def battery(cx, cy, vertical=True, label=None, lpos="right"):
    """直流電源（長い線が +、短い太い線が −）。縦なら上が +。
    線は (cx, cy-6) と (cx, cy+6) につなぐ（横なら左右）。"""
    out = []
    if vertical:
        out.append(rect(cx - 20, cy - 7, 40, 14, WHITE, WHITE, 0, 0))
        out.append(line(cx - 17, cy - 6, cx + 17, cy - 6, INK, 3))
        out.append(line(cx - 9, cy + 6, cx + 9, cy + 6, INK, 6))
        out.append(text("+", cx + 25, cy - 13, 10, INK))
        if label:
            if lpos == "left":
                out.append(text(label, cx - 26, cy, 13, RED, "end"))
            else:
                out.append(text(label, cx + 26, cy + 6, 13, RED, "start"))
    else:
        out.append(rect(cx - 7, cy - 20, 14, 40, WHITE, WHITE, 0, 0))
        out.append(line(cx - 6, cy - 17, cx - 6, cy + 17, INK, 3))
        out.append(line(cx + 6, cy - 9, cx + 6, cy + 9, INK, 6))
        out.append(text("+", cx - 14, cy - 22, 10, INK))
        if label:
            out.append(text(label, cx, cy + 32, 13, RED))
    return "\n".join(out)


def ac(cx, cy, r=17, label=None):
    """交流電源（○に正弦波）。"""
    out = circle(cx, cy, r) + (f'<path d="M{cx - r * 0.62:.1f} {cy:.1f} q {r * 0.31:.1f} {-r * 0.7:.1f} {r * 0.62:.1f} 0 '
                              f't {r * 0.62:.1f} 0" fill="none" stroke="{INK}" stroke-width="2.5"/>')
    if label:
        out += text(label, cx + r + 8, cy, 13, RED, "start")
    return out


def lamp(cx, cy, r=15):
    s = r * 0.62
    return (circle(cx, cy, r) + line(cx - s, cy - s, cx + s, cy + s, INK, 3)
            + line(cx - s, cy + s, cx + s, cy - s, INK, 3))


def outlet(cx, cy, r=15):
    return (circle(cx, cy, r) + line(cx - 4.5, cy - 7, cx - 4.5, cy + 7, INK, 3)
            + line(cx + 4.5, cy - 7, cx + 4.5, cy + 7, INK, 3))


def heat(cx, top, n=3, spacing=12, height=22, color=RED):
    """上へ立ちのぼる熱の波。"""
    out = []
    for i in range(n):
        x = cx + (i - (n - 1) / 2) * spacing
        out.append(f'<path d="M{x:.1f} {top:.1f} q 5 {-height / 4:.1f} 0 {-height / 2:.1f} q -5 {-height / 4:.1f} 0 {-height / 2:.1f}" '
                   f'fill="none" stroke="{color}" stroke-width="2.5" stroke-linecap="round"/>')
    return "\n".join(out)


def heat_down(cx, bottom, n=3, spacing=12, height=22, color=RED):
    out = []
    for i in range(n):
        x = cx + (i - (n - 1) / 2) * spacing
        out.append(f'<path d="M{x:.1f} {bottom:.1f} q 5 {height / 4:.1f} 0 {height / 2:.1f} q -5 {height / 4:.1f} 0 {height / 2:.1f}" '
                   f'fill="none" stroke="{color}" stroke-width="2.5" stroke-linecap="round"/>')
    return "\n".join(out)


def span_h(x1, x2, y, label, color=RED, size=12, above=True, tick=6):
    """横の区間（両端に目盛り）と、その上か下のラベル。"""
    out = [line(x1, y, x2, y, color, 2), line(x1, y - tick, x1, y + tick, color, 2), line(x2, y - tick, x2, y + tick, color, 2)]
    ly = y - size * 0.95 if above else y + size * 0.95
    out.append(text(label, (x1 + x2) / 2, ly, size, color))
    return "\n".join(out)


def span_v(x, y1, y2, label, color=RED, size=12, right=True, tick=6):
    out = [line(x, y1, x, y2, color, 2), line(x - tick, y1, x + tick, y1, color, 2), line(x - tick, y2, x + tick, y2, color, 2)]
    lx = x + 7 if right else x - 7
    out.append(text(label, lx, (y1 + y2) / 2, size, color, "start" if right else "end"))
    return "\n".join(out)


def pill(cx, cy, label, color, fill, size=12, pad=7):
    w = text_width(label, size) + pad * 2
    return rect(cx - w / 2, cy - size * 0.95, w, size * 1.9, fill, color, 2, size * 0.95) + text(label, cx, cy, size, color)


def circled(n, cx, cy, r=14):
    return circle(cx, cy, r, YEL_L, YEL, 2.5) + text(str(n), cx, cy, 14, YEL, bold=1.1)


def svg(body, w=W, h=H):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}">\n'
            f'<rect x="0" y="0" width="{w}" height="{h}" rx="14" fill="{WHITE}"/>\n{body}\n</svg>\n')


def wires(*segments, color=INK, w=3):
    return "\n".join(poly(seg, color, w) for seg in segments)


figures = {}

# ===========================================================================
# F01 接頭語
# ===========================================================================
def f01_prefix_ladder():
    out = []
    boxes = [("k", "1000"), ("V A W", "1"), ("m", "1/1000"), ("μ", "1/1000000")]
    xs = [12, 116, 220, 324]
    bw, top, bh = 84, 74, 70
    for i, (pre, val) in enumerate(boxes):
        x = xs[i]
        base = i == 1
        out.append(rect(x, top, bw, bh, LIGHT if base else WHITE, INK, 3, 10))
        out.append(text(pre, x + bw / 2, top + 22, 15 if base else 26, INK if base else YEL, bold=1.1))
        out.append(text(val, x + bw / 2, top + 55, 9 if len(val) > 6 else 11, GRAY))
    for i in range(3):
        x1 = xs[i] + bw / 2 + 8
        x2 = xs[i + 1] + bw / 2 - 8
        mid = (x1 + x2) / 2
        # 上: 小さい単位へ進む = ×1000（青）
        out.append(f'<path d="M{x1:.1f} {top - 6} Q {mid:.1f} {top - 44} {x2:.1f} {top - 6}" fill="none" stroke="{BLUE}" stroke-width="3"/>')
        out.append(arrow(x2 - 9, top - 17, x2, top - 6, BLUE, 3, 10))
        out.append(text("×1000", mid, top - 40, 11, BLUE))
        # 下: 大きい単位へ戻る = ÷1000（赤）
        y0 = top + bh + 6
        out.append(f'<path d="M{x2:.1f} {y0} Q {mid:.1f} {y0 + 38} {x1:.1f} {y0}" fill="none" stroke="{RED}" stroke-width="3"/>')
        out.append(arrow(x1 + 9, y0 + 11, x1, y0, RED, 3, 10))
        out.append(text("÷1000", mid, y0 + 34, 11, RED))
    out.append(text("6.6kV = 6600V", 110, 226, 11, GRAY))
    out.append(text("0.5A = 500mA", 316, 226, 11, GRAY))
    return svg("\n".join(out))


figures["F01_prefix_ladder"] = f01_prefix_ladder()


# ===========================================================================
# F02 電流・電圧・抵抗
# ===========================================================================
def f02_water_analogy():
    out = []
    # 太い管 = 大電流
    out.append(rect(40, 42, 270, 56, BLUE_L, BLUE, 3, 10))
    for x in (90, 170, 250):
        for dy in (-14, 0, 14):
            out.append(arrow(x - 22, 70 + dy, x + 22, 70 + dy, BLUE, 3.5, 10))
    out.append(text("10A", 360, 70, 24, BLUE, bold=1.1))
    # 細い管 = 小電流
    out.append(rect(40, 160, 270, 18, BLUE_L, BLUE, 3, 6))
    out.append(arrow(150, 169, 200, 169, BLUE, 2.5, 8))
    out.append(text("1A", 360, 169, 16, BLUE))
    out.append(text("I", 22, 70, 18, BLUE, bold=1.1))
    out.append(text("I", 22, 169, 12, BLUE))
    return svg("\n".join(out))


figures["F02_water_analogy"] = f02_water_analogy()


def f02_voltage_height():
    out = []
    ground = 205
    for cx, top, label, big in ((140, 150, "1.5V", False), (330, 42, "100V", True)):
        # 高いタンク
        tx = cx - 62
        out.append(line(tx + 8, top + 30, tx + 8, ground, GRAY, 3))
        out.append(line(tx + 52, top + 30, tx + 52, ground, GRAY, 3))
        out.append(rect(tx, top, 60, 30, BLUE_L, BLUE, 3, 4))
        # 低いタンク
        lx = cx + 14
        out.append(rect(lx, ground - 24, 56, 24, BLUE_L, BLUE, 3, 4))
        # 管と流れ
        out.append(poly([(tx + 60, top + 22), (lx + 28, top + 22), (lx + 28, ground - 24)], BLUE, 5))
        out.append(flow(lx + 28, (top + 22 + ground - 24) / 2, "d", BLUE, 10))
        # 高さの差
        dx = cx - 82
        out.append(darrow(dx, top + 4, dx, ground - 20, RED, 2.5, 8))
        out.append(text(label, dx - 6, (top + ground - 16) / 2, 15 if big else 13, RED, "end", 1.1 if big else 1.0))
    out.append(line(20, ground, 400, ground, INK, 3))
    return svg("\n".join(out))


figures["F02_voltage_height"] = f02_voltage_height()


def f02_resistance_load_vs_wire():
    out = []
    out.append(wires([(50, 103), (50, 55), (330, 55), (330, 80)], [(330, 160), (330, 185), (50, 185), (50, 137)]))
    out.append(ac(50, 120, 17))
    # 電線はほぼ 0Ω
    out.append(text("≒0Ω", 190, 38, 14, BLUE))
    out.append(text("≒0Ω", 190, 207, 14, BLUE))
    # 負荷（電熱器）は抵抗が大きい
    out.append(res(330, 120, True, 80, 34, ORANGE_L, ORANGE))
    out.append(text("R", 330, 120, 18, ORANGE, bold=1.1))
    out.append(heat(372, 142, 3, 11, 44, RED))
    out.append(flow(120, 55, "r", BLUE))
    out.append(text("I", 120, 36, 12, BLUE))
    return svg("\n".join(out))


figures["F02_resistance_load_vs_wire"] = f02_resistance_load_vs_wire()


def f02_ohm_triangle():
    out = []
    ax, ay, lx, rx, by = 125, 28, 32, 218, 206
    out.append(poly([(ax, ay), (lx, by), (rx, by)], INK, 3.5, fill=LIGHT, close=True))
    t = (130 - ay) / (by - ay)
    out.append(line(ax - (ax - lx) * t, 130, ax + (rx - ax) * t, 130, INK, 3))
    out.append(line(ax, 130, ax, by, INK, 3))
    out.append(text("V", ax, 92, 34, RED, bold=1.1))
    out.append(text("I", 92, 168, 30, BLUE, bold=1.1))
    out.append(text("R", 158, 168, 30, INK, bold=1.1))
    rows = [
        [("V", RED), ("=", INK), ("I", BLUE), ("×", INK), ("R", INK)],
        [("I", BLUE), ("=", INK), ("V", RED), ("÷", INK), ("R", INK)],
        [("R", INK), ("=", INK), ("V", RED), ("÷", INK), ("I", BLUE)],
    ]
    for i, parts in enumerate(rows):
        out.append(formula(parts, 322, 70 + i * 50, 20))
    return svg("\n".join(out))


figures["F02_ohm_triangle"] = f02_ohm_triangle()


def f02_wire_drop_intro():
    out = []
    out.append(wires([(60, 114), (60, 60), (143, 60)], [(199, 60), (330, 60), (330, 85)],
                     [(330, 155), (330, 190), (60, 190), (60, 126)]))
    out.append(battery(60, 120, True, "100V"))
    out.append(res(171, 60, False, 56, 18, LIGHT, INK))
    out.append(text("0.2Ω", 171, 84, 11, INK))
    out.append(span_h(143, 199, 34, "2V", RED, 13))
    out.append(res(330, 120, True, 70, 26))
    out.append(span_v(362, 85, 155, "98V", RED, 13))
    out.append(flow(105, 60, "r", BLUE))
    out.append(text("10A", 105, 40, 12, BLUE))
    return svg("\n".join(out))


figures["F02_wire_drop_intro"] = f02_wire_drop_intro()


# ===========================================================================
# F03 直列回路
# ===========================================================================
def series_frame(xs, top=60, bottom=180, left=50, right=380, battery_label=None):
    """左に電池、上の線に抵抗を並べた直列回路の枠。xs は抵抗の中心 x。"""
    out = []
    pts = [(left, (top + bottom) / 2 - 6), (left, top)]
    segs = []
    x = left
    cur = [(left, (top + bottom) / 2 - 6), (left, top)]
    for cx in xs:
        cur.append((cx - 25, top))
        segs.append(cur)
        cur = [(cx + 25, top)]
    cur += [(right, top), (right, bottom), (left, bottom), (left, (top + bottom) / 2 + 6)]
    segs.append(cur)
    out.append(wires(*segs))
    out.append(battery(left, (top + bottom) / 2, True, battery_label))
    return "\n".join(out)


def f03_series_basic():
    out = [series_frame([140, 230, 320])]
    for cx, name in ((140, "R_1"), (230, "R_2"), (320, "R_3")):
        out.append(res(cx, 60))
        out.append(text(name, cx, 34, 14, INK))
    out.append(flow(88, 60, "r"))
    out.append(flow(380, 120, "d"))
    out.append(flow(215, 180, "l"))
    out.append(text("I", 380 + 14, 120, 14, BLUE, "start"))
    out.append(text("I", 215, 202, 14, BLUE))
    return svg("\n".join(out))


figures["F03_series_basic"] = f03_series_basic()


def f03_series_same_current():
    out = [series_frame([160, 280])]
    out.append(res(160, 60, label="R_1", lsize=10))
    out.append(res(280, 60, label="R_2", lsize=10))
    for x in (95, 220, 335):
        out.append(flow(x, 60, "r", BLUE, 11))
        out.append(pill(x, 30, "2A", BLUE, BLUE_L, 13))
    out.append(flow(215, 180, "l", BLUE, 11))
    out.append(pill(215, 208, "2A", BLUE, BLUE_L, 13))
    return svg("\n".join(out))


figures["F03_series_same_current"] = f03_series_same_current()


def f03_series_voltage_divide():
    out = [series_frame([165, 285], top=62, bottom=196, battery_label="12V")]
    out.append(res(165, 62, label="2Ω", lsize=11))
    out.append(res(285, 62, label="4Ω", lsize=11))
    out.append(span_h(140, 190, 98, "4V", RED, 13, above=False))
    out.append(span_h(260, 310, 98, "8V", RED, 13, above=False))
    out.append(span_h(140, 310, 150, "12V", RED, 14, above=False))
    out.append(flow(380, 129, "d", BLUE, 10))
    out.append(text("2A", 394, 129, 12, BLUE, "start"))
    return svg("\n".join(out))


figures["F03_series_voltage_divide"] = f03_series_voltage_divide()


def f03_series_combined():
    out = []
    y = 100
    out.append(wires([(28, y), (68, y)], [(118, y), (148, y)], [(198, y), (232, y)]))
    out.append(res(93, y, label="3Ω", lsize=11))
    out.append(res(173, y, label="5Ω", lsize=11))
    out.append(dot(28, y, 5))
    out.append(dot(232, y, 5))
    out.append(text("=", 262, y, 26, INK, bold=1.2))
    out.append(wires([(292, y), (320, y)], [(380, y), (400, y)]))
    out.append(res(350, y, length=60, thick=24, fill=YEL_L, stroke=YEL, label="8Ω", lsize=13, lcolor=INK))
    out.append(dot(292, y, 5))
    out.append(dot(400, y, 5))
    out.append(formula([("3Ω", INK), ("+", GRAY), ("5Ω", INK), ("=", GRAY), ("8Ω", YEL)], 210, 180, 18))
    return svg("\n".join(out))


figures["F03_series_combined"] = f03_series_combined()


def f03_series_procedure():
    out = []
    rows = [
        [("R", INK), ("=", GRAY), ("R_1", INK), ("+", GRAY), ("R_2", INK)],
        [("I", BLUE), ("=", GRAY), ("V", RED), ("÷", GRAY), ("R", INK)],
        [("V_1", RED), ("=", GRAY), ("I", BLUE), ("×", GRAY), ("R_1", INK)],
        [("V_1", RED), ("+", GRAY), ("V_2", RED), ("=", GRAY), ("V", RED)],
    ]
    for i, parts in enumerate(rows):
        y = 36 + i * 56
        out.append(circled(i + 1, 50, y))
        if i < 3:
            out.append(arrow(50, y + 17, 50, y + 39, GRAY, 2.5, 8))
        out.append(rect(84, y - 20, 300, 40, LIGHT if i < 3 else GREEN_L, LINE if i < 3 else GREEN, 2, 10))
        out.append(formula(parts, 234, y, 19))
    out.append(poly([(396, 214), (402, 221), (412, 206)], GREEN, 3.5))
    return svg("\n".join(out))


figures["F03_series_procedure"] = f03_series_procedure()


# ===========================================================================
# F04 並列回路
# ===========================================================================
def parallel_frame(bx=(220, 330), top=55, bottom=190, left=50, series=None, battery_label=None):
    """左に電池、右に縦の枝を並べた並列回路の枠。series は上の線に入れる抵抗の中心 x。"""
    out = []
    mid = (top + bottom) / 2
    last = bx[-1]
    if series:
        out.append(wires([(left, mid - 6), (left, top), (series - 25, top)], [(series + 25, top), (last, top)]))
    else:
        out.append(wires([(left, mid - 6), (left, top), (last, top)]))
    out.append(wires([(last, bottom), (left, bottom), (left, mid + 6)]))
    for x in bx:
        out.append(wires([(x, top), (x, mid - 28)], [(x, mid + 28), (x, bottom)]))
    for x in bx[:-1]:
        out.append(dot(x, top))
        out.append(dot(x, bottom))
    out.append(battery(left, mid, True, battery_label))
    return "\n".join(out)


def f04_parallel_basic():
    out = [parallel_frame()]
    out.append(res(220, 122.5, True, 56, 28, label="R_1", lsize=10))
    out.append(res(330, 122.5, True, 56, 28, label="R_2", lsize=10))
    out.append(flow(130, 55, "r", BLUE, 11))
    out.append(text("I", 130, 34, 14, BLUE))
    out.append(flow(220, 80, "d", BLUE, 10))
    out.append(text("I_1", 200, 80, 13, BLUE, "end"))
    out.append(flow(330, 80, "d", BLUE, 10))
    out.append(text("I_2", 310, 80, 13, BLUE, "end"))
    out.append(flow(130, 190, "l", BLUE, 11))
    out.append(text("I", 130, 211, 14, BLUE))
    return svg("\n".join(out))


figures["F04_parallel_basic"] = f04_parallel_basic()


def f04_parallel_same_voltage():
    out = [parallel_frame(battery_label="100V")]
    out.append(res(220, 122.5, True, 56, 28, label="R_1", lsize=10))
    out.append(res(330, 122.5, True, 56, 28, label="R_2", lsize=10))
    out.append(span_v(252, 94, 151, "100V", RED, 12))
    out.append(span_v(362, 94, 151, "100V", RED, 12))
    return svg("\n".join(out))


figures["F04_parallel_same_voltage"] = f04_parallel_same_voltage()


def f04_parallel_current_split():
    out = [parallel_frame(battery_label="100V")]
    out.append(res(220, 122.5, True, 56, 40, label="20Ω", lsize=10))
    out.append(res(330, 122.5, True, 56, 40, label="50Ω", lsize=10))
    out.append(arrow(96, 36, 160, 36, BLUE, 6, 14))
    out.append(text("7A", 128, 18, 14, BLUE, bold=1.1))
    out.append(arrow(252, 70, 252, 100, BLUE, 5, 12))
    out.append(text("5A", 262, 85, 14, BLUE, "start", 1.1))
    out.append(arrow(362, 72, 362, 98, BLUE, 2.5, 9))
    out.append(text("2A", 372, 85, 12, BLUE, "start"))
    out.append(formula([("5A", BLUE), ("+", GRAY), ("2A", BLUE), ("=", GRAY), ("7A", BLUE)], 275, 214, 12))
    return svg("\n".join(out))


figures["F04_parallel_current_split"] = f04_parallel_current_split()


def f04_parallel_combined():
    out = []
    cy, y1, y2 = 90, 58, 122
    out.append(wires([(28, cy), (62, cy)], [(62, y1), (62, y2)], [(62, y1), (98, y1)], [(62, y2), (98, y2)],
                     [(148, y1), (184, y1)], [(148, y2), (184, y2)], [(184, y1), (184, y2)], [(184, cy), (214, cy)]))
    out.append(res(123, y1, label="10Ω", lsize=10))
    out.append(res(123, y2, label="30Ω", lsize=10))
    for x in (62, 184):
        out.append(dot(x, cy))
    out.append(dot(28, cy, 5))
    out.append(dot(214, cy, 5))
    out.append(text("=", 244, cy, 26, INK, bold=1.2))
    out.append(wires([(274, cy), (302, cy)], [(366, cy), (394, cy)]))
    out.append(res(334, cy, length=64, thick=24, fill=YEL_L, stroke=YEL, label="7.5Ω", lsize=12))
    out.append(dot(274, cy, 5))
    out.append(dot(394, cy, 5))
    # 和分の積
    out.append(text("R =", 150, 196, 18, INK, "end"))
    out.append(text("R_1×R_2", 214, 178, 16, INK))
    out.append(line(166, 196, 262, 196, INK, 2.5))
    out.append(text("R_1+R_2", 214, 214, 16, INK))
    return svg("\n".join(out))


figures["F04_parallel_combined"] = f04_parallel_combined()


def f04_house_wiring():
    out = []
    top, bottom = 50, 196
    xs = (190, 276, 362)
    out.append(wires([(40, 106), (40, top), (86, top)], [(116, top), (362, top)],
                     [(362, bottom), (40, bottom), (40, 140)]))
    out.append(ac(40, 123, 17))
    out.append(text("100V", 40, 222, 12, RED))
    # ブレーカー
    out.append(rect(86, top - 13, 30, 26, WHITE, INK, 3, 4))
    out.append(text("B", 101, top, 12, INK))
    for x in xs:
        out.append(wires([(x, top), (x, 105)], [(x, 141), (x, bottom)]))
    for x in xs[:-1]:
        out.append(dot(x, top))
        out.append(dot(x, bottom))
    out.append(lamp(190, 123, 17))
    out.append(outlet(276, 123, 17))
    out.append(res(362, 123, True, 36, 26, ORANGE_L, ORANGE))
    out.append(heat(394, 138, 2, 10, 30, RED))
    for x in xs:
        out.append(text("100V", x - 22, 123, 10, RED, "end"))
    out.append(arrow(128, 30, 172, 30, BLUE, 5, 12))
    out.append(text("I", 150, 14, 13, BLUE, bold=1.1))
    return svg("\n".join(out))


figures["F04_house_wiring"] = f04_house_wiring()


# ===========================================================================
# F05 直並列
# ===========================================================================
def mixed_circuit():
    out = [parallel_frame(bx=(250, 350), top=55, bottom=195, series=150, battery_label="12V")]
    out.append(res(150, 55, label="4Ω", lsize=11))
    out.append(res(250, 125, True, 56, 30, label="6Ω", lsize=11))
    out.append(res(350, 125, True, 56, 30, label="3Ω", lsize=11))
    return "\n".join(out)


def f05_mixed_basic():
    out = [mixed_circuit()]
    out.append(rect(212, 82, 176, 88, "none", YEL, 2.5, 12, dash="7,5"))
    out.append(pill(300, 125, "2Ω", YEL, YEL_L, 14))
    out.append(flow(95, 55, "r", BLUE, 11))
    out.append(text("2A", 95, 34, 13, BLUE))
    return svg("\n".join(out))


figures["F05_mixed_basic"] = f05_mixed_basic()


def f05_mixed_branch_current():
    out = [mixed_circuit()]
    out.append(span_h(125, 175, 30, "8V", RED, 12))
    out.append(flow(88, 55, "r", BLUE, 11))
    out.append(text("2A", 88, 34, 13, BLUE))
    out.append(flow(250, 78, "d", BLUE, 10))
    out.append(text("≒0.67A", 202, 125, 11, BLUE))
    out.append(flow(350, 78, "d", BLUE, 10))
    out.append(text("≒1.33A", 300, 125, 11, BLUE))
    out.append(span_v(377, 97, 153, "4V", RED, 11))
    return svg("\n".join(out))


figures["F05_mixed_branch_current"] = f05_mixed_branch_current()


def f05_spot_the_topology():
    out = []
    # 左: 見慣れない描き方
    P, Q = (30, 125), (160, 125)
    out.append(poly([P, (72, 125)], BLUE, 3))
    out.append(poly([(118, 125), Q], RED, 3))
    out.append(res(95, 125, length=46, thick=18))
    out.append(text("R_1", 95, 100, 12, INK))
    out.append(poly([P, (30, 40), (186, 40), (186, 82)], BLUE, 3))
    out.append(poly([(186, 128), (186, 206), (160, 206), Q], RED, 3))
    out.append(res(186, 105, True, 46, 18))
    out.append(text("R_2", 200, 105, 12, INK, "start"))
    out.append(dot(*P, 6, BLUE))
    out.append(dot(*Q, 6, RED))
    # 矢印
    out.append(arrow(222, 125, 250, 125, GRAY, 3, 10))
    # 右: 描き直し
    P2, Q2 = (266, 125), (398, 125)
    out.append(poly([P2, (266, 78), (309, 78)], BLUE, 3))
    out.append(poly([P2, (266, 172), (309, 172)], BLUE, 3))
    out.append(poly([(355, 78), (398, 78), Q2], RED, 3))
    out.append(poly([(355, 172), (398, 172), Q2], RED, 3))
    out.append(res(332, 78, length=46, thick=18))
    out.append(res(332, 172, length=46, thick=18))
    out.append(text("R_1", 332, 56, 12, INK))
    out.append(text("R_2", 332, 196, 12, INK))
    out.append(dot(*P2, 6, BLUE))
    out.append(dot(*Q2, 6, RED))
    return svg("\n".join(out))


figures["F05_spot_the_topology"] = f05_spot_the_topology()


def f05_bridge():
    out = []
    L, T, R, B = (86, 112), (210, 38), (334, 112), (210, 186)
    out.append(res_on(*L, *T))
    out.append(res_on(*T, *R))
    out.append(res_on(*L, *B))
    out.append(res_on(*B, *R))
    for p in (L, T, R, B):
        out.append(dot(*p))
    # 橋と電流計
    out.append(line(210, 38, 210, 96, INK, 3))
    out.append(line(210, 128, 210, 186, INK, 3))
    out.append(circle(210, 112, 16))
    out.append(text("A", 210, 112, 13, INK))
    out.append(pill(250, 112, "0A", GREEN, GREEN_L, 12))
    # 電源
    out.append(wires([L, (40, 112), (40, 222), (196, 222)], [(224, 222), (380, 222), (380, 112), R]))
    out.append(battery(210, 222, False))
    out.append(text("R_1", 128, 60, 13, INK))
    out.append(text("R_2", 292, 60, 13, INK))
    out.append(text("R_3", 128, 166, 13, INK))
    out.append(text("R_4", 292, 166, 13, INK))
    out.append(formula([("R_1×R_4", INK), ("=", GREEN), ("R_2×R_3", INK)], 330, 22, 12))
    return svg("\n".join(out))


figures["F05_bridge"] = f05_bridge()


def f05_bridge_ratio():
    """セッション5：比で見るブリッジ。12V、上の道 2Ω・4Ω、下の道 4Ω・8Ω。橋の両端はどちらも 8V。"""
    out = []
    L, T, R, B = (110, 124), (230, 50), (350, 124), (230, 198)
    out.append(res_on(*L, *T))
    out.append(res_on(*T, *R))
    out.append(res_on(*L, *B))
    out.append(res_on(*B, *R))
    for p in (L, T, R, B):
        out.append(dot(*p))
    # 橋：電位差がないので消せる（点線）
    out.append(line(230, 50, 230, 198, GRAY, 2.5, dash="6,6"))
    out.append(pill(230, 124, "0A", GREEN, GREEN_L, 12))
    # 電源（左の縦線、+ が上）
    out.append(wires([L, (40, 124), (40, 171)], [(40, 183), (40, 238), (396, 238), (396, 124), R]))
    out.append(battery(40, 177, True, "12V", "right"))
    out.append(text("2Ω", 152, 70, 13, INK))
    out.append(text("4Ω", 308, 70, 13, INK))
    out.append(text("4Ω", 152, 180, 13, INK))
    out.append(text("8Ω", 308, 180, 13, INK))
    # 橋の両端の電圧
    out.append(pill(230, 22, "8V", RED, RED_L, 12))
    out.append(pill(230, 220, "8V", RED, RED_L, 12))
    out.append(formula([("R_1:R_2", INK), ("=", GREEN), ("R_3:R_4", INK)], 96, 24, 12))
    out.append(formula([("2:4", INK), ("=", GREEN), ("4:8", INK)], 348, 24, 13))
    return svg("\n".join(out), W, 256)


figures["F05_bridge_ratio"] = f05_bridge_ratio()


# ===========================================================================
# F06 電力・電力量・発熱
# ===========================================================================
def f06_power_basic():
    out = []
    x, y, w, h = 128, 34, 200, 132
    out.append(rect(x, y, w, h, ORANGE_L, ORANGE, 3, 6))
    out.append(text("P", x + w / 2, y + 48, 38, ORANGE, bold=1.2))
    out.append(formula([("=", GRAY), ("V", RED), ("×", GRAY), ("I", BLUE)], x + w / 2, y + 100, 20))
    out.append(darrow(x - 22, y, x - 22, y + h, RED, 2.5, 9))
    out.append(text("V", x - 34, y + h / 2, 22, RED, "end", 1.1))
    out.append(darrow(x, y + h + 22, x + w, y + h + 22, BLUE, 2.5, 9))
    out.append(text("I", x + w / 2, y + h + 44, 20, BLUE, bold=1.1))
    out.append(text("100V×12A", 375, 90, 11, GRAY))
    out.append(text("= 1200W", 375, 112, 11, ORANGE))
    return svg("\n".join(out))


figures["F06_power_basic"] = f06_power_basic()


def f06_three_formulas():
    out = []
    cards = [
        ([("P", ORANGE), ("=", GRAY), ("V", RED), ("×", GRAY), ("I", BLUE)], [("V", RED, RED_L), ("I", BLUE, BLUE_L)]),
        ([("P", ORANGE), ("=", GRAY), ("I", BLUE), ("²", ORANGE), ("×", GRAY), ("R", INK)], [("I", BLUE, BLUE_L), ("R", INK, LIGHT)]),
        ([("P", ORANGE), ("=", GRAY), ("V", RED), ("²", ORANGE), ("÷", GRAY), ("R", INK)], [("V", RED, RED_L), ("R", INK, LIGHT)]),
    ]
    for i, (parts, known) in enumerate(cards):
        cx = 72 + i * 138
        out.append(rect(cx - 62, 30, 124, 180, WHITE, LINE, 2.5, 14))
        out.append(formula(parts, cx, 70, 17))
        out.append(line(cx - 44, 104, cx + 44, 104, LINE, 2))
        for j, (ch, c, f) in enumerate(known):
            kx = cx - 30 + j * 60
            out.append(circle(kx, 150, 18, f, c, 2.5))
            out.append(text(ch, kx, 150, 17, c, bold=1.1))
        out.append(text("+", cx, 150, 14, GRAY))
    return svg("\n".join(out))


figures["F06_three_formulas"] = f06_three_formulas()


def f06_energy_vs_power():
    out = []
    base, left = 200, 44
    out.append(arrow(left, base + 8, left, 22, INK, 2.5, 9))
    out.append(arrow(left - 8, base, 404, base, INK, 2.5, 9))
    out.append(text("P", left - 14, 30, 14, ORANGE, "end"))
    out.append(text("t", 404, base + 18, 14, INK))
    # 1200W × 1/12h
    out.append(rect(62, 44, 30, base - 44, ORANGE_L, ORANGE, 3, 2))
    out.append(text("1200W", 77, 32, 11, ORANGE))
    out.append(text("1/12h", 77, base + 18, 11, INK))
    out.append(text("100Wh", 102, 120, 14, ORANGE, "start", 1.1))
    # 8W × 24h
    out.append(rect(190, base - 18, 196, 18, ORANGE_L, ORANGE, 3, 2))
    out.append(text("8W", 176, base - 9, 11, ORANGE, "end"))
    out.append(text("24h", 288, base + 18, 11, INK))
    out.append(text("192Wh", 288, base - 34, 14, ORANGE, bold=1.1))
    out.append(formula([("W", ORANGE), ("=", GRAY), ("P", ORANGE), ("×", GRAY), ("t", INK)], 300, 70, 20))
    return svg("\n".join(out))


figures["F06_energy_vs_power"] = f06_energy_vs_power()


def f06_joule_heat():
    out = []
    y = 104
    out.append(wires([(40, y), (150, y)], [(270, y), (380, y)]))
    out.append(dot(40, y, 5))
    out.append(dot(380, y, 5))
    out.append(res(210, y, length=120, thick=42, fill=ORANGE_L, stroke=ORANGE, label="R", lsize=20, lcolor=ORANGE))
    out.append(heat(210, y - 28, 5, 20, 46, RED))
    out.append(flow(96, y, "r", BLUE, 12))
    out.append(text("I", 96, y - 22, 16, BLUE, bold=1.1))
    out.append(formula([("Q", RED), ("=", GRAY), ("I", BLUE), ("²", ORANGE), ("×", GRAY), ("R", INK), ("×", GRAY),
                        ("t", INK), (" [J]", GRAY)], 210, 184, 22))
    return svg("\n".join(out))


figures["F06_joule_heat"] = f06_joule_heat()


def f06_wire_heating():
    out = []
    base = 206
    out.append(line(46, base, 380, base, INK, 3))
    bars = [(100, 100, "10A", "×1", COPPER_L, ORANGE), (205, 400, "20A", "×4", ORANGE_L, ORANGE), (310, 900, "30A", "×9", RED_L, RED)]
    for x, v, label, mult, fill, stroke in bars:
        h = v / 900 * 150
        out.append(rect(x - 30, base - h, 60, h, fill, stroke, 3, 3))
        out.append(text(str(v), x, base - h - 14, 13, stroke, bold=1.1))
        out.append(text(mult, x, base - h - 32, 11, RED))
        out.append(text(label, x, base + 18, 13, BLUE))
    out.append(line(46, 88, 360, 88, RED, 2.5, dash="8,6"))
    out.append(text("60℃", 368, 88, 12, RED, "start"))
    out.append(formula([("I", BLUE), ("²", ORANGE), ("×", GRAY), ("R", INK)], 90, 44, 16))
    return svg("\n".join(out))


figures["F06_wire_heating"] = f06_wire_heating()


# ===========================================================================
# F07 抵抗率と電線の抵抗
# ===========================================================================
def f07_length():
    out = []
    out.append(line(56, 70, 176, 70, COPPER, 12))
    out.append(text("1m", 116, 96, 12, GRAY))
    out.append(text("0.01Ω", 318, 70, 16, INK, bold=1.1))
    out.append(line(56, 160, 176, 160, COPPER, 12))
    out.append(line(176, 160, 296, 160, COPPER, 12))
    out.append(dot(176, 160, 6, INK))
    out.append(text("1m", 116, 186, 12, GRAY))
    out.append(text("1m", 236, 186, 12, GRAY))
    out.append(text("0.02Ω", 338, 160, 16, INK, bold=1.1))
    out.append(arrow(382, 88, 382, 140, RED, 3, 10))
    out.append(text("×2", 392, 114, 13, RED, "start"))
    out.append(darrow(56, 214, 296, 214, GRAY, 2, 8))
    out.append(text("2m", 176, 228, 11, GRAY))
    return svg("\n".join(out))


figures["F07_length"] = f07_length()


def f07_area():
    out = []
    items = [(78, 1, "×1", "R"), (210, 2, "×2", "R÷2"), (342, 3, "×3", "R÷3")]
    for x, k, a, r in items:
        rad = 20 * math.sqrt(k)
        out.append(circle(x, 90, rad, COPPER_L, COPPER, 3))
        out.append(text(a, x, 158, 15, COPPER, bold=1.1))
        out.append(text(r, x, 198, 16, INK, bold=1.1))
    out.append(arrow(118, 90, 160, 90, GRAY, 2.5, 9))
    out.append(arrow(256, 90, 294, 90, GRAY, 2.5, 9))
    out.append(line(24, 178, 396, 178, LINE, 2))
    return svg("\n".join(out))


figures["F07_area"] = f07_area()


def f07_diameter_vs_area():
    out = []
    items = [(66, 1.6, "1.6mm", "2.0mm²", None, None), (164, 2.0, "2.0mm", "3.1mm²", None, None),
             (312, 3.2, "3.2mm", "8.0mm²", "(×2)", "(×4)")]
    for x, d, dl, al, dm, am in items:
        r = d * 15
        cy = 110
        out.append(circle(x, cy, r, COPPER_L, COPPER, 3))
        out.append(darrow(x - r, cy, x + r, cy, INK, 2, 7))
        out.append(text(dl, x, 38, 12, INK))
        out.append(text(al, x, 186, 13, COPPER, bold=1.1))
        if dm:
            out.append(text(dm, x + 48, 38, 11, RED, "start"))
            out.append(text(am, x + 48, 186, 12, RED, "start"))
    return svg("\n".join(out))


figures["F07_diameter_vs_area"] = f07_diameter_vs_area()


def f07_resistivity_formula():
    out = []
    out.append(formula([("R", INK), ("=", GRAY), ("ρ", GREEN), ("×", GRAY), ("L", BLUE), ("÷", GRAY), ("A", ORANGE)], 210, 34, 24))
    x1, x2, cy, ry = 90, 320, 112, 20
    out.append(rect(x1, cy - ry, x2 - x1, ry * 2, COPPER_L, COPPER, 3, 0))
    out.append(ellipse(x1, cy, 9, ry, COPPER_L, COPPER, 3))
    out.append(ellipse(x2, cy, 9, ry, ORANGE_L, ORANGE, 3))
    out.append(text("ρ", 205, cy, 22, GREEN, bold=1.1))
    out.append(darrow(x1, cy + ry + 16, x2, cy + ry + 16, BLUE, 2.5, 9))
    out.append(text("L", (x1 + x2) / 2, cy + ry + 34, 16, BLUE, bold=1.1))
    out.append(text("A", x2 + 26, cy, 18, ORANGE, "start", 1.1))
    chips = [([("L↑", BLUE), ("R↑", INK)], 84), ([("A↑", ORANGE), ("R↓", INK)], 210), ([("ρ↑", GREEN), ("R↑", INK)], 336)]
    for parts, x in chips:
        out.append(rect(x - 52, 196, 104, 30, LIGHT, LINE, 2, 15))
        out.append(formula([parts[0], ("→", GRAY), parts[1]], x, 211, 14))
    return svg("\n".join(out))


figures["F07_resistivity_formula"] = f07_resistivity_formula()


def f07_length_and_diameter():
    """セッション6：長さ 3 倍・直径 2 倍 → 抵抗 3 ÷ (2×2) = 0.75 倍。"""
    out = []
    # 元の電線
    out.append(line(70, 70, 170, 70, COPPER, 8))
    out.append(circle(44, 70, 8, COPPER_L, COPPER, 2.5))
    out.append(text("R", 190, 70, 14, INK, "start", 1.1))
    # 長さ 3 倍・直径 2 倍
    out.append(line(70, 150, 370, 150, COPPER, 16))
    out.append(circle(44, 150, 16, COPPER_L, COPPER, 2.5))
    out.append(text("×2", 44, 116, 13, COPPER, bold=1.1))
    out.append(darrow(70, 184, 370, 184, BLUE, 2, 8))
    out.append(text("×3", 220, 200, 13, BLUE, bold=1.1))
    out.append(formula([("3", BLUE), ("÷", GRAY), ("(2×2)", COPPER), ("=", GRAY), ("0.75", RED)], 316, 40, 15))
    out.append(formula([("R", INK), ("×", GRAY), ("0.75", RED)], 316, 96, 15))
    out.append(arrow(316, 58, 316, 80, GRAY, 2, 8))
    return svg("\n".join(out), W, 220)


figures["F07_length_and_diameter"] = f07_length_and_diameter()


# ===========================================================================
# F08 電圧降下と電力損失
# ===========================================================================
def f08_drop_basic():
    out = []
    top, bottom = 44, 126
    out.append(wires([(44, 79), (44, top), (122, top)], [(178, top), (330, top), (330, 58)],
                     [(330, 112), (330, bottom), (44, bottom), (44, 91)]))
    out.append(battery(44, 85, True, "100V", "right"))
    out.append(res(150, top, False, 56, 18, LIGHT, INK))
    out.append(text("0.2Ω", 150, 66, 10, INK))
    out.append(span_h(122, 178, 20, "2V", RED, 12))
    out.append(res(330, 85, True, 54, 24))
    out.append(text("98V", 348, 85, 13, RED, "start"))
    out.append(flow(88, top, "r", BLUE, 10))
    out.append(text("10A", 88, 26, 11, BLUE))
    # 電圧の高さ
    gy, y100, y98 = 222, 160, 190
    out.append(line(44, gy, 350, gy, LINE, 2))
    out.append(poly([(44, y100), (122, y100), (178, y98), (330, y98)], RED, 4))
    out.append(line(122, y100, 122, gy, LINE, 1.5, dash="4,4"))
    out.append(line(178, y98, 178, gy, LINE, 1.5, dash="4,4"))
    out.append(text("100V", 50, y100 - 14, 11, RED, "start"))
    out.append(text("98V", 338, y98, 11, RED, "start"))
    out.append(span_v(196, y100, y98, "2V", RED, 11))
    return svg("\n".join(out))


figures["F08_drop_basic"] = f08_drop_basic()


def round_trip_frame(label_r="0.1Ω", fill=LIGHT, stroke=INK):
    out = []
    top, bottom = 50, 190
    out.append(wires([(46, 103), (46, top), (152, top)], [(208, top), (350, top), (350, 90)],
                     [(350, 150), (350, bottom), (208, bottom)], [(152, bottom), (46, bottom), (46, 137)]))
    out.append(ac(46, 120, 17))
    out.append(res(180, top, False, 56, 20, fill, stroke, label_r, 11))
    out.append(res(180, bottom, False, 56, 20, fill, stroke, label_r, 11))
    out.append(res(350, 120, True, 60, 26))
    return "\n".join(out)


def f08_round_trip():
    out = [round_trip_frame()]
    out.append(flow(100, 50, "r", BLUE, 11))
    out.append(text("10A", 100, 30, 12, BLUE))
    out.append(flow(270, 190, "l", BLUE, 11))
    out.append(text("10A", 270, 211, 12, BLUE))
    out.append(formula([("0.1Ω", INK), ("×", GRAY), ("2", RED), ("=", GRAY), ("0.2Ω", INK)], 198, 104, 14))
    out.append(formula([("10A", BLUE), ("×", GRAY), ("0.2Ω", INK), ("=", GRAY), ("2V", RED)], 198, 136, 14))
    return svg("\n".join(out))


figures["F08_round_trip"] = f08_round_trip()


def f08_reverse():
    out = []
    x0, x1, x2, y, h = 40, 300, 380, 86, 44
    out.append(rect(x0, y, x1 - x0, h, GREEN_L, GREEN, 3, 6))
    out.append(rect(x1, y, x2 - x1, h, RED_L, RED, 3, 6))
    out.append(text("96V", (x0 + x1) / 2, y + h / 2, 18, GREEN, bold=1.1))
    out.append(text("4V", (x1 + x2) / 2, y + h / 2, 16, RED, bold=1.1))
    out.append(span_h(x0, x2, 58, "? = 100V", INK, 14))
    out.append(res((x0 + x1) / 2, y + h + 34, False, 48, 18))
    out.append(res(x1 + 20, y + h + 34, False, 26, 12, LIGHT, INK))
    out.append(res(x1 + 58, y + h + 34, False, 26, 12, LIGHT, INK))
    out.append(text("2×10A×0.2Ω", (x1 + x2) / 2 - 14, y + h + 58, 10, RED))
    out.append(formula([("96V", GREEN), ("+", GRAY), ("4V", RED), ("=", GRAY), ("100V", INK)], 210, 216, 18))
    return svg("\n".join(out))


figures["F08_reverse"] = f08_reverse()


def f08_power_loss():
    out = [round_trip_frame("r", ORANGE_L, ORANGE)]
    out.append(heat(180, 38, 3, 12, 26, RED))
    out.append(heat_down(180, 202, 3, 12, 26, RED))
    out.append(flow(100, 50, "r", BLUE, 11))
    out.append(text("I", 100, 30, 13, BLUE))
    out.append(flow(270, 190, "l", BLUE, 11))
    out.append(text("I", 270, 211, 13, BLUE))
    out.append(formula([("P", ORANGE), ("=", GRAY), ("2", RED), ("×", GRAY), ("I", BLUE), ("²", ORANGE), ("×", GRAY), ("r", ORANGE)],
                       198, 120, 20))
    return svg("\n".join(out))


figures["F08_power_loss"] = f08_power_loss()


def f08_thickness_comparison():
    out = []
    base = 214
    data = [(86, 1.6, "1.6mm", 3.6, 36), (210, 2.0, "2.0mm", 2.2, 22), (334, 2.6, "2.6mm", 1.3, 13)]
    out.append(line(24, base, 396, base, INK, 3))
    for x, d, dl, dv, loss in data:
        out.append(circle(x, 38, d * 7.5, COPPER_L, COPPER, 3))
        out.append(text(dl, x, 74, 12, INK))
        hv = dv / 3.6 * 96
        out.append(rect(x - 38, base - hv, 34, hv, RED_L, RED, 2.5, 3))
        out.append(text(f"{dv}V", x - 21, base - hv - 12, 11, RED, bold=1.1))
        out.append(rect(x + 4, base - hv, 34, hv, ORANGE_L, ORANGE, 2.5, 3))
        out.append(text(f"{loss}W", x + 21, base - hv - 12, 11, ORANGE, bold=1.1))
    return svg("\n".join(out))


figures["F08_thickness_comparison"] = f08_thickness_comparison()


def f08_per_km():
    """セッション7：1km あたり 9Ω の電線で、こう長 20m。1本 0.18Ω、往復 0.36Ω、10A で 3.6V。"""
    out = []
    top, bottom = 56, 150
    out.append(wires([(46, 86), (46, top), (152, top)], [(208, top), (350, top), (350, 73)],
                     [(350, 133), (350, bottom), (208, bottom)], [(152, bottom), (46, bottom), (46, 120)]))
    out.append(ac(46, 103, 17))
    out.append(res(180, top, False, 56, 20, LIGHT, INK, "0.18Ω", 10))
    out.append(res(180, bottom, False, 56, 20, LIGHT, INK, "0.18Ω", 10))
    out.append(res(350, 103, True, 60, 26))
    out.append(span_h(46, 350, 26, "20m", BLUE, 12))
    out.append(flow(110, top, "r", BLUE, 10))
    out.append(flow(280, bottom, "l", BLUE, 10))
    out.append(text("10A", 280, 170, 11, BLUE))
    out.append(formula([("9Ω", INK), ("×", GRAY), ("0.02", BLUE), ("=", GRAY), ("0.18Ω", INK)], 212, 103, 13))
    out.append(formula([("0.18Ω", INK), ("×", GRAY), ("2", RED), ("=", GRAY), ("0.36Ω", INK)], 210, 196, 14))
    out.append(formula([("10A", BLUE), ("×", GRAY), ("0.36Ω", INK), ("=", GRAY), ("3.6V", RED)], 210, 226, 14))
    return svg("\n".join(out), W, 246)


figures["F08_per_km"] = f08_per_km()


# ---------------------------------------------------------------------------
def write_assets():
    FIG.mkdir(parents=True, exist_ok=True)
    contents = FIG / "Contents.json"
    if not contents.exists():
        contents.write_text(json.dumps({"info": {"author": "xcode", "version": 1},
                                        "properties": {"provides-namespace": False}}, indent=2) + "\n")
    for name, body in figures.items():
        d = FIG / f"{name}.imageset"
        d.mkdir(exist_ok=True)
        (d / f"{name}.svg").write_text(body, encoding="utf-8")
        (d / "Contents.json").write_text(json.dumps({
            "images": [{"filename": f"{name}.svg", "idiom": "universal"}],
            "info": {"author": "xcode", "version": 1},
            "properties": {"preserves-vector-representation": True},
        }, indent=2) + "\n")
    print(f"{len(figures)} 枚を書き出しました: {FIG}")


def write_preview(out_dir):
    import cairosvg  # 確認用。アプリには不要
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    for name, body in figures.items():
        cairosvg.svg2png(bytestring=body.encode("utf-8"), write_to=str(out / f"{name}.png"), output_width=W * 2)
    print(f"プレビュー {len(figures)} 枚: {out}")


if __name__ == "__main__":
    if len(sys.argv) >= 3 and sys.argv[1] == "--preview":
        write_preview(sys.argv[2])
    else:
        write_assets()
