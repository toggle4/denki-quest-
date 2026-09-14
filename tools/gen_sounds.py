#!/usr/bin/env python3
"""効果音を合成して DenkiQuest/Sounds/*.wav に書き出す。

外部素材を使わず、すべて正弦波などから生成する（ライセンス問題なし）。
再生成: python3 tools/gen_sounds.py
"""
import math
import struct
import wave
from pathlib import Path

RATE = 44100
OUT = Path(__file__).resolve().parent.parent / "DenkiQuest" / "Sounds"


def tone(freq, seconds, volume=0.5, attack=0.005, decay=None, harmonics=(1.0, 0.3, 0.12), wave_shape="sine"):
    """1 音を生成して float のリストで返す。"""
    n = int(RATE * seconds)
    decay = seconds if decay is None else decay
    out = []
    for i in range(n):
        t = i / RATE
        env = min(1.0, t / attack) if attack > 0 else 1.0
        env *= math.exp(-3.0 * t / decay)
        s = 0.0
        for k, amp in enumerate(harmonics, start=1):
            phase = 2 * math.pi * freq * k * t
            if wave_shape == "square":
                s += amp * (1.0 if math.sin(phase) >= 0 else -1.0)
            else:
                s += amp * math.sin(phase)
        out.append(volume * env * s / sum(harmonics))
    return out


def silence(seconds):
    return [0.0] * int(RATE * seconds)


def mix(a, b, offset_seconds):
    """b を a の offset 位置に重ねる。"""
    off = int(RATE * offset_seconds)
    length = max(len(a), off + len(b))
    out = a + [0.0] * (length - len(a))
    for i, v in enumerate(b):
        out[off + i] += v
    return out


def write(name, samples):
    OUT.mkdir(parents=True, exist_ok=True)
    peak = max(1e-6, max(abs(s) for s in samples))
    scale = 0.9 / peak if peak > 0.9 else 1.0
    with wave.open(str(OUT / name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        frames = b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, s * scale)) * 32767)) for s in samples
        )
        w.writeframes(frames)
    print(f"wrote {name} ({len(samples) / RATE:.2f}s)")


# 音名 → 周波数
C5, E5, G5, A5, C6, E6, G6 = 523.25, 659.25, 783.99, 880.0, 1046.5, 1318.5, 1568.0

# tap: 選択肢をタップしたときの軽いクリック
write("tap.wav", tone(1400, 0.06, volume=0.35, attack=0.001, decay=0.03, harmonics=(1.0,)))

# correct: 明るい 2 音（ピンポン）
correct = tone(C6, 0.14, volume=0.5, decay=0.12)
correct = mix(correct, tone(E6, 0.32, volume=0.5, decay=0.25), 0.11)
write("correct.wav", correct)

# wrong: 低いブザー
write("wrong.wav", tone(160, 0.35, volume=0.45, attack=0.01, decay=0.3, harmonics=(1.0, 0.5, 0.25), wave_shape="square"))

# combo: 連続正解時の上昇アルペジオ
combo = []
for i, f in enumerate((C6, E6, G6)):
    combo = mix(combo, tone(f, 0.16, volume=0.45, decay=0.14), i * 0.07)
write("combo.wav", combo)

# clear: セッション終了のファンファーレ
clear = []
for i, f in enumerate((C5, E5, G5)):
    clear = mix(clear, tone(f, 0.18, volume=0.45, decay=0.16), i * 0.13)
clear = mix(clear, tone(C6, 0.9, volume=0.55, decay=0.7), 0.39)
clear = mix(clear, tone(E6, 0.9, volume=0.3, decay=0.7), 0.39)
write("clear.wav", clear)

# perfect: 全問正解のときだけ鳴る、より長いファンファーレ
perfect = []
for i, f in enumerate((C5, E5, G5, C6, E6)):
    perfect = mix(perfect, tone(f, 0.16, volume=0.45, decay=0.14), i * 0.1)
perfect = mix(perfect, tone(G6, 1.2, volume=0.55, decay=0.9), 0.5)
perfect = mix(perfect, tone(C6, 1.2, volume=0.35, decay=0.9), 0.5)
perfect = mix(perfect, tone(E6, 1.2, volume=0.3, decay=0.9), 0.5)
write("perfect.wav", perfect)
