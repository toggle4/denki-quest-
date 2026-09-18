#!/usr/bin/env python3
"""単線図（配線図）の SVG を生成して Assets.xcassets/Figures/<name>.imageset に置く。

Xcode の SVG レンダラは <text> を落とすことがあるので、数字・記号も線で描く。
再生成: python3 tools/gen_wiring_figures.py
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FIG = ROOT / "DenkiQuest" / "Assets.xcassets" / "Figures"
INK = "#1B2550"
ACC = "#C99700"
W, H = 420, 280

# ---- 線で描く簡易グリフ（座標は 0..10 x 0..14）----
GLYPHS = {
    "1": [[(5, 0), (5, 14)], [(2, 3), (5, 0)]],
    "2": [[(0, 3), (2, 0), (8, 0), (10, 3), (10, 5), (0, 14), (10, 14)]],
    "3": [[(0, 0), (10, 0), (4, 6), (10, 9), (8, 14), (0, 14)]],
    "4": [[(8, 14), (8, 0), (0, 9), (10, 9)]],
    "5": [[(10, 0), (0, 0), (0, 6), (7, 6), (10, 9), (10, 11), (7, 14), (0, 14)]],
    "S": [[(10, 2), (8, 0), (2, 0), (0, 2), (0, 5), (2, 7), (8, 7), (10, 9), (10, 12), (8, 14), (2, 14), (0, 12)]],
    "L": [[(0, 0), (0, 14), (10, 14)]],
    "C": [[(10, 2), (8, 0), (2, 0), (0, 2), (0, 12), (2, 14), (8, 14), (10, 12)]],
    "P": [[(0, 14), (0, 0), (8, 0), (10, 2), (10, 6), (8, 8), (0, 8)]],
    "J": [[(2, 0), (10, 0)], [(6, 0), (6, 11), (4, 14), (1, 14), (0, 12)]],
    "B": [[(0, 0), (0, 14), (8, 14), (10, 12), (10, 9), (8, 7), (0, 7)], [(0, 0), (8, 0), (10, 2), (10, 5), (8, 7)]],
    "A": [[(0, 14), (5, 0), (10, 14)], [(2, 9), (8, 9)]],
    "V": [[(0, 0), (5, 14), (10, 0)]],
}


def glyph(ch, x, y, size=10, color=INK, width=2.2):
    """ch を左上 (x, y) に高さ size で描く。"""
    sx = size / 14 * 10 / 10
    parts = []
    for stroke in GLYPHS[ch]:
        pts = " ".join(f"{x + px * size / 14:.1f},{y + py * size / 14:.1f}" for px, py in stroke)
        parts.append(f'<polyline points="{pts}" fill="none" stroke="{color}" stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round"/>')
    return "\n".join(parts)


def label(text, x, y, size=10, color=INK):
    out = []
    for i, ch in enumerate(text):
        out.append(glyph(ch, x + i * size * 0.85, y, size, color))
    return "\n".join(out)


def circled_digit(d, x, y, r=11):
    return (f'<circle cx="{x}" cy="{y}" r="{r}" fill="#FFFFFF" stroke="{ACC}" stroke-width="2.5"/>'
            + glyph(d, x - 4, y - 7, 14, ACC, 2.4))


# ---- 図記号 ----
def power(x, y):
    """電源（分電盤からの電源）: 四角に正弦波"""
    return (f'<rect x="{x-22}" y="{y-14}" width="44" height="28" rx="4" fill="#FFFFFF" stroke="{INK}" stroke-width="3"/>'
            f'<path d="M{x-14} {y} q 7 -12 14 0 t 14 0" fill="none" stroke="{INK}" stroke-width="2.5"/>')


def jbox(x, y):
    """VVF 用ジョイントボックス（円）"""
    return f'<circle cx="{x}" cy="{y}" r="17" fill="#FFFFFF" stroke="{INK}" stroke-width="3"/>' + label("JB", x - 11, y - 6, 9)


def lamp(x, y, tag="L"):
    """照明器具（○に×）"""
    s = 9
    return (f'<circle cx="{x}" cy="{y}" r="15" fill="#FFFFFF" stroke="{INK}" stroke-width="3"/>'
            f'<line x1="{x-s}" y1="{y-s}" x2="{x+s}" y2="{y+s}" stroke="{INK}" stroke-width="3"/>'
            f'<line x1="{x-s}" y1="{y+s}" x2="{x+s}" y2="{y-s}" stroke="{INK}" stroke-width="3"/>'
            + label(tag, x + 20, y - 7, 10))


def switch(x, y, kind="", tag="S"):
    """点滅器（●）。kind: "3" / "4" で 3 路 / 4 路"""
    out = f'<circle cx="{x}" cy="{y}" r="8" fill="{INK}"/>'
    if kind:
        out += glyph(kind, x + 12, y - 3, 12)
    out += label(tag, x - 5, y + 14, 9)
    return out


def outlet(x, y):
    """コンセント（○に 2 本の刃受）"""
    return (f'<circle cx="{x}" cy="{y}" r="13" fill="#FFFFFF" stroke="{INK}" stroke-width="3"/>'
            f'<line x1="{x-4}" y1="{y-6}" x2="{x-4}" y2="{y+6}" stroke="{INK}" stroke-width="3"/>'
            f'<line x1="{x+4}" y1="{y-6}" x2="{x+4}" y2="{y+6}" stroke="{INK}" stroke-width="3"/>'
            + label("C", x - 5, y + 18, 9))


def pilot(x, y):
    """確認表示灯（小さい○に点）"""
    return (f'<circle cx="{x}" cy="{y}" r="9" fill="#FFFFFF" stroke="{INK}" stroke-width="3"/>'
            f'<circle cx="{x}" cy="{y}" r="3" fill="{INK}"/>' + label("P", x - 5, y + 14, 9))


def gang_box(x, y, w, h):
    """連用取付枠（点線の角丸四角）"""
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="8" fill="none" stroke="{INK}" stroke-width="1.5" stroke-dasharray="5,4"/>'


def wire(x1, y1, x2, y2):
    return f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{INK}" stroke-width="3" stroke-linecap="round"/>'


def mark(x, y, d):
    """区間の目印（黄色の破線の丸 + 番号）"""
    return (f'<circle cx="{x}" cy="{y}" r="20" fill="none" stroke="{ACC}" stroke-width="2.5" stroke-dasharray="6,4"/>'
            + circled_digit(d, x + 22, y - 18))


def svg(body):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}">\n'
            f'<rect x="0" y="0" width="{W}" height="{H}" rx="14" fill="#FFFFFF"/>\n{body}\n</svg>\n')


figures = {}

# A: 照明 1 灯 + 単極スイッチ
figures["wiring_a"] = svg("\n".join([
    wire(62, 140, 190, 140), wire(207, 130, 300, 70), wire(207, 150, 300, 210),
    power(40, 140), jbox(190, 140), lamp(315, 62), switch(315, 218),
    mark(253, 180, "1"), mark(253, 100, "2"),
]))

# B: 照明 + 単極スイッチ + コンセント
figures["wiring_b"] = svg("\n".join([
    wire(62, 140, 190, 140), wire(207, 130, 300, 62), wire(207, 150, 300, 218), wire(207, 140, 330, 140),
    power(40, 140), jbox(190, 140), lamp(315, 54), switch(315, 226), outlet(345, 140),
    mark(253, 180, "1"), mark(253, 100, "2"), mark(270, 140, "3"),
]))

# C: 3 路スイッチ 2 個 + 照明
figures["wiring_c"] = svg("\n".join([
    wire(62, 130, 190, 130), wire(190, 113, 190, 55), wire(178, 143, 100, 225), wire(202, 143, 300, 225),
    power(40, 130), jbox(190, 130), lamp(190, 42, "L"), switch(90, 236, "3"), switch(312, 236, "3"),
    mark(139, 184, "1"), mark(251, 184, "2"), mark(190, 84, "3"),
]))

# E: 1 スイッチで 2 灯（送り配線）
figures["wiring_e"] = svg("\n".join([
    wire(62, 140, 190, 140), wire(207, 130, 280, 62), wire(295, 62, 370, 62), wire(207, 150, 300, 218),
    power(40, 140), jbox(190, 140), lamp(280, 55, "L"), lamp(385, 62, "L"), switch(315, 226),
    mark(243, 96, "1"), mark(332, 62, "2"), mark(253, 184, "3"),
]))

# F: スイッチとコンセントの連用 + 照明
figures["wiring_f"] = svg("\n".join([
    wire(62, 140, 190, 140), wire(207, 130, 300, 62), wire(207, 150, 296, 218),
    power(40, 140), jbox(190, 140), lamp(315, 54),
    gang_box(288, 190, 92, 60), switch(308, 218), outlet(355, 218),
    mark(251, 184, "1"), mark(253, 96, "2"),
]))

# G: 確認表示灯（同時点滅）+ スイッチ の連用 + 照明
figures["wiring_g"] = svg("\n".join([
    wire(62, 140, 190, 140), wire(207, 130, 300, 62), wire(207, 150, 296, 218),
    power(40, 140), jbox(190, 140), lamp(315, 54),
    gang_box(288, 190, 92, 60), pilot(310, 218), switch(355, 218),
    mark(251, 184, "1"), mark(253, 96, "2"),
]))

# I: 3 路 + 4 路 + 3 路 + 照明
figures["wiring_i"] = svg("\n".join([
    wire(62, 120, 190, 120), wire(190, 103, 190, 50), wire(176, 132, 80, 225), wire(190, 137, 190, 225), wire(204, 132, 300, 225),
    power(40, 120), jbox(190, 120), lamp(190, 38, "L"), switch(72, 236, "3"), switch(190, 236, "4"), switch(312, 236, "3"),
    mark(190, 182, "1"), mark(128, 178, "2"), mark(252, 178, "3"),
]))

FIG.mkdir(parents=True, exist_ok=True)
(FIG / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}, "properties": {"provides-namespace": False}}, indent=2) + "\n")
for name, body in figures.items():
    d = FIG / f"{name}.imageset"
    d.mkdir(exist_ok=True)
    (d / f"{name}.svg").write_text(body, encoding="utf-8")
    (d / "Contents.json").write_text(json.dumps({
        "images": [{"filename": f"{name}.svg", "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
        "properties": {"preserves-vector-representation": True},
    }, indent=2) + "\n")
    print("wrote", name)
