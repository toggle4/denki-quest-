#!/usr/bin/env python3
"""ステージ 1（S01〜S07）の図を生成して Assets.xcassets/Figures/<name>.imageset に置く。

- sym_*  配線用図記号（JIS C 0303 の形を自分で描いたもの）と傍記
- face_* コンセントの刃受けの形（正面から見た図）
- cont_* スイッチの接点の組み合わせ（接点構成図）
- cab_*  電線・ケーブルの断面
- mat_*  配線材料、tool_* 工具、dev_* 機器（形の特徴だけを描いたイメージ図。写真ではない）
- S0x_*  教材の画面に出す一覧図

選択肢の図（imageChoice）は 200 × 150 のタイル。一覧図は 420 × 240 前後。
文字は tools/gen_lesson_figures.py の線の文字で描く（<text> は使わない。日本語は入れない）。

再生成: python3 tools/gen_symbol_figures.py
確認用の PNG: python3 tools/gen_symbol_figures.py --preview <出力フォルダ>
"""
import json
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_lesson_figures as base  # noqa: E402
from gen_lesson_figures import (  # noqa: E402
    BLUE, COPPER, COPPER_L, GRAY, GREEN, INK, LIGHT, LINE, ORANGE, ORANGE_L, RED, WHITE, YEL, YEL_L,
    circle, dot, line, poly, rect, svg, text,
)

FIG = base.FIG
TW, TH = 200, 150

# 線の文字に足りない字を足す（gen_lesson_figures.py 側にあればそちらを使う）
EXTRA_GLYPHS = {
    "D": [[(0, 0), (0, 14), (6, 14), (10, 10), (10, 4), (6, 0), (0, 0)]],
    "E": [[(10, 0), (0, 0), (0, 14), (10, 14)], [(0, 7), (7, 7)]],
    "F": [[(10, 0), (0, 0), (0, 14)], [(0, 7), (7, 7)]],
    "H": [[(0, 0), (0, 14)], [(10, 0), (10, 14)], [(0, 7), (10, 7)]],
    "K": [[(0, 0), (0, 14)], [(10, 0), (0, 8)], [(3, 5.5), (10, 14)]],
    "N": [[(0, 14), (0, 0), (10, 14), (10, 0)]],
    "O": [[(3, 0), (7, 0), (10, 3), (10, 11), (7, 14), (3, 14), (0, 11), (0, 3), (3, 0)]],
    "T": [[(0, 0), (10, 0)], [(5, 0), (5, 14)]],
    "U": [[(0, 0), (0, 11), (3, 14), (7, 14), (10, 11), (10, 0)]],
    "X": [[(0, 0), (10, 14)], [(10, 0), (0, 14)]],
    "Y": [[(0, 0), (5, 7), (10, 0)], [(5, 7), (5, 14)]],
    "f": [[(9, 1), (7, 0), (5, 0), (3, 2), (3, 14)], [(0, 5), (7, 5)]],
    "p": [[(0, 5), (0, 19)], [(0, 7), (2, 5), (7, 5), (9, 7), (9, 12), (7, 14), (2, 14), (0, 12)]],
}
for _ch, _strokes in EXTRA_GLYPHS.items():
    base.G.setdefault(_ch, _strokes)
base.ADV.setdefault("f", 8)
base.ADV.setdefault("p", 9)

DARK = "#2B2F3A"
CREAM = "#F4EFE3"
PLATE = "#FBF8F1"
STEEL = "#B9C1CF"
STEEL_D = "#7D879A"


def tag(label, x, y, size=16, color=INK, anchor="start"):
    return text(label, x, y, size, color, anchor, 1.1)


# ===========================================================================
# 配線用図記号
# ===========================================================================
def switch_sym(cx, cy, s=1.0, label=None, dimmer=False):
    """点滅器 ●。label は右上の傍記。dimmer は調光器（斜めの矢印）。"""
    out = [dot(cx, cy, 9 * s, INK)]
    if dimmer:
        out.append(base.arrow(cx - 16 * s, cy + 16 * s, cx + 18 * s, cy - 18 * s, INK, 2.6 * s, 11 * s))
    if label:
        out.append(tag(label, cx + 15 * s, cy - 14 * s, 20 * s))
    return "\n".join(out)


def outlet_sym(cx, cy, s=1.0, labels=None):
    """コンセント（○に縦線 2 本）。labels は右の傍記（上から順に）。"""
    r = 20 * s
    if labels:
        cx -= 14 * s  # 傍記のぶん左へ寄せる
    out = [circle(cx, cy, r, WHITE, INK, 3 * s),
           line(cx - 6 * s, cy - 9 * s, cx - 6 * s, cy + 9 * s, INK, 3 * s),
           line(cx + 6 * s, cy - 9 * s, cx + 6 * s, cy + 9 * s, INK, 3 * s)]
    for i, lab in enumerate(labels or []):
        out.append(tag(lab, cx + r + 8 * s, cy - 12 * s + i * 24 * s, 18 * s))
    return "\n".join(out)


def light_sym(cx, cy, s=1.0, label=None):
    """照明器具（白熱灯・HID 灯）○。label は傍記（CL・CH・DL など）。"""
    if label:
        cx -= 12 * s
    out = [circle(cx, cy, 20 * s, WHITE, INK, 3 * s)]
    if label:
        out.append(tag(label, cx + 28 * s, cy - 14 * s, 18 * s))
    return "\n".join(out)


def pendant_sym(cx, cy, s=1.0):
    """ペンダント（○に横線）。"""
    r = 20 * s
    return circle(cx, cy, r, WHITE, INK, 3 * s) + line(cx - r, cy, cx + r, cy, INK, 3 * s)


def bracket_sym(cx, cy, s=1.0):
    """壁付の照明（壁側を塗る）。左に壁。"""
    r = 20 * s
    wall_x = cx - r
    out = [line(wall_x, cy - 38 * s, wall_x, cy + 38 * s, INK, 4 * s)]
    for k in range(-3, 4):
        y = cy + k * 11 * s
        out.append(line(wall_x, y, wall_x - 10 * s, y + 10 * s, GRAY, 2 * s))
    out.append(circle(cx, cy, r, WHITE, INK, 3 * s))
    out.append(f'<path d="M{cx:.1f} {cy - r:.1f} A {r:.1f} {r:.1f} 0 0 0 {cx:.1f} {cy + r:.1f} Z" fill="{INK}"/>')
    return "\n".join(out)


def fluorescent_sym(cx, cy, s=1.0, label=None):
    """蛍光灯（細長い四角の中央に ○）。"""
    w, h, r = 120 * s, 22 * s, 13 * s
    out = [rect(cx - w / 2, cy - h / 2, w, h, WHITE, INK, 3 * s, 2),
           circle(cx, cy, r, WHITE, INK, 3 * s)]
    if label:
        out.append(tag(label, cx + w / 2 + 6 * s, cy - 18 * s, 16 * s))
    return "\n".join(out)


def fan_sym(cx, cy, s=1.0):
    """換気扇（○の中に ∞）。"""
    r = 24 * s
    a = 9 * s
    path = (f"M{cx:.1f} {cy:.1f} C {cx + a:.1f} {cy - 1.4 * a:.1f} {cx + 2.2 * a:.1f} {cy - 1.1 * a:.1f} {cx + 2.2 * a:.1f} {cy:.1f} "
            f"C {cx + 2.2 * a:.1f} {cy + 1.1 * a:.1f} {cx + a:.1f} {cy + 1.4 * a:.1f} {cx:.1f} {cy:.1f} "
            f"C {cx - a:.1f} {cy - 1.4 * a:.1f} {cx - 2.2 * a:.1f} {cy - 1.1 * a:.1f} {cx - 2.2 * a:.1f} {cy:.1f} "
            f"C {cx - 2.2 * a:.1f} {cy + 1.1 * a:.1f} {cx - a:.1f} {cy + 1.4 * a:.1f} {cx:.1f} {cy:.1f} Z")
    return circle(cx, cy, r, WHITE, INK, 3 * s) + f'<path d="{path}" fill="none" stroke="{INK}" stroke-width="{2.6 * s:.1f}"/>'


def boxed(cx, cy, s, label, w=46, h=46):
    """四角の中に文字（開閉器 S、配線用遮断器 B、漏電遮断器 E など）。"""
    return (rect(cx - w * s / 2, cy - h * s / 2, w * s, h * s, WHITE, INK, 3 * s, 2)
            + text(label, cx, cy, 20 * s, INK, "middle", 1.1))


def circled_letter(cx, cy, s, label, r=22):
    """○の中に文字（電動機 M、電熱器 H、電力量計 Wh など）。"""
    return circle(cx, cy, r * s, WHITE, INK, 3 * s) + text(label, cx, cy, (18 if len(label) > 1 else 20) * s, INK, "middle", 1.1)


def panel_sym(cx, cy, s=1.0):
    """分電盤（長方形を対角線で分け、半分を塗る）。"""
    w, h = 76 * s, 40 * s
    x0, y0 = cx - w / 2, cy - h / 2
    return (rect(x0, y0, w, h, WHITE, INK, 3 * s, 0)
            + poly([(x0, y0 + h), (x0 + w, y0), (x0 + w, y0 + h)], INK, 1, fill=INK, close=True))


def aircon_sym(cx, cy, s=1.0, unit=None):
    """ルームエアコン（四角に RC）。unit は傍記 I（屋内）・O（屋外）。"""
    out = [boxed(cx, cy, s, "RC", 60, 40)]
    if unit:
        out.append(tag(unit, cx + 38 * s, cy - 14 * s, 18 * s))
    return "\n".join(out)


def earth_sym(cx, cy, s=1.0):
    """接地極（縦線と、短くなる横線 3 本）。"""
    top = cy - 26 * s
    out = [line(cx, top, cx, cy, INK, 3 * s)]
    for i, half in enumerate((22, 14, 6)):
        y = cy + i * 9 * s
        out.append(line(cx - half * s, y, cx + half * s, y, INK, 3 * s))
    return "\n".join(out)


def pushbutton_sym(cx, cy, s=1.0):
    """押しボタン（○の中に●）。"""
    return circle(cx, cy, 17 * s, WHITE, INK, 3 * s) + dot(cx, cy, 7 * s, INK)


def wiring_line(x1, x2, y, kind, s=1.0):
    """配線の線種。ceiling = 実線、floor = 破線、exposed = 点線、underground = 一点鎖線"""
    w = 4 * s
    dash = {"ceiling": None, "floor": f"{14 * s:.0f},{9 * s:.0f}", "exposed": f"{2 * s:.0f},{9 * s:.0f}",
            "underground": f"{20 * s:.0f},{7 * s:.0f},{3 * s:.0f},{7 * s:.0f}"}[kind]
    return line(x1, y, x2, y, INK, w, dash)


# ===========================================================================
# コンセントの刃受け（正面）
# ===========================================================================
def slot(cx, cy, w, h):
    return rect(cx - w / 2, cy - h / 2, w, h, DARK, DARK, 0, min(w, h) / 2)


def ground_hole(cx, cy, s):
    """接地極の刃受け（半円形の穴）。"""
    r = 8 * s
    return (f'<path d="M{cx - r:.1f} {cy + r * 0.3:.1f} L {cx - r:.1f} {cy - r * 0.2:.1f} '
            f'A {r:.1f} {r:.1f} 0 0 1 {cx + r:.1f} {cy - r * 0.2:.1f} L {cx + r:.1f} {cy + r * 0.3:.1f} Z" fill="{DARK}"/>')


def outlet_face(cx, cy, kind, s=1.0):
    """kind: 15A125V / 15A125V_E / 20A125V / 15A250V / 15A250V_E / twist"""
    out = [rect(cx - 46 * s, cy - 52 * s, 92 * s, 104 * s, PLATE, STEEL_D, 2.5 * s, 12 * s)]
    top = cy - 8 * s if kind.endswith("_E") else cy
    if kind.startswith("15A125V"):
        out.append(slot(cx - 13 * s, top, 6 * s, 30 * s))   # 接地側（長い）
        out.append(slot(cx + 13 * s, top, 6 * s, 24 * s))
    elif kind == "20A125V":
        out.append(slot(cx - 13 * s, cy, 6 * s, 30 * s))
        out.append(slot(cx - 20 * s, cy, 14 * s, 6 * s))    # 横向きの刃も入る
        out.append(slot(cx + 13 * s, cy, 6 * s, 24 * s))
    elif kind.startswith("15A250V"):
        out.append(slot(cx - 15 * s, top, 20 * s, 6 * s))
        out.append(slot(cx + 15 * s, top, 20 * s, 6 * s))
    elif kind == "twist":
        r = 26 * s
        out.append(circle(cx, cy, r + 8 * s, WHITE, STEEL_D, 2 * s))
        for a0 in (200, 20):
            a1 = a0 + 55
            p0 = (cx + r * math.cos(math.radians(a0)), cy + r * math.sin(math.radians(a0)))
            p1 = (cx + r * math.cos(math.radians(a1)), cy + r * math.sin(math.radians(a1)))
            out.append(f'<path d="M{p0[0]:.1f} {p0[1]:.1f} A {r:.1f} {r:.1f} 0 0 1 {p1[0]:.1f} {p1[1]:.1f}" '
                       f'fill="none" stroke="{DARK}" stroke-width="{6 * s:.1f}" stroke-linecap="round"/>')
    if kind.endswith("_E"):
        out.append(ground_hole(cx, cy + 26 * s, s))
    return "\n".join(out)


# ===========================================================================
# スイッチの接点構成図
# ===========================================================================
def terminal(x, y, s, label=None, lx=0, ly=0):
    out = circle(x, y, 5 * s, WHITE, INK, 2.5 * s)
    if label:
        out += text(label, x + lx * s, y + ly * s, 14 * s, INK, "middle", 1.1)
    return out


def contact(cx, cy, kind, s=1.0):
    """kind: single（片切）/ 3way（3 路）/ 4way（4 路）/ 2p（両切）"""
    out = []
    if kind == "single":
        a, b = (cx - 40 * s, cy), (cx + 40 * s, cy)
        out += [line(a[0] - 26 * s, cy, a[0], cy, INK, 3 * s), line(b[0], cy, b[0] + 26 * s, cy, INK, 3 * s),
                line(a[0], cy, b[0] - 6 * s, cy - 28 * s, INK, 3.5 * s), terminal(*a, s), terminal(*b, s)]
    elif kind == "2p":
        for dy in (-22, 22):
            y = cy + dy * s
            a, b = (cx - 40 * s, y), (cx + 40 * s, y)
            out += [line(a[0] - 26 * s, y, a[0], y, INK, 3 * s), line(b[0], y, b[0] + 26 * s, y, INK, 3 * s),
                    line(a[0], y, b[0] - 6 * s, y - 20 * s, INK, 3.5 * s), terminal(*a, s), terminal(*b, s)]
        out.append(line(cx - 4 * s, cy - 32 * s, cx - 4 * s, cy + 12 * s, GRAY, 2 * s, dash=f"{5 * s:.0f},{4 * s:.0f}"))
    elif kind == "3way":
        o, t1, t3 = (cx - 40 * s, cy), (cx + 40 * s, cy - 26 * s), (cx + 40 * s, cy + 26 * s)
        out += [line(o[0] - 26 * s, cy, o[0], cy, INK, 3 * s),
                line(t1[0], t1[1], t1[0] + 26 * s, t1[1], INK, 3 * s), line(t3[0], t3[1], t3[0] + 26 * s, t3[1], INK, 3 * s),
                line(o[0], o[1], t1[0] - 4 * s, t1[1] + 3 * s, INK, 3.5 * s),
                terminal(*o, s, "0", 0, 18), terminal(*t1, s, "1", 0, -17), terminal(*t3, s, "3", 0, 18)]
    elif kind == "4way":
        l1, l2 = (cx - 34 * s, cy - 24 * s), (cx - 34 * s, cy + 24 * s)
        r1, r2 = (cx + 34 * s, cy - 24 * s), (cx + 34 * s, cy + 24 * s)
        out += [line(l1[0] - 26 * s, l1[1], l1[0], l1[1], INK, 3 * s), line(l2[0] - 26 * s, l2[1], l2[0], l2[1], INK, 3 * s),
                line(r1[0], r1[1], r1[0] + 26 * s, r1[1], INK, 3 * s), line(r2[0], r2[1], r2[0] + 26 * s, r2[1], INK, 3 * s),
                line(l1[0], l1[1], r1[0], r1[1], INK, 3.5 * s), line(l2[0], l2[1], r2[0], r2[1], INK, 3.5 * s),
                line(l1[0], l1[1], r2[0], r2[1], GRAY, 2.5 * s, dash=f"{6 * s:.0f},{5 * s:.0f}"),
                line(l2[0], l2[1], r1[0], r1[1], GRAY, 2.5 * s, dash=f"{6 * s:.0f},{5 * s:.0f}"),
                terminal(*l1, s, "1", 0, -17), terminal(*l2, s, "2", 0, 18),
                terminal(*r1, s, "3", 0, -17), terminal(*r2, s, "4", 0, 18)]
    return "\n".join(out)


# ===========================================================================
# 電線・ケーブルの断面
# ===========================================================================
INSUL = {"black": "#3A3A3A", "white": "#F5F5F5", "red": "#D8453A", "green": "#3C9D5A"}


def core(cx, cy, s, color, r_cu=7, r_ins=13):
    return (circle(cx, cy, r_ins * s, INSUL[color], INK, 2 * s)
            + circle(cx, cy, r_cu * s, COPPER_L, COPPER, 2 * s))


def cable(cx, cy, kind, s=1.0):
    """kind: IV / VVF2 / VVF3 / VVR / CV"""
    out = []
    if kind == "IV":
        out.append(circle(cx, cy, 26 * s, INSUL["black"], INK, 2.5 * s))
        out.append(circle(cx, cy, 13 * s, COPPER_L, COPPER, 2.5 * s))
    elif kind in ("VVF2", "VVF3"):
        colors = ["black", "white"] + (["red"] if kind == "VVF3" else [])
        n = len(colors)
        w = (n * 30 + 20) * s
        out.append(rect(cx - w / 2, cy - 24 * s, w, 48 * s, "#E9ECEF", INK, 2.5 * s, 22 * s))
        for i, c in enumerate(colors):
            out.append(core(cx + (i - (n - 1) / 2) * 30 * s, cy, s, c))
    elif kind == "VVR":
        out.append(circle(cx, cy, 42 * s, "#E9ECEF", INK, 2.5 * s))
        out.append(circle(cx, cy, 33 * s, "#D5D9DF", GRAY, 1.5 * s, dash=f"{3 * s:.0f},{3 * s:.0f}"))
        for (dx, dy), c in zip(((-15, -6), (15, -6), (0, 17)), ("black", "white", "red")):
            out.append(core(cx + dx * s, cy + dy * s, s, c, 6, 12))
    elif kind == "CV":
        out.append(circle(cx, cy, 42 * s, "#3A3A3A", INK, 2.5 * s))
        out.append(circle(cx, cy, 35 * s, CREAM, INK, 2 * s))
        out.append(circle(cx, cy, 15 * s, COPPER_L, COPPER, 2.5 * s))
        for k in range(7):
            a = k * math.tau / 6
            px, py = (cx, cy) if k == 6 else (cx + 9 * s * math.cos(a), cy + 9 * s * math.sin(a))
            out.append(circle(px, py, 4.5 * s, COPPER_L, COPPER, 1.2 * s))
    return "\n".join(out)


# ===========================================================================
# 配線材料（イメージ図）
# ===========================================================================
def pipe_h(x1, x2, cy, r, fill=STEEL, stroke=STEEL_D, sw=2.5):
    return rect(x1, cy - r, x2 - x1, 2 * r, fill, stroke, sw, 2)


def threads(x1, x2, cy, r, step=6, color=STEEL_D):
    return "\n".join(line(x, cy - r, x, cy + r, color, 1.3) for x in frange(x1, x2, step))


def frange(a, b, step):
    x = a
    while x <= b + 1e-9:
        yield x
        x += step


def mat_normal_bend(cx, cy, s=1.0):
    """ノーマルベンド（90° に曲がった管）。"""
    R, r = 46 * s, 11 * s
    x0, y0 = cx - 40 * s, cy + 40 * s  # 曲がりの中心
    outer, inner = R + r, R - r
    d = (f"M{x0 + outer:.1f} {y0:.1f} A {outer:.1f} {outer:.1f} 0 0 0 {x0:.1f} {y0 - outer:.1f} "
         f"L {x0:.1f} {y0 - inner:.1f} A {inner:.1f} {inner:.1f} 0 0 1 {x0 + inner:.1f} {y0:.1f} Z")
    out = [f'<path d="{d}" fill="{STEEL}" stroke="{STEEL_D}" stroke-width="{2.5 * s:.1f}"/>']
    # 両端のねじ部
    out.append(rect(x0 + inner, y0, 2 * r, 18 * s, STEEL, STEEL_D, 2.5 * s, 1))
    out.append(rect(x0 - 18 * s, y0 - outer, 18 * s, 2 * r, STEEL, STEEL_D, 2.5 * s, 1))
    for k in range(4):
        out.append(line(x0 + inner, y0 + (4 + 4 * k) * s, x0 + inner + 2 * r, y0 + (4 + 4 * k) * s, STEEL_D, 1.3 * s))
        out.append(line(x0 - (4 + 4 * k) * s, y0 - outer, x0 - (4 + 4 * k) * s, y0 - inner, STEEL_D, 1.3 * s))
    return "\n".join(out)


def mat_coupling(cx, cy, s=1.0):
    """カップリング（管と管をつなぐ短い筒）。両側に管を差した状態。"""
    out = [pipe_h(cx - 90 * s, cx - 26 * s, cy, 12 * s), pipe_h(cx + 26 * s, cx + 90 * s, cy, 12 * s),
           rect(cx - 30 * s, cy - 17 * s, 60 * s, 34 * s, "#9AA3B5", STEEL_D, 2.5 * s, 3)]
    out.append(threads(cx - 24 * s, cx + 24 * s, cy, 15 * s, 6 * s, STEEL_D))
    return "\n".join(out)


def mat_bushing(cx, cy, s=1.0):
    """絶縁ブッシング（管の端に付ける、つばのある輪）。正面と横から。"""
    out = [circle(cx - 44 * s, cy, 34 * s, "#3A3A3A", INK, 2.5 * s), circle(cx - 44 * s, cy, 20 * s, WHITE, INK, 2.5 * s)]
    x = cx + 36 * s
    out.append(rect(x - 8 * s, cy - 34 * s, 12 * s, 68 * s, "#3A3A3A", INK, 2.5 * s, 3))
    out.append(rect(x + 4 * s, cy - 22 * s, 30 * s, 44 * s, "#555555", INK, 2.5 * s, 2))
    return "\n".join(out)


def mat_locknut(cx, cy, s=1.0):
    """ロックナット（周りに爪のある薄い輪）。"""
    R, r, n = 40 * s, 24 * s, 12
    pts = []
    for k in range(n * 2):
        a = k * math.pi / n
        rr = R if k % 2 == 0 else R - 7 * s
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    return poly(pts, STEEL_D, 2.5 * s, fill=STEEL, close=True) + circle(cx, cy, r, WHITE, STEEL_D, 2.5 * s)


def mat_saddle(cx, cy, s=1.0):
    """両サドル（管の端から見た図。管をまたいで、両側の 2 か所をねじで止める）。"""
    base_y = cy + 30 * s
    r = 24 * s
    out = [line(cx - 92 * s, base_y + 3 * s, cx + 92 * s, base_y + 3 * s, INK, 4 * s)]
    for k in range(-8, 9):
        x = cx + k * 11 * s
        out.append(line(x, base_y + 5 * s, x - 8 * s, base_y + 13 * s, GRAY, 1.5 * s))
    out.append(circle(cx, base_y - r, r, LIGHT, GRAY, 2.5 * s))
    out.append(circle(cx, base_y - r, r - 6 * s, WHITE, GRAY, 1.5 * s))
    R = r + 5 * s
    d = (f"M{cx - 70 * s:.1f} {base_y - 3 * s:.1f} L {cx - R:.1f} {base_y - 3 * s:.1f} "
         f"L {cx - R:.1f} {base_y - r:.1f} A {R:.1f} {R:.1f} 0 0 1 {cx + R:.1f} {base_y - r:.1f} "
         f"L {cx + R:.1f} {base_y - 3 * s:.1f} L {cx + 70 * s:.1f} {base_y - 3 * s:.1f}")
    out.append(f'<path d="{d}" fill="none" stroke="{STEEL_D}" stroke-width="{6 * s:.1f}" stroke-linejoin="round"/>')
    for x in (cx - 50 * s, cx + 50 * s):
        out.append(rect(x - 5 * s, base_y - 14 * s, 10 * s, 12 * s, INK, INK, 1, 2))
    return "\n".join(out)


def mat_entrance_cap(cx, cy, s=1.0):
    """エントランスキャップ（管の端に付け、口を下に向けて雨水が入らないようにする）。"""
    out = [pipe_h(cx - 90 * s, cx - 10 * s, cy, 11 * s)]
    d = (f"M{cx - 14 * s:.1f} {cy - 16 * s:.1f} L {cx + 24 * s:.1f} {cy - 16 * s:.1f} "
         f"Q {cx + 50 * s:.1f} {cy - 16 * s:.1f} {cx + 50 * s:.1f} {cy + 12 * s:.1f} L {cx + 50 * s:.1f} {cy + 40 * s:.1f} "
         f"L {cx + 22 * s:.1f} {cy + 40 * s:.1f} L {cx + 22 * s:.1f} {cy + 16 * s:.1f} L {cx - 14 * s:.1f} {cy + 16 * s:.1f} Z")
    out.append(f'<path d="{d}" fill="#9AA3B5" stroke="{STEEL_D}" stroke-width="{2.5 * s:.1f}" stroke-linejoin="round"/>')
    out.append(base.arrow(cx + 36 * s, cy + 46 * s, cx + 36 * s, cy + 64 * s, BLUE, 2.5 * s, 8 * s))
    return "\n".join(out)


def mat_ring_sleeve(cx, cy, s=1.0):
    """リングスリーブ（小・中・大の短い筒）。"""
    out = []
    for dx, r in ((-58, 11), (0, 15), (60, 20)):
        x = cx + dx * s
        out.append(rect(x - r * s, cy - 24 * s, 2 * r * s, 48 * s, COPPER_L, COPPER, 2.5 * s, 3))
        out.append(f'<ellipse cx="{x:.1f}" cy="{cy - 24 * s:.1f}" rx="{r * s:.1f}" ry="{5 * s:.1f}" fill="{WHITE}" stroke="{COPPER}" stroke-width="{2.5 * s:.1f}"/>')
    return "\n".join(out)


def mat_push_connector(cx, cy, s=1.0):
    """差込形コネクタ（透明の箱に電線を差し込む穴）。"""
    out = [rect(cx - 56 * s, cy - 30 * s, 112 * s, 60 * s, "#DDEBFA", "#6F8FB8", 2.5 * s, 8 * s)]
    for k in range(4):
        x = cx + (k - 1.5) * 24 * s
        out.append(circle(x, cy - 8 * s, 7 * s, WHITE, "#6F8FB8", 2 * s))
        out.append(line(x, cy + 2 * s, x, cy + 20 * s, COPPER, 3 * s))
    return "\n".join(out)


def mat_crimp_terminal(cx, cy, s=1.0):
    """裸圧着端子（丸い舌と、電線を差す筒）。"""
    out = [circle(cx - 44 * s, cy, 24 * s, COPPER_L, COPPER, 2.5 * s), circle(cx - 44 * s, cy, 9 * s, WHITE, COPPER, 2.5 * s),
           rect(cx - 24 * s, cy - 9 * s, 26 * s, 18 * s, COPPER_L, COPPER, 2.5 * s, 2),
           rect(cx + 2 * s, cy - 14 * s, 44 * s, 28 * s, COPPER_L, COPPER, 2.5 * s, 4),
           line(cx + 46 * s, cy, cx + 90 * s, cy, COPPER, 8 * s)]
    return "\n".join(out)


def mat_outlet_box(cx, cy, s=1.0):
    """アウトレットボックス（四角い金属の箱。周りにノックアウトの丸）。"""
    w = 96 * s
    out = [rect(cx - w / 2, cy - w / 2 * 0.8, w, w * 0.8, STEEL, STEEL_D, 2.5 * s, 6),
           rect(cx - w / 2 + 10 * s, cy - w / 2 * 0.8 + 10 * s, w - 20 * s, w * 0.8 - 20 * s, "#D6DBE4", STEEL_D, 2 * s, 4)]
    for dx, dy in ((0, -1), (0, 1), (-1, 0), (1, 0)):
        out.append(circle(cx + dx * 30 * s, cy + dy * 22 * s, 8 * s, "#C7CDD8", STEEL_D, 2 * s))
    return "\n".join(out)


# ===========================================================================
# 工具（イメージ図）
# ===========================================================================
HANDLE = "#D8453A"
HANDLE_Y = "#F2C12E"


def grip(p0, p1, width, color):
    return line(p0[0], p0[1], p1[0], p1[1], color, width) + line(p0[0], p0[1], p1[0], p1[1], INK, 1.2)


def tool_pliers(cx, cy, s=1.0, crimper=False, stripper=False):
    """ペンチ系。crimper = 圧着ペンチ（黄色の柄、あごに 3 つのくぼみ）、stripper = ワイヤストリッパ（刃に穴の列）。"""
    out = []
    pivot = (cx - 20 * s, cy)
    color = HANDLE_Y if crimper else (BLUE if stripper else HANDLE)
    hl = 90 * s if crimper else 70 * s
    out.append(grip((pivot[0] + 14 * s, cy - 6 * s), (pivot[0] + hl, cy - 22 * s), 13 * s, color))
    out.append(grip((pivot[0] + 14 * s, cy + 6 * s), (pivot[0] + hl, cy + 22 * s), 13 * s, color))
    jaw = 48 * s if not crimper else 40 * s
    top = [(pivot[0] + 12 * s, cy - 8 * s), (pivot[0] - jaw * 0.3, cy - 13 * s), (pivot[0] - jaw, cy - 5 * s), (pivot[0] - jaw, cy), (pivot[0] + 12 * s, cy)]
    bottom = [(x, 2 * cy - y) for x, y in top]
    out.append(poly(top, INK, 2 * s, fill=STEEL, close=True))
    out.append(poly(bottom, INK, 2 * s, fill=STEEL, close=True))
    if crimper:
        for k in range(3):
            out.append(circle(pivot[0] - (8 + 11 * k) * s, cy, (3 + k) * s, WHITE, INK, 1.5 * s))
    if stripper:
        for k in range(4):
            out.append(circle(pivot[0] - (8 + 10 * k) * s, cy, (1.6 + 0.5 * k) * s, WHITE, INK, 1.2 * s))
    out.append(circle(*pivot, 7 * s, STEEL_D, INK, 2 * s))
    return "\n".join(out)


def tool_hacksaw(cx, cy, s=1.0):
    """金切りのこ（コの字の枠に細い刃を張る）。"""
    x0, x1, top, blade = cx - 70 * s, cx + 60 * s, cy - 32 * s, cy + 12 * s
    out = [poly([(x0, blade), (x0, top), (x1, top), (x1, blade)], INK, 5 * s),
           line(x0, blade, x1, blade, GRAY, 3 * s)]
    for x in frange(x0 + 4 * s, x1 - 4 * s, 6 * s):
        out.append(line(x, blade + 1.5 * s, x + 3 * s, blade + 5 * s, GRAY, 1.3 * s))
    out.append(rect(x1 - 4 * s, blade - 12 * s, 36 * s, 26 * s, HANDLE, INK, 2 * s, 8 * s))
    return "\n".join(out)


def tool_pipe_bender(cx, cy, s=1.0):
    """パイプベンダ（長い柄の先に、管を引っかける曲げ型）。"""
    out = [line(cx - 80 * s, cy + 40 * s, cx + 40 * s, cy - 30 * s, STEEL_D, 9 * s)]
    hx, hy = cx + 52 * s, cy - 38 * s
    out.append(f'<path d="M{hx - 24 * s:.1f} {hy + 10 * s:.1f} A {26 * s:.1f} {26 * s:.1f} 0 1 1 {hx + 20 * s:.1f} {hy + 18 * s:.1f}" '
               f'fill="none" stroke="{INK}" stroke-width="{9 * s:.1f}" stroke-linecap="round"/>')
    out.append(pipe_h(cx - 90 * s, cx + 90 * s, cy + 58 * s, 7 * s, LIGHT, GRAY, 2))
    return "\n".join(out)


def tool_click_ball(cx, cy, s=1.0):
    """クリックボール（クランク形の柄で、先にリーマを付けて回す）。"""
    pts = [(cx - 70 * s, cy), (cx - 40 * s, cy), (cx - 40 * s, cy - 36 * s), (cx + 20 * s, cy - 36 * s), (cx + 20 * s, cy), (cx + 44 * s, cy)]
    out = [poly(pts, STEEL_D, 6 * s)]
    out.append(f'<ellipse cx="{cx - 10 * s:.1f}" cy="{cy - 36 * s:.1f}" rx="{16 * s:.1f}" ry="{8 * s:.1f}" fill="{HANDLE}" stroke="{INK}" stroke-width="{2 * s:.1f}"/>')
    out.append(circle(cx - 78 * s, cy, 12 * s, HANDLE, INK, 2 * s))
    # 先のリーマ（円すい）
    out.append(poly([(cx + 44 * s, cy - 11 * s), (cx + 92 * s, cy), (cx + 44 * s, cy + 11 * s)], INK, 2 * s, fill=STEEL, close=True))
    for k in range(3):
        x = cx + (52 + 12 * k) * s
        out.append(line(x, cy - (9 - 2.5 * k) * s, x + 6 * s, cy + (9 - 2.5 * k) * s, STEEL_D, 1.3 * s))
    return "\n".join(out)


def tool_hole_saw(cx, cy, s=1.0):
    """ホルソ（のこ刃のついたカップと、中心のドリル）。"""
    x0, x1, y0, y1 = cx - 36 * s, cx + 36 * s, cy - 30 * s, cy + 26 * s
    out = [rect(x0, y0, x1 - x0, y1 - y0, STEEL, STEEL_D, 2.5 * s, 2)]
    teeth = []
    for k, x in enumerate(frange(x0, x1, 8 * s)):
        teeth += [(x, y1), (x + 4 * s, y1 + 8 * s)]
    out.append(poly(teeth + [(x1, y1)], STEEL_D, 2 * s))
    out.append(line(cx, y0 - 36 * s, cx, y0, STEEL_D, 7 * s))
    out.append(line(cx, y1, cx, y1 + 22 * s, INK, 4 * s))
    return "\n".join(out)


def tool_fish_tape(cx, cy, s=1.0):
    """呼び線挿入器（リールに巻いた鋼線。先を管に通す）。"""
    out = [circle(cx - 30 * s, cy, 44 * s, "#4A6FA5", INK, 2.5 * s), circle(cx - 30 * s, cy, 28 * s, WHITE, INK, 2 * s)]
    for r in (32, 36, 40):
        out.append(circle(cx - 30 * s, cy, r * s, "none", "#DDE4EE", 1.5 * s))
    out.append(f'<path d="M{cx + 10 * s:.1f} {cy + 20 * s:.1f} Q {cx + 50 * s:.1f} {cy + 40 * s:.1f} {cx + 90 * s:.1f} {cy + 30 * s:.1f}" '
               f'fill="none" stroke="{STEEL_D}" stroke-width="{3 * s:.1f}"/>')
    out.append(circle(cx + 92 * s, cy + 30 * s, 4 * s, STEEL_D, INK, 1.5 * s))
    return "\n".join(out)


def tool_cable_cutter(cx, cy, s=1.0):
    """ケーブルカッタ（長い柄、丸く湾曲した刃）。"""
    out = [grip((cx - 10 * s, cy - 6 * s), (cx + 90 * s, cy - 26 * s), 10 * s, HANDLE),
           grip((cx - 10 * s, cy + 6 * s), (cx + 90 * s, cy + 26 * s), 10 * s, HANDLE)]
    out.append(f'<path d="M{cx - 10 * s:.1f} {cy - 4 * s:.1f} Q {cx - 60 * s:.1f} {cy - 50 * s:.1f} {cx - 80 * s:.1f} {cy - 4 * s:.1f} '
               f'L {cx - 58 * s:.1f} {cy - 4 * s:.1f} Q {cx - 46 * s:.1f} {cy - 26 * s:.1f} {cx - 10 * s:.1f} {cy - 4 * s:.1f} Z" '
               f'fill="{STEEL}" stroke="{INK}" stroke-width="{2 * s:.1f}"/>')
    out.append(f'<path d="M{cx - 10 * s:.1f} {cy + 4 * s:.1f} Q {cx - 60 * s:.1f} {cy + 50 * s:.1f} {cx - 80 * s:.1f} {cy + 4 * s:.1f} '
               f'L {cx - 58 * s:.1f} {cy + 4 * s:.1f} Q {cx - 46 * s:.1f} {cy + 26 * s:.1f} {cx - 10 * s:.1f} {cy + 4 * s:.1f} Z" '
               f'fill="{STEEL}" stroke="{INK}" stroke-width="{2 * s:.1f}"/>')
    out.append(circle(cx - 10 * s, cy, 7 * s, STEEL_D, INK, 2 * s))
    return "\n".join(out)


def tool_screwdriver(cx, cy, s=1.0):
    """ドライバ（柄と、先がプラスの軸）。"""
    out = [rect(cx + 10 * s, cy - 14 * s, 70 * s, 28 * s, HANDLE, INK, 2 * s, 12 * s),
           line(cx - 80 * s, cy, cx + 10 * s, cy, STEEL_D, 7 * s),
           poly([(cx - 80 * s, cy - 4 * s), (cx - 92 * s, cy), (cx - 80 * s, cy + 4 * s)], INK, 1.5 * s, fill=STEEL_D, close=True)]
    return "\n".join(out)


def tool_torch(cx, cy, s=1.0):
    """ガストーチランプ（ボンベと火口。硬質ポリ塩化ビニル電線管をあぶって曲げる）。"""
    out = [rect(cx - 72 * s, cy - 18 * s, 60 * s, 52 * s, HANDLE, INK, 2 * s, 10 * s),
           rect(cx - 12 * s, cy - 8 * s, 28 * s, 16 * s, STEEL_D, INK, 2 * s, 3),
           line(cx + 16 * s, cy, cx + 58 * s, cy - 12 * s, STEEL_D, 7 * s)]
    flame = (f"M{cx + 60 * s:.1f} {cy - 18 * s:.1f} Q {cx + 96 * s:.1f} {cy - 30 * s:.1f} {cx + 94 * s:.1f} {cy - 16 * s:.1f} "
             f"Q {cx + 90 * s:.1f} {cy - 4 * s:.1f} {cx + 60 * s:.1f} {cy - 6 * s:.1f} Z")
    out.append(f'<path d="{flame}" fill="{ORANGE_L}" stroke="{ORANGE}" stroke-width="{2.5 * s:.1f}"/>')
    return "\n".join(out)


# ===========================================================================
# 機器（イメージ図）
# ===========================================================================
def dev_magnetic_starter(cx, cy, s=1.0):
    """電磁開閉器 = 上の電磁接触器（MC）＋ 下の熱動継電器（THR）。"""
    out = [rect(cx - 50 * s, cy - 62 * s, 100 * s, 64 * s, "#E4E7EE", INK, 2.5 * s, 6),
           rect(cx - 50 * s, cy + 6 * s, 100 * s, 50 * s, "#CFD5E0", INK, 2.5 * s, 6)]
    for k in range(3):
        x = cx + (k - 1) * 26 * s
        out.append(circle(x, cy - 50 * s, 5 * s, STEEL, INK, 1.5 * s))
        out.append(circle(x, cy + 46 * s, 5 * s, STEEL, INK, 1.5 * s))
    out.append(text("MC", cx, cy - 26 * s, 20 * s, INK, "middle", 1.1))
    out.append(text("THR", cx - 8 * s, cy + 26 * s, 16 * s, INK, "middle", 1.1))
    out.append(circle(cx + 36 * s, cy + 26 * s, 7 * s, RED, INK, 2 * s))
    return "\n".join(out)


def capacitor(cx, cy, s=1.0, vertical=True):
    if vertical:
        return (line(cx - 16 * s, cy - 5 * s, cx + 16 * s, cy - 5 * s, INK, 3.5 * s)
                + line(cx - 16 * s, cy + 5 * s, cx + 16 * s, cy + 5 * s, INK, 3.5 * s))
    return (line(cx - 5 * s, cy - 16 * s, cx - 5 * s, cy + 16 * s, INK, 3.5 * s)
            + line(cx + 5 * s, cy - 16 * s, cx + 5 * s, cy + 16 * s, INK, 3.5 * s))


# ===========================================================================
# タイル（imageChoice の選択肢）と一覧図
# ===========================================================================
figures = {}


def tile(name, body, w=TW, h=TH):
    figures[name] = svg(body, w, h)


C = (TW / 2, TH / 2)

# --- S01 スイッチ
tile("sym_switch", switch_sym(90, 78, 1.4))
for lab, key in (("3", "3way"), ("4", "4way"), ("H", "H"), ("L", "L"), ("P", "P"), ("A", "A"),
                 ("RAS", "RAS"), ("D", "D"), ("WP", "WP"), ("2P", "2P"), ("R", "R"), ("T", "T")):
    tile(f"sym_switch_{key}", switch_sym(80, 86, 1.4, lab))
tile("sym_dimmer", switch_sym(95, 78, 1.4, dimmer=True))

# --- S01 コンセント
tile("sym_outlet", outlet_sym(100, 75, 1.4))
for labels, key in ((["2"], "2"), (["3"], "3"), (["E"], "E"), (["ET"], "ET"), (["EET"], "EET"), (["EL"], "EL"),
                    (["LK"], "LK"), (["T"], "T"), (["WP"], "WP"), (["20A"], "20A"), (["250V"], "250V"),
                    (["E", "20A", "250V"], "E_20A_250V"), (["WP", "LK"], "WP_LK")):
    tile(f"sym_outlet_{key}", outlet_sym(70, 75 if len(labels) < 3 else 70, 1.4, labels))

# --- S01 照明
tile("sym_light", light_sym(100, 75, 1.5))
for lab in ("CL", "CH", "DL"):
    tile(f"sym_light_{lab}", light_sym(78, 80, 1.5, lab))
tile("sym_pendant", pendant_sym(100, 75, 1.5))
tile("sym_bracket", bracket_sym(108, 75, 1.4))
tile("sym_fluorescent", fluorescent_sym(100, 75, 1.2))
tile("sym_fan", fan_sym(100, 75, 1.5))

# --- S02 機器・盤・計器
tile("sym_panel", panel_sym(100, 75, 1.5))
for lab, key in (("S", "kaiheiki"), ("B", "breaker"), ("E", "elcb"), ("BE", "elcb_oc")):
    tile(f"sym_{key}", boxed(100, 75, 1.5, lab, 56 if len(lab) > 1 else 46))
tile("sym_meter_wh", circled_letter(100, 75, 1.5, "Wh", 24))
tile("sym_motor", circled_letter(100, 75, 1.5, "M"))
tile("sym_heater", circled_letter(100, 75, 1.5, "H"))
tile("sym_ammeter", circled_letter(100, 75, 1.5, "A"))
tile("sym_voltmeter", circled_letter(100, 75, 1.5, "V"))
tile("sym_aircon_I", aircon_sym(86, 80, 1.3, "I"))
tile("sym_aircon_O", aircon_sym(86, 80, 1.3, "O"))
tile("sym_earth", earth_sym(100, 80, 1.5))
tile("sym_pushbutton", pushbutton_sym(100, 75, 1.6))
for kind in ("ceiling", "floor", "exposed", "underground"):
    tile(f"sym_line_{kind}", wiring_line(28, 172, 75, kind, 1.2))

# --- S03 刃受けと接点
for kind in ("15A125V", "15A125V_E", "20A125V", "15A250V", "15A250V_E", "twist"):
    tile(f"face_{kind}", outlet_face(100, 75, kind, 1.25))
for kind in ("single", "2p", "3way", "4way"):
    tile(f"cont_{kind}", contact(100, 78, kind, 1.25))

# --- S05 ケーブルの断面
for kind in ("IV", "VVF2", "VVF3", "VVR", "CV"):
    tile(f"cab_{kind}", cable(100, 75, kind, 1.3 if kind in ("IV", "VVF2", "VVF3") else 1.4))

# --- S06 材料
for name, fn in (("normal_bend", mat_normal_bend), ("coupling", mat_coupling), ("bushing", mat_bushing),
                 ("locknut", mat_locknut), ("saddle", mat_saddle), ("entrance_cap", mat_entrance_cap),
                 ("ring_sleeve", mat_ring_sleeve), ("push_connector", mat_push_connector),
                 ("crimp_terminal", mat_crimp_terminal), ("outlet_box", mat_outlet_box)):
    tile(f"mat_{name}", fn(100, 75, 1.0))

# --- S07 工具
tile("tool_pliers", tool_pliers(100, 75, 1.0))
tile("tool_crimper", tool_pliers(90, 75, 1.0, crimper=True))
tile("tool_stripper", tool_pliers(100, 75, 1.0, stripper=True))
for name, fn in (("hacksaw", tool_hacksaw), ("pipe_bender", tool_pipe_bender), ("click_ball", tool_click_ball),
                 ("hole_saw", tool_hole_saw), ("fish_tape", tool_fish_tape), ("cable_cutter", tool_cable_cutter),
                 ("screwdriver", tool_screwdriver), ("torch", tool_torch)):
    tile(f"tool_{name}", fn(100, 75, 1.0))

# --- S04 機器
tile("dev_magnetic_starter", dev_magnetic_starter(100, 75, 1.0))


# ---------------------------------------------------------------------------
# 一覧図（教材の画面用）。日本語は本文の表で説明する。
# ---------------------------------------------------------------------------
def sheet(cells, cols, cw, ch, s, top=0, left=0):
    """cells = [(描く関数, 追加の引数)]。格子に並べる。"""
    out = []
    for i, (fn, kw) in enumerate(cells):
        r, c = divmod(i, cols)
        cx = left + cw * (c + 0.5)
        cy = top + ch * (r + 0.5)
        out.append(fn(cx, cy, s=s, **kw))
        if c > 0:
            out.append(line(left + cw * c, top + 12, left + cw * c, top + ch * (r + 1) - 12, LINE, 1.5))
    return "\n".join(out)


def number_badge(n, x, y):
    return circle(x, y, 11, YEL_L, YEL, 2) + text(str(n), x, y, 12, YEL, "middle", 1.1)


def numbered(cells, cols, cw, ch, s, w, h):
    out = [sheet(cells, cols, cw, ch, s)]
    for i in range(len(cells)):
        r, c = divmod(i, cols)
        out.append(number_badge(i + 1, cw * c + 16, ch * r + 16))
    return svg("\n".join(out), w, h)


figures["S01_light_symbols"] = numbered(
    [(light_sym, {}), (pendant_sym, {}), (light_sym, {"label": "CL"}), (light_sym, {"label": "DL"}),
     (bracket_sym, {}), (fluorescent_sym, {}), (fan_sym, {}), (light_sym, {"label": "CH"})],
    4, 105, 110, 0.9, 420, 220)
figures["S01_switch_symbols"] = numbered(
    [(switch_sym, {}), (switch_sym, {"label": "3"}), (switch_sym, {"label": "4"}), (switch_sym, {"label": "H"}),
     (switch_sym, {"label": "L"}), (switch_sym, {"label": "P"}), (switch_sym, {"label": "A"}), (switch_sym, {"dimmer": True})],
    4, 105, 100, 1.0, 420, 200)
figures["S01_outlet_symbols"] = numbered(
    [(outlet_sym, {}), (outlet_sym, {"labels": ["2"]}), (outlet_sym, {"labels": ["E"]}), (outlet_sym, {"labels": ["ET"]}),
     (outlet_sym, {"labels": ["EL"]}), (outlet_sym, {"labels": ["LK"]}), (outlet_sym, {"labels": ["WP"]}),
     (outlet_sym, {"labels": ["T"]})],
    4, 105, 100, 0.9, 420, 200)
figures["S02_panel_symbols"] = numbered(
    [(panel_sym, {}), (lambda x, y, s: boxed(x, y, s, "S"), {}), (lambda x, y, s: boxed(x, y, s, "B"), {}),
     (lambda x, y, s: boxed(x, y, s, "E"), {}), (lambda x, y, s: circled_letter(x, y, s, "Wh", 24), {}),
     (lambda x, y, s: circled_letter(x, y, s, "M"), {}), (lambda x, y, s: circled_letter(x, y, s, "H"), {}),
     (earth_sym, {})],
    4, 105, 100, 0.95, 420, 200)


def f_lines():
    out = []
    for i, kind in enumerate(("ceiling", "floor", "exposed", "underground")):
        y = 34 + i * 48
        out.append(number_badge(i + 1, 26, y))
        out.append(wiring_line(56, 396, y, kind, 1.0))
    return svg("\n".join(out), 420, 214)


figures["S02_wiring_lines"] = f_lines()
figures["S03_outlet_faces"] = numbered(
    [(outlet_face, {"kind": k}) for k in ("15A125V", "15A125V_E", "20A125V", "15A250V")], 4, 105, 130, 0.78, 420, 130)
figures["S03_switch_contacts"] = numbered(
    [(contact, {"kind": k}) for k in ("single", "3way", "4way", "2p")], 2, 210, 120, 1.0, 420, 240)
figures["S05_cable_sections"] = numbered(
    [(cable, {"kind": k}) for k in ("IV", "VVF2", "VVR", "CV")], 4, 105, 120, 0.85, 420, 120)
figures["S06_materials"] = numbered(
    [(mat_normal_bend, {}), (mat_coupling, {}), (mat_bushing, {}), (mat_locknut, {}),
     (mat_saddle, {}), (mat_entrance_cap, {}), (mat_ring_sleeve, {}), (mat_push_connector, {})],
    4, 105, 100, 0.5, 420, 200)
figures["S07_tools"] = numbered(
    [(tool_pliers, {}), (tool_pliers, {"crimper": True}), (tool_pliers, {"stripper": True}), (tool_hacksaw, {}),
     (tool_pipe_bender, {}), (tool_click_ball, {}), (tool_hole_saw, {}), (tool_fish_tape, {})],
    4, 105, 100, 0.5, 420, 200)


def f_sync_speed():
    out = [base.formula([("N", INK), ("=", GRAY), ("120", RED), ("×", GRAY), ("f", BLUE), ("÷", GRAY), ("p", GREEN)], 210, 40, 26)]
    out.append(circled_letter(90, 140, 1.6, "M"))
    for k in range(3):
        a = -math.pi / 2 + k * math.tau / 3
        out.append(base.arrow(90 + 44 * math.cos(a), 140 + 44 * math.sin(a), 90 + 44 * math.cos(a + 0.9),
                              140 + 44 * math.sin(a + 0.9), ORANGE, 3, 9))
    out.append(base.formula([("120", RED), ("×", GRAY), ("60", BLUE), ("÷", GRAY), ("4", GREEN), ("=", GRAY), ("1800", INK)], 290, 120, 18))
    out.append(base.formula([("120", RED), ("×", GRAY), ("50", BLUE), ("÷", GRAY), ("4", GREEN), ("=", GRAY), ("1500", INK)], 290, 164, 18))
    return svg("\n".join(out), 420, 220)


figures["S04_sync_speed"] = f_sync_speed()


def f_capacitor():
    """三相誘導電動機と、並列に入れた進相コンデンサ（3 個を Δ につないだもの）。"""
    out = []
    xs = (70, 110, 150)
    for x in xs:
        out.append(line(x, 20, x, 150 if x != 110 else 164, INK, 3))
        out.append(dot(x, 60 + (x - 70) * 0.5, 4.5))
    out.append(poly([(70, 150), (100, 170)], INK, 3) + poly([(150, 150), (120, 170)], INK, 3))
    out.append(circled_letter(110, 188, 1.1, "M"))
    # 分岐してコンデンサへ
    taps = [(70, 60), (110, 80), (150, 100)]
    ends = [(250, 60), (310, 80), (370, 100)]
    for (x, y), (ex, ey) in zip(taps, ends):
        out.append(line(x, y, ex, y, INK, 2.5))
    # Δ につないだ 3 個のコンデンサ（頂点に 1 相ずつ）
    apex, left_c, right_c = (310, 110), (250, 196), (370, 196)
    out.append(poly([(250, 60), left_c], INK, 2.5) + poly([(310, 80), apex], INK, 2.5) + poly([(370, 100), right_c], INK, 2.5))
    for p, q in ((apex, left_c), (apex, right_c), (left_c, right_c)):
        mx, my = (p[0] + q[0]) / 2, (p[1] + q[1]) / 2
        ang = math.atan2(q[1] - p[1], q[0] - p[0])
        ux, uy = math.cos(ang), math.sin(ang)
        g = 6
        out.append(line(p[0], p[1], mx - ux * g, my - uy * g, INK, 2.5))
        out.append(line(mx + ux * g, my + uy * g, q[0], q[1], INK, 2.5))
        nx, ny = -uy, ux
        for sgn in (-1, 1):
            px, py = mx + sgn * ux * g, my + sgn * uy * g
            out.append(line(px - nx * 15, py - ny * 15, px + nx * 15, py + ny * 15, ORANGE, 3.5))
    out.append(dot(*apex, 4.5) + dot(*left_c, 4.5) + dot(*right_c, 4.5))
    return svg("\n".join(out), 420, 240)


figures["S04_capacitor"] = f_capacitor()


# ---------------------------------------------------------------------------
def write_assets():
    FIG.mkdir(parents=True, exist_ok=True)
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
        cairosvg.svg2png(bytestring=body.encode("utf-8"), write_to=str(out / f"{name}.png"), scale=2)
    print(f"プレビュー {len(figures)} 枚: {out}")


if __name__ == "__main__":
    if len(sys.argv) >= 3 and sys.argv[1] == "--preview":
        write_preview(sys.argv[2])
    else:
        write_assets()
