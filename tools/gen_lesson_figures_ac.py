#!/usr/bin/env python3
"""教材 F09〜F12（交流・磁気・インピーダンス・三相）の図（SVG）を生成して
Assets.xcassets/Figures/<name>.imageset に置く。

文字の描き方・色の決まり・部品は tools/gen_lesson_figures.py と共通（そちらを import する）。
  電流 = 青、電圧 = 赤、電力・熱 = 橙、抵抗・配線 = 紺、補助線 = 灰、磁界 = 緑
数値は教材テキスト（content/lessons/F09〜F12.md）の例題とそろえてある。
<text> は使わず、文字も線で描く。日本語は図に入れない。

再生成: python3 tools/gen_lesson_figures_ac.py
確認用の PNG（任意）: python3 tools/gen_lesson_figures_ac.py --preview <出力フォルダ>
"""
import json
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from gen_lesson_figures import *  # noqa: E402,F401,F403
from gen_lesson_figures import FIG, W, H  # noqa: E402

ac_figures = {}   # 名前 → (SVG, 幅)


def add(name, body, w=W, h=H):
    ac_figures[name] = (svg(body, w, h), w)


# ---------------------------------------------------------------------------
# 部品
# ---------------------------------------------------------------------------
def wave_pts(x0, x1, ymid, amp, period, phase_deg=0.0, n=160):
    """正弦波の点列。x0 で位相 phase_deg（度）から始まる。上が正。"""
    pts = []
    for k in range(n + 1):
        x = x0 + (x1 - x0) * k / n
        ang = 2 * math.pi * (x - x0) / period + math.radians(phase_deg)
        pts.append((x, ymid - amp * math.sin(ang)))
    return pts


def wave(x0, x1, ymid, amp, period, phase_deg=0.0, color=RED, w=3, dash=None):
    return poly(wave_pts(x0, x1, ymid, amp, period, phase_deg), color, w, dash=dash)


def axes(x0, x1, ymid, ytop, ybot, tlabel="t", vlabel=None, vcolor=RED):
    """時間軸（右向きの矢印）と縦軸。"""
    out = [arrow(x0, ymid, x1, ymid, GRAY, 2, 9), line(x0, ybot, x0, ytop + 6, GRAY, 2),
           poly([(x0 - 4.5, ytop + 8), (x0, ytop), (x0 + 4.5, ytop + 8)], GRAY, 1, fill=GRAY, close=True)]
    if tlabel:
        out.append(text(tlabel, x1 - 2, ymid + 16, 12, GRAY))
    if vlabel:
        out.append(text(vlabel, x0 + 10, ytop + 4, 12, vcolor, "start"))
    return "\n".join(out)


def coil_h(x0, x1, cy, half, n, color=INK):
    """横向きのコイル（ばねを横から見た形）。前の線は実線、後ろの線は灰の点線。
    左下から入り、前の線で上から下へ流れる巻き方（右ねじで右端が N）。"""
    p = (x1 - x0) / n
    back, front = [], []
    for i in range(n):
        xs = x0 + i * p
        back.append(line(xs, cy + half, xs + p / 2, cy - half, GRAY, 2, dash="3,4"))
        front.append(line(xs + p / 2, cy - half, xs + p, cy + half, color, 3))
    return "\n".join(back), "\n".join(front), p


def coil_sym(x, y, n=4, r=6, vertical=False, color=INK):
    """回路図のコイル（半円の山を n 個）。横なら (x, y) から右へ、縦なら下へ。"""
    if vertical:
        d = f"M{x:.1f} {y:.1f} " + " ".join(f"a {r} {r} 0 0 1 0 {2 * r}" for _ in range(n))
    else:
        d = f"M{x:.1f} {y:.1f} " + " ".join(f"a {r} {r} 0 0 1 {2 * r} 0" for _ in range(n))
    return f'<path d="{d}" fill="none" stroke="{color}" stroke-width="3" stroke-linecap="round"/>'


def cap_sym(cx, cy, vertical=False, gap=6, plate=14, color=INK):
    """コンデンサ（2 枚の板）。横向きの線の途中に置くときは vertical=False（板は縦）。"""
    if vertical:
        return (line(cx - plate, cy - gap, cx + plate, cy - gap, color, 3.5)
                + line(cx - plate, cy + gap, cx + plate, cy + gap, color, 3.5))
    return (line(cx - gap, cy - plate, cx - gap, cy + plate, color, 3.5)
            + line(cx + gap, cy - plate, cx + gap, cy + plate, color, 3.5))


def dot_out(cx, cy, r=13, color=BLUE):
    """⊙ 電流が手前に出てくる。"""
    return circle(cx, cy, r, WHITE, color, 3) + dot(cx, cy, 4, color)


def cross_in(cx, cy, r=13, color=BLUE):
    """⊗ 電流が奥へ入っていく。"""
    s = r * 0.62
    return (circle(cx, cy, r, WHITE, color, 3) + line(cx - s, cy - s, cx + s, cy + s, color, 3)
            + line(cx - s, cy + s, cx + s, cy - s, color, 3))


def tag(letter, cx, cy, r=12):
    return circle(cx, cy, r, YEL_L, YEL, 2.5) + text(letter, cx, cy, 13, YEL, bold=1.1)


def right_triangle(x0, y0, bw, vh, fill=LIGHT, stroke=INK, base_color=INK, vert_color=INK, hyp_color=INK,
                   up=True, hyp_dash=None):
    """直角三角形。(x0, y0) が θ の角、底辺 bw、縦 vh（up なら上向き）。"""
    x1 = x0 + bw
    y1 = y0 - vh if up else y0 + vh
    out = [poly([(x0, y0), (x1, y0), (x1, y1)], stroke, 0.1, fill=fill, close=True),
           line(x0, y0, x1, y0, base_color, 4), line(x1, y0, x1, y1, vert_color, 4),
           line(x0, y0, x1, y1, hyp_color, 4, dash=hyp_dash)]
    s = 12 if up else -12
    out.append(poly([(x1 - 12, y0), (x1 - 12, y0 - s), (x1, y0 - s)], GRAY, 1.5))
    # θ の弧
    ang = math.atan2(vh, bw)
    r = 34
    ex, ey = x0 + r * math.cos(ang), (y0 - r * math.sin(ang)) if up else (y0 + r * math.sin(ang))
    sweep = 0 if up else 1
    out.append(f'<path d="M{x0 + r:.1f} {y0:.1f} A {r} {r} 0 0 {sweep} {ex:.1f} {ey:.1f}" fill="none" '
               f'stroke="{GRAY}" stroke-width="2"/>')
    ta = ang / 2
    tx = x0 + (r + 13) * math.cos(ta)
    ty = y0 - (r + 13) * math.sin(ta) if up else y0 + (r + 13) * math.sin(ta)
    out.append(text("θ", tx, ty, 13, GRAY))
    return "\n".join(out), (x1, y1)


# ===========================================================================
# F09 交流の基礎
# ===========================================================================
def f09_dc_ac():
    out = []
    ymid, amp = 118, 52
    for px, kind in ((20, "DC"), (222, "AC")):
        x0, x1 = px + 16, px + 184
        out.append(rect(px, 14, 178, 212, WHITE, LINE, 2, 12))
        out.append(text(kind, px + 89, 34, 16, INK, bold=1.1))
        out.append(axes(x0, x1, ymid, 52, 184, "t"))
        out.append(text("+", x0 - 8, ymid - amp, 10, GRAY, "end"))
        out.append(text("−", x0 - 8, ymid + amp, 10, GRAY, "end"))
        if kind == "DC":
            out.append(line(x0, ymid - amp, x1 - 14, ymid - amp, RED, 3.5))
            for k in range(4):
                cx = x0 + 22 + k * 40
                out.append(arrow(cx - 11, 206, cx + 11, 206, BLUE, 3, 9))
        else:
            period = 80
            out.append(wave(x0, x0 + 2 * period, ymid, amp, period, 0, RED, 3.5))
            for k in range(4):
                cx = x0 + 20 + k * 40
                if k % 2 == 0:
                    out.append(arrow(cx - 11, 206, cx + 11, 206, BLUE, 3, 9))
                else:
                    out.append(arrow(cx + 11, 206, cx - 11, 206, BLUE, 3, 9))
    return "\n".join(out)


add("F09_dc_ac", f09_dc_ac())


def f09_period():
    """50Hz の交流。周期 T = 1/50 = 0.02s = 20ms。"""
    out = []
    x0, ymid, amp, period = 46, 100, 56, 140
    out.append(axes(x0, 400, ymid, 26, 170, "t"))
    out.append(wave(x0, x0 + 2 * period, ymid, amp, period, 0, RED, 3.5))
    y = 186
    out.append(line(x0, ymid, x0, y + 6, GRAY, 1.5, dash="4,4"))
    out.append(line(x0 + period, ymid, x0 + period, y + 6, GRAY, 1.5, dash="4,4"))
    out.append(span_h(x0, x0 + period, y, "T = 20ms", BLUE, 13, above=False))
    out.append(pill(362, 40, "f = 50Hz", INK, LIGHT, 13))
    out.append(formula([("T", BLUE), ("=", GRAY), ("1", INK), ("÷", GRAY), ("50", INK), ("=", GRAY),
                        ("0.02s", BLUE), ("=", GRAY), ("20ms", BLUE)], 210, 232, 14))
    return "\n".join(out)


add("F09_period", f09_period(), W, 252)


def f09_peak_rms():
    """実効値 100V の交流。最大値は 100 × √2 ≒ 141V。"""
    out = []
    x0, ymid, amp, period = 44, 128, 92, 170
    out.append(axes(x0, 312, ymid, 22, 232, "t"))
    out.append(wave(x0, x0 + 1.5 * period, ymid, amp, period, 0, RED, 3.5))
    y_max = ymid - amp
    y_rms = ymid - amp / math.sqrt(2)
    out.append(line(x0, y_max, 300, y_max, RED, 2, dash="6,5"))
    out.append(line(x0, y_rms, 300, y_rms, RED, 1.5, dash="2,6"))
    out.append(formula([("V_m", RED), ("=", GRAY), ("141V", RED)], 306, y_max, 13, "start", 1.1))
    out.append(formula([("V", RED), ("=", GRAY), ("100V", RED)], 306, y_rms + 4, 13, "start"))
    out.append(formula([("141", RED), ("÷", GRAY), ("√2", INK), ("≒", GRAY), ("100", RED)], 330, 180, 13))
    out.append(formula([("100", RED), ("×", GRAY), ("√2", INK), ("≒", GRAY), ("141", RED)], 330, 210, 13))
    return "\n".join(out)


add("F09_peak_rms", f09_peak_rms(), W, 250)


def f09_phase():
    """電流 i が電圧 v より 90° 遅れる。1 周期 = 360°。"""
    out = []
    x0, ymid, period = 46, 128, 200
    out.append(axes(x0, 404, ymid, 40, 214, "t"))
    out.append(wave(x0, x0 + 1.75 * period, ymid, 72, period, 0, RED, 3.5))
    out.append(wave(x0, x0 + 1.75 * period, ymid, 50, period, -90, BLUE, 3.5))
    pv, pi = x0 + period / 4, x0 + period / 2
    out.append(line(pv, ymid - 72, pv, ymid, GRAY, 1.5, dash="4,4"))
    out.append(line(pi, ymid - 50, pi, ymid, GRAY, 1.5, dash="4,4"))
    out.append(arrow(pv, ymid - 84, pi, ymid - 84, BLUE, 2.5, 8))
    out.append(line(pv, ymid - 90, pv, ymid - 78, BLUE, 2))
    out.append(text("90°", (pv + pi) / 2, ymid - 100, 13, BLUE, bold=1.1))
    out.append(text("v", x0 + 20, ymid - 74, 14, RED, bold=1.1))
    out.append(text("i", pi + 22, ymid - 58, 14, BLUE, bold=1.1))
    out.append(span_h(x0, x0 + period, 232, "360°", GRAY, 12, above=False))
    return "\n".join(out)


add("F09_phase", f09_phase(), W, 256)


# ===========================================================================
# F10 磁気と電磁誘導
# ===========================================================================
def f10_right_screw():
    out = []
    # 左：上向きの電流と、まわりの磁界（上から見て反時計回り）
    cx, cy, rx, ry = 104, 126, 64, 20
    out.append(f'<path d="M{cx - rx} {cy} A {rx} {ry} 0 0 1 {cx + rx} {cy}" fill="none" stroke="{GREEN}" '
               f'stroke-width="3"/>')
    out.append(flow(cx - 34, cy - ry * 0.847, "l", GREEN, 9))
    out.append(line(cx, 222, cx, 50, INK, 5))
    out.append(arrow(cx, 90, cx, 34, BLUE, 4, 13))
    out.append(text("I", cx + 18, 44, 15, BLUE, bold=1.1))
    out.append(f'<path d="M{cx - rx} {cy} A {rx} {ry} 0 0 0 {cx + rx} {cy}" fill="none" stroke="{GREEN}" '
               f'stroke-width="3"/>')
    out.append(flow(cx + 34, cy + ry * 0.847, "r", GREEN, 9))
    out.append(line(214, 20, 214, 224, LINE, 2))
    # 右：真上から見た図
    for x, kind in ((278, "out"), (368, "in")):
        y, r = 120, 36
        out.append(circle(x, y, r, "none", GREEN, 3))
        out.append(dot_out(x, y) if kind == "out" else cross_in(x, y))
        if kind == "out":   # 反時計回り：上は左向き、下は右向き
            out.append(flow(x, y - r, "l", GREEN, 9))
            out.append(flow(x, y + r, "r", GREEN, 9))
        else:               # 時計回り
            out.append(flow(x, y - r, "r", GREEN, 9))
            out.append(flow(x, y + r, "l", GREEN, 9))
        out.append(text("I", x, y + r + 26, 13, BLUE))
    return "\n".join(out)


add("F10_right_screw", f10_right_screw())


def f10_coil():
    """電磁石。前の線で上から下へ流れる巻き方なので、右端が N。"""
    out = []
    x0, x1, cy, half = 118, 302, 104, 38
    # 磁界（外側は N → S）
    out.append(f'<path d="M322 {cy - 8} C 360 -6, 60 -6, 98 {cy - 8}" fill="none" stroke="{GREEN}" '
               f'stroke-width="2.5" stroke-dasharray="7,5"/>')
    out.append(flow(210, 20, "l", GREEN, 9))
    back, front, p = coil_h(x0, x1, cy, half, 6)
    out.append(back)
    out.append(rect(96, cy - 16, 228, 32, LIGHT, GRAY, 2.5, 4))
    out.append(arrow(150, cy, 270, cy, GREEN, 3, 11))
    out.append(front)
    for i in range(6):
        xm = x0 + i * p + p * 0.75
        out.append(flow(xm, cy + half / 2, "d", BLUE, 8))
    out.append(text("S", 76, cy, 22, INK, bold=1.2))
    out.append(text("N", 344, cy, 22, INK, bold=1.2))
    # 電池へのリード線（+ から左端へ）
    by = 204
    out.append(wires([(x0, cy + half), (x0, by), (204, by)], [(216, by), (x1, by), (x1, cy + half)]))
    out.append(battery(210, by, False))
    out.append(flow(160, by, "l", BLUE, 9))
    out.append(flow(262, by, "l", BLUE, 9))
    out.append(text("I", 160, by + 18, 13, BLUE))
    return "\n".join(out)


add("F10_coil", f10_coil(), W, 234)


def f10_motor_force():
    """磁界（左 N → 右 S）の中で、奥へ流れる電流 ⊗ は下向きに押される。"""
    out = []
    out.append(rect(24, 50, 76, 140, RED_L, INK, 3, 6))
    out.append(rect(320, 50, 76, 140, BLUE_L, INK, 3, 6))
    out.append(text("N", 62, 120, 26, INK, bold=1.2))
    out.append(text("S", 358, 120, 26, INK, bold=1.2))
    for y in (78, 120, 162):
        out.append(line(108, y, 186, y, GREEN, 3))
        out.append(arrow(234, y, 312, y, GREEN, 3, 11))
    out.append(cross_in(210, 120, 16))
    out.append(text("I", 240, 102, 15, BLUE, bold=1.1))
    out.append(arrow(210, 140, 210, 222, ORANGE, 5, 15))
    out.append(text("F", 232, 206, 16, ORANGE, bold=1.2))
    return "\n".join(out)


add("F10_motor_force", f10_motor_force())


def f10_induction():
    """棒磁石をコイルに近づけると、検流計の針がふれる。"""
    out = []
    x0, x1, cy, half = 70, 214, 96, 40
    back, front, _ = coil_h(x0, x1, cy, half, 6)
    out.append(back)
    out.append(front)
    gx, gy = 142, 196
    out.append(wires([(x0, cy + half), (x0, gy), (gx - 26, gy)], [(gx + 26, gy), (x1, gy), (x1, cy + half)]))
    out.append(circle(gx, gy, 26))
    out.append(f'<path d="M{gx - 17} {gy + 4} A 18 18 0 0 1 {gx + 17} {gy + 4}" fill="none" stroke="{GRAY}" '
               f'stroke-width="2"/>')
    out.append(line(gx, gy + 12, gx - 12, gy - 12, RED, 3))
    out.append(dot(gx, gy + 12, 3.5, INK))
    out.append(text("G", gx + 40, gy, 13, INK, "start"))
    out.append(flow(96, gy, "r", BLUE, 9))
    # 棒磁石（N を左＝コイル側）
    out.append(rect(262, cy - 18, 64, 36, RED_L, INK, 3, 3))
    out.append(rect(326, cy - 18, 64, 36, BLUE_L, INK, 3, 3))
    out.append(text("N", 294, cy, 18, INK, bold=1.2))
    out.append(text("S", 358, cy, 18, INK, bold=1.2))
    out.append(arrow(350, cy - 40, 280, cy - 40, GRAY, 3.5, 12))
    return "\n".join(out)


add("F10_induction", f10_induction(), W, 236)


def f10_transformer():
    """柱上変圧器の例：6600V → 100V（巻数比 66）。二次 66A のとき一次 1A。"""
    out = []
    # 鉄心
    out.append(rect(140, 50, 140, 140, LIGHT, GRAY, 3, 6))
    out.append(rect(170, 80, 80, 80, WHITE, GRAY, 3, 3))
    # 一次（左の脚、巻数多め）
    ys1 = [68 + 16 * k for k in range(7)]
    out.append(wires([(134, ys1[0]), (70, ys1[0]), (70, 103)], [(70, 137), (70, ys1[-1]), (134, ys1[-1])]))
    out.append(ac(70, 120, 17))
    for y in ys1:
        out.append(line(134, y, 176, y + 8, INK, 3))
    # 二次（右の脚、巻数少なめ）
    ys2 = [100, 118, 136]
    out.append(wires([(286, ys2[0] + 8), (360, ys2[0] + 8), (360, 114)], [(286, ys2[-1] + 8), (360, ys2[-1] + 8), (360, 138)]))
    for y in ys2:
        out.append(line(244, y, 286, y + 8, INK, 3))
    out.append(res(360, 126, True, 24, 20))
    # ラベル
    out.append(text("6600V", 70, 186, 13, RED, bold=1.1))
    out.append(text("100V", 360, 168, 13, RED, bold=1.1))
    out.append(flow(104, ys1[0], "r", BLUE, 9))
    out.append(text("1A", 104, ys1[0] - 16, 12, BLUE))
    out.append(flow(326, ys2[0] + 8, "r", BLUE, 9))
    out.append(text("66A", 326, ys2[0] - 8, 12, BLUE))
    out.append(text("N_1", 155, 212, 14, INK))
    out.append(text("N_2", 265, 212, 14, INK))
    out.append(formula([("V_1", RED), (":", GRAY), ("V_2", RED), ("=", GRAY), ("N_1", INK), (":", GRAY), ("N_2", INK),
                        ("=", GRAY), ("66", INK), (":", GRAY), ("1", INK)], 210, 244, 15))
    return "\n".join(out)


add("F10_transformer", f10_transformer(), W, 262)


# ===========================================================================
# F11 交流回路とインピーダンス
# ===========================================================================
def f11_phase_rlc():
    """R は同相、L は電流が 90° 遅れ、C は電流が 90° 進む。"""
    out = []
    for k, kind in enumerate(("R", "L", "C")):
        px = 10 + k * 136
        out.append(rect(px, 12, 128, 220, WHITE, LINE, 2, 12))
        cx = px + 64
        # 記号
        if kind == "R":
            out.append(line(px + 20, 42, px + 108, 42, INK, 3))
            out.append(res(cx, 42, False, 42, 16))
        elif kind == "L":
            out.append(line(px + 20, 42, cx - 24, 42, INK, 3))
            out.append(line(cx + 24, 42, px + 108, 42, INK, 3))
            out.append(coil_sym(cx - 24, 42, 4, 6))
        else:
            out.append(line(px + 20, 42, cx - 6, 42, INK, 3))
            out.append(line(cx + 6, 42, px + 108, 42, INK, 3))
            out.append(cap_sym(cx, 42))
        out.append(text(kind, cx, 76, 16, INK, bold=1.2))
        # 波形
        x0, ymid, period = px + 12, 150, 96
        out.append(line(x0, ymid, px + 118, ymid, GRAY, 1.5))
        shift = {"R": 0, "L": -90, "C": 90}[kind]
        out.append(wave(x0, x0 + 1.1 * period, ymid, 40, period, 0, RED, 3))
        out.append(wave(x0, x0 + 1.1 * period, ymid, 26, period, shift, BLUE, 3))
        pv = x0 + period / 4
        pi_ = pv - shift / 360 * period
        if kind == "R":
            out.append(text("0°", cx, 212, 13, GRAY, bold=1.1))
        else:
            out.append(arrow(pv, 212, pi_, 212, BLUE, 2.5, 8))
            out.append(line(pv, 206, pv, 218, BLUE, 2))
            out.append(text("90°", px + 68 if kind == "L" else px + 46, 212, 13, BLUE, "start", 1.1))
        if k == 0:
            out.append(text("v", x0 + 4, ymid - 52, 13, RED, bold=1.1))
            out.append(text("i", x0 + 50, ymid - 34, 13, BLUE, bold=1.1))
    return "\n".join(out)


add("F11_phase_rlc", f11_phase_rlc(), W, 244)


def f11_wave_abcd():
    """問題用：v（赤の点線）に対する i（青）。A 同相、B 90° 進み、C 90° 遅れ、D 180°。"""
    out = []
    shifts = {"A": 0, "B": 90, "C": -90, "D": 180}
    for idx, letter in enumerate("ABCD"):
        px = 12 + (idx % 2) * 202
        py = 12 + (idx // 2) * 118
        out.append(rect(px, py, 194, 110, WHITE, LINE, 2, 10))
        out.append(tag(letter, px + 20, py + 20))
        x0, ymid, period = px + 38, py + 58, 140
        out.append(line(x0, ymid, px + 186, ymid, GRAY, 1.5))
        out.append(wave(x0, x0 + period, ymid, 38, period, 0, RED, 2, dash="5,4"))
        out.append(wave(x0, x0 + period, ymid, 26, period, shifts[letter], BLUE, 3.5))
    return "\n".join(out)


add("F11_wave_abcd", f11_wave_abcd(), W, 250)


def f11_impedance_triangle():
    """R = 8Ω、X_L = 6Ω、Z = 10Ω。"""
    out = []
    s = 20
    body, (x1, y1) = right_triangle(30, 200, 8 * s, 6 * s)
    out.append(body)
    out.append(text("R = 8Ω", 30 + 4 * s, 222, 14, INK, bold=1.1))
    out.append(text("X_L = 6Ω", x1 + 10, 200 - 3 * s, 14, INK, "start", 1.1))
    out.append(text("Z = 10Ω", 30 + 4 * s - 26, 200 - 3 * s - 22, 14, INK, bold=1.1))
    fx = 262
    ind = text_width("Z", 14) + SPACING
    out.append(formula([("Z", INK), ("=", GRAY), ("√(R² + X²)", INK)], fx, 44, 14, "start"))
    out.append(formula([("=", GRAY), ("√(8² + 6²)", INK)], fx + ind, 74, 14, "start"))
    out.append(formula([("=", GRAY), ("√(64 + 36)", INK)], fx + ind, 104, 14, "start"))
    out.append(formula([("=", GRAY), ("10Ω", INK)], fx + ind, 134, 14, "start", 1.1))
    return "\n".join(out)


add("F11_impedance_triangle", f11_impedance_triangle())


def f11_power_triangle():
    """100V・10A、力率 0.8：P = 800W、Q = 600var、S = 1000VA。"""
    out = []
    s = 0.2
    body, (x1, y1) = right_triangle(30, 196, 800 * s, 600 * s, fill=ORANGE_L, base_color=ORANGE,
                                    vert_color=GRAY, hyp_color=ORANGE, hyp_dash="10,6")
    out.append(body)
    out.append(text("P = 800W", 30 + 400 * s, 218, 14, ORANGE, bold=1.1))
    out.append(text("Q = 600var", x1 + 10, 196 - 300 * s, 13, GRAY, "start", 1.1))
    out.append(text("S = 1000VA", 30 + 400 * s - 36, 196 - 300 * s - 26, 14, ORANGE, bold=1.1))
    fx = 262
    ind = text_width("cosθ", 14) + SPACING
    out.append(formula([("cosθ", INK), ("=", GRAY), ("P", ORANGE), ("÷", GRAY), ("S", ORANGE)], fx, 44, 14, "start"))
    out.append(formula([("=", GRAY), ("800", ORANGE), ("÷", GRAY), ("1000", ORANGE)], fx + ind, 74, 14, "start"))
    out.append(formula([("=", GRAY), ("0.8", INK)], fx + ind, 104, 14, "start", 1.1))
    return "\n".join(out)


add("F11_power_triangle", f11_power_triangle(), W, 236)


def f11_voltage_triangle():
    """RL 直列：電源 100V、抵抗 80V、コイル 60V。力率 80 ÷ 100 = 0.8。"""
    out = []
    top, bottom, left, right = 72, 190, 40, 214
    out.append(wires([(left, 113), (left, top), (78, top)], [(122, top), (148, top)],
                     [(196, top), (right, top), (right, bottom), (left, bottom), (left, 147)]))
    out.append(ac(left, 130, 17))
    out.append(res(100, top, False, 44, 18))
    out.append(coil_sym(148, top, 4, 6))
    out.append(text("R", 100, 96, 12, INK))
    out.append(text("L", 172, 96, 12, INK))
    out.append(span_h(78, 122, 40, "80V", RED, 13))
    out.append(span_h(148, 196, 40, "60V", RED, 13))
    out.append(text("100V", left + 26, 130, 13, RED, "start", 1.1))
    # 電圧の三角形
    s = 1.5
    body, (x1, y1) = right_triangle(250, 190, 80 * s, 60 * s, fill=RED_L, base_color=RED, vert_color=RED,
                                    hyp_color=RED)
    out.append(body)
    out.append(text("80V", 250 + 40 * s, 210, 13, RED, bold=1.1))
    out.append(text("60V", x1 + 8, 190 - 30 * s, 13, RED, "start", 1.1))
    out.append(text("100V", 250 + 40 * s - 22, 190 - 30 * s - 18, 13, RED, bold=1.1))
    out.append(formula([("cosθ", INK), ("=", GRAY), ("80", RED), ("÷", GRAY), ("100", RED), ("=", GRAY),
                        ("0.8", INK)], 210, 238, 15))
    return "\n".join(out)


add("F11_voltage_triangle", f11_voltage_triangle(), W, 256)


def f11_parallel_rx():
    """R と L の並列：120V、R = 15Ω に 8A、X_L = 20Ω に 6A、全体 10A、P = 960W。"""
    out = []
    top, bottom, left = 46, 176, 44
    rx, lx = 196, 316
    out.append(wires([(left, 94), (left, top), (lx, top), (lx, 83)], [(lx, 139), (lx, bottom), (left, bottom),
                                                                      (left, 128)],
                     [(rx, top), (rx, 86)], [(rx, 136), (rx, bottom)]))
    out.append(ac(left, 111, 17))
    out.append(text("120V", left + 26, 111, 13, RED, "start", 1.1))
    out.append(dot(rx, top, 4.5))
    out.append(dot(rx, bottom, 4.5))
    out.append(res(rx, 111, True, 50, 22))
    out.append(coil_sym(lx, 83, 4, 7, vertical=True))
    out.append(text("15Ω", rx + 20, 111, 13, INK, "start"))
    out.append(text("20Ω", lx + 16, 111, 13, INK, "start"))
    out.append(flow(118, top, "r", BLUE, 9))
    out.append(text("10A", 118, top - 18, 13, BLUE, bold=1.1))
    out.append(flow(rx, 156, "d", BLUE, 9))
    out.append(text("8A", rx - 14, 156, 13, BLUE, "end", 1.1))
    out.append(flow(lx, 156, "d", BLUE, 9))
    out.append(text("6A", lx - 14, 156, 13, BLUE, "end", 1.1))
    out.append(formula([("P", ORANGE), ("=", GRAY), ("8²", BLUE), ("×", GRAY), ("15", INK), ("=", GRAY),
                        ("960W", ORANGE)], 210, 210, 15))
    out.append(formula([("I", BLUE), ("=", GRAY), ("√(8² + 6²)", BLUE), ("=", GRAY), ("10A", BLUE)], 210, 240, 15))
    return "\n".join(out)


add("F11_parallel_rx", f11_parallel_rx(), W, 258)


def f11_pf_correction():
    """100V・10A・力率 0.8 のモーター：有効分 8A、遅れ分 6A。コンデンサ 6A で打ち消すと電源側は 8A。"""
    out = []
    s = 16
    for px, after in ((16, False), (218, True)):
        out.append(rect(px, 12, 186, 196, WHITE, LINE, 2, 12))
        ox, oy = px + 22, 80
        ex, ey = ox + 8 * s, oy + 6 * s
        out.append(text("M + C" if after else "M", px + 93, 32, 14, INK, bold=1.1))
        if not after:
            out.append(line(ox, oy, ex, oy, BLUE, 2.5, dash="6,5"))
            out.append(line(ex, oy, ex, ey, GRAY, 2.5, dash="6,5"))
            out.append(arrow(ox, oy, ex, ey, BLUE, 4, 13))
            out.append(text("8A", (ox + ex) / 2, oy - 13, 13, BLUE))
            out.append(text("6A", ex + 8, (oy + ey) / 2, 13, GRAY, "start"))
            out.append(text("10A", (ox + ex) / 2 - 22, (oy + ey) / 2 + 20, 14, BLUE, bold=1.1))
        else:
            out.append(line(ox, oy, ex, ey, LINE, 2.5, dash="6,5"))
            out.append(arrow(ex, ey, ex, oy + 3, BLUE, 3, 11))
            out.append(text("6A", ex + 8, (oy + ey) / 2, 13, BLUE, "start"))
            out.append(arrow(ox, oy, ex, oy, BLUE, 4, 13))
            out.append(text("8A", (ox + ex) / 2, oy - 13, 14, BLUE, bold=1.1))
    out.append(formula([("10A", BLUE), ("→", GRAY), ("8A", BLUE)], 210, 228, 16, bold=1.1))
    return "\n".join(out)


add("F11_pf_correction", f11_pf_correction(), W, 246)


# ===========================================================================
# F12 三相交流
# ===========================================================================
def f12_three_waves():
    """a・b・c の 3 つの交流が 120° ずつずれている。"""
    out = []
    x0, ymid, amp, period = 44, 142, 62, 240
    out.append(axes(x0, 404, ymid, 60, 222, "t"))
    styles = [("a", 0, RED, None), ("b", -120, "#B03A2E", "10,6"), ("c", -240, "#F08C7A", "3,5")]
    for name, ph, col, dash in styles:
        out.append(wave(x0, x0 + 1.4 * period, ymid, amp, period, ph, col, 3.5, dash))
    peaks = [x0 + period / 4 + k * period / 3 for k in range(3)]
    for (name, _, col, _), px in zip(styles, peaks):
        out.append(text(name, px, ymid - amp - 16, 15, col, bold=1.2))
    out.append(span_h(peaks[0], peaks[1], 40, "120°", GRAY, 12))
    out.append(span_h(peaks[1], peaks[2], 40, "120°", GRAY, 12))
    out.append(formula([("a", RED), ("+", GRAY), ("b", "#B03A2E"), ("+", GRAY), ("c", "#F08C7A"), ("=", GRAY),
                        ("0", INK)], 210, 244, 15, bold=1.1))
    return "\n".join(out)


add("F12_three_waves", f12_three_waves(), W, 262)


def line_labels(ys, x=16):
    return "\n".join(text(n, x, y, 13, GRAY, bold=1.1) for n, y in zip("abc", ys))


def f12_y_connection():
    """線間電圧 200V、各相 20Ω の Y 結線。相電圧 200 ÷ √3 ≒ 115.5V、線電流 ≒ 5.8A。"""
    out = []
    cx, cy = 300, 128
    ta, tb, tc = (300, 44), (226, 172), (374, 172)
    ya, yb, yc = 44, 172, 214
    out.append(wires([(30, ya), ta], [(30, yb), tb], [(30, yc), (tc[0], yc), tc]))
    out.append(line_labels((ya, yb, yc)))
    out.append(res_on(ta[0], ta[1], cx, cy, 40, 18))
    out.append(res_on(tb[0], tb[1], cx, cy, 40, 18))
    out.append(res_on(tc[0], tc[1], cx, cy, 40, 18))
    out.append(dot(cx, cy, 5))
    for t in (ta, tb, tc):
        out.append(dot(*t, 4.5))
    out.append(text("20Ω", 280, 86, 12, INK, "end"))
    out.append(darrow(322, 50, 322, 122, RED, 2.5, 8))
    out.append(text("115.5V", 330, 86, 13, RED, "start", 1.1))
    out.append(darrow(66, ya + 6, 66, yb - 6, RED, 2.5, 8))
    out.append(text("200V", 76, (ya + yb) / 2, 13, RED, "start", 1.1))
    out.append(flow(170, ya, "r", BLUE, 9))
    out.append(text("5.8A", 170, ya - 17, 13, BLUE, bold=1.1))
    out.append(formula([("200", RED), ("÷", GRAY), ("√3", INK), ("≒", GRAY), ("115.5V", RED)], 210, 244, 15))
    return "\n".join(out)


add("F12_y_connection", f12_y_connection(), W, 262)


def f12_delta_connection():
    """線間電圧 200V、各相 20Ω の Δ 結線。相電流 10A、線電流 10 × √3 ≒ 17.3A。"""
    out = []
    ta, tb, tc = (300, 44), (220, 184), (380, 184)
    ya, yb, yc = 44, 184, 222
    out.append(wires([(30, ya), ta], [(30, yb), tb], [(30, yc), (tc[0], yc), tc]))
    out.append(line_labels((ya, yb, yc)))
    out.append(res_on(ta[0], ta[1], tb[0], tb[1], 44, 18))
    out.append(res_on(ta[0], ta[1], tc[0], tc[1], 44, 18))
    out.append(res_on(tb[0], tb[1], tc[0], tc[1], 44, 18))
    for t in (ta, tb, tc):
        out.append(dot(*t, 4.5))
    out.append(text("20Ω", 238, 104, 12, INK, "end"))
    # 相電流（a → c の辺の外側）
    mx, my = (ta[0] + tc[0]) / 2, (ta[1] + tc[1]) / 2
    ux, uy = (tc[0] - ta[0]), (tc[1] - ta[1])
    ln = math.hypot(ux, uy)
    ux, uy = ux / ln, uy / ln
    nx, ny = uy, -ux
    ox, oy = mx + nx * 20, my + ny * 20
    out.append(arrow(ox - ux * 22, oy - uy * 22, ox + ux * 22, oy + uy * 22, BLUE, 2.5, 9))
    out.append(text("10A", ox + 12, oy - 12, 13, BLUE, "start", 1.1))
    out.append(darrow(66, ya + 6, 66, yb - 6, RED, 2.5, 8))
    out.append(text("200V", 76, (ya + yb) / 2, 13, RED, "start", 1.1))
    out.append(flow(170, ya, "r", BLUE, 9))
    out.append(text("17.3A", 170, ya - 17, 13, BLUE, bold=1.1))
    out.append(formula([("10", BLUE), ("×", GRAY), ("√3", INK), ("≒", GRAY), ("17.3A", BLUE)], 210, 250, 15))
    return "\n".join(out)


add("F12_delta_connection", f12_delta_connection(), W, 268)


def f12_delta_open():
    """200V、各相 10Ω の Δ 結線で線 a が断線。b–c 間に 10Ω（20A）と 10Ω + 10Ω（10A）が並ぶ。"""
    out = []
    # 左：断線した Δ
    ta, tb, tc = (150, 56), (104, 146), (196, 146)
    ya, yb, yc = 56, 146, 184
    out.append(wires([(28, ya), ta], [(28, yb), tb], [(28, yc), (tc[0], yc), tc]))
    out.append(line_labels((ya, yb, yc), 14))
    out.append(res_on(ta[0], ta[1], tb[0], tb[1], 30, 14))
    out.append(res_on(ta[0], ta[1], tc[0], tc[1], 30, 14))
    out.append(res_on(tb[0], tb[1], tc[0], tc[1], 30, 14))
    for t in (ta, tb, tc):
        out.append(dot(*t, 4))
    out.append(rect(60, ya - 8, 22, 16, WHITE, WHITE, 0, 0))
    out.append(line(62, ya - 10, 80, ya + 10, RED, 3.5))
    out.append(line(62, ya + 10, 80, ya - 10, RED, 3.5))
    out.append(text("10Ω", 150, 172, 12, INK))
    out.append(line(214, 20, 214, 206, LINE, 2))
    # 右：b–c 間の単相回路に描き直す
    top, bottom = 40, 196
    l1, l2 = 306, 374
    out.append(wires([(238, top), (l2, top), (l2, 62)], [(l2, 98), (l2, 136)], [(l2, 172), (l2, bottom), (238, bottom)],
                     [(l1, top), (l1, 93)], [(l1, 143), (l1, bottom)]))
    out.append(dot(238, top, 4.5))
    out.append(dot(238, bottom, 4.5))
    out.append(text("b", 238, top - 14, 13, GRAY, bold=1.1))
    out.append(text("c", 238, bottom + 16, 13, GRAY, bold=1.1))
    out.append(darrow(238, top + 10, 238, bottom - 10, RED, 2.5, 8))
    out.append(text("200V", 246, 118, 12, RED, "start", 1.1))
    out.append(res(l1, 118, True, 50, 20))
    out.append(res(l2, 80, True, 36, 18))
    out.append(res(l2, 154, True, 36, 18))
    out.append(dot(l1, top, 4.5))
    out.append(dot(l1, bottom, 4.5))
    out.append(text("20A", l1 + 16, 170, 12, BLUE, "start", 1.1))
    out.append(flow(l1, 170, "d", BLUE, 8))
    out.append(text("10A", l2 - 14, 117, 12, BLUE, "end", 1.1))
    out.append(flow(l2, 117, "d", BLUE, 8))
    out.append(text("100V", l2 - 14, 80, 11, RED, "end"))
    out.append(text("100V", l2 - 14, 154, 11, RED, "end"))
    out.append(formula([("4000W", ORANGE), ("+", GRAY), ("1000W", ORANGE), ("+", GRAY), ("1000W", ORANGE), ("=", GRAY),
                        ("6000W", ORANGE)], 210, 240, 13, bold=1.1))
    return "\n".join(out)


add("F12_delta_open", f12_delta_open(), W, 258)


# ---------------------------------------------------------------------------
def write_assets():
    FIG.mkdir(parents=True, exist_ok=True)
    contents = FIG / "Contents.json"
    if not contents.exists():
        contents.write_text(json.dumps({"info": {"author": "xcode", "version": 1},
                                        "properties": {"provides-namespace": False}}, indent=2) + "\n")
    for name, (body, _) in ac_figures.items():
        d = FIG / f"{name}.imageset"
        d.mkdir(exist_ok=True)
        (d / f"{name}.svg").write_text(body, encoding="utf-8")
        (d / "Contents.json").write_text(json.dumps({
            "images": [{"filename": f"{name}.svg", "idiom": "universal"}],
            "info": {"author": "xcode", "version": 1},
            "properties": {"preserves-vector-representation": True},
        }, indent=2) + "\n")
    print(f"{len(ac_figures)} 枚を書き出しました: {FIG}")


def write_preview(out_dir):
    import cairosvg  # 確認用。アプリには不要
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    for name, (body, w) in ac_figures.items():
        cairosvg.svg2png(bytestring=body.encode("utf-8"), write_to=str(out / f"{name}.png"), output_width=w * 2)
    print(f"プレビュー {len(ac_figures)} 枚: {out}")


if __name__ == "__main__":
    if len(sys.argv) >= 3 and sys.argv[1] == "--preview":
        write_preview(sys.argv[2])
    else:
        write_assets()
