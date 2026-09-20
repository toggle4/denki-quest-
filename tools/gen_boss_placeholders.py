#!/usr/bin/env python3
"""ボス画像の仮素材と imageset を生成する。

ユーザーが用意した 12 体の絵を入れるまでのつなぎ。
生成物: DenkiQuest/Assets.xcassets/Bosses/BossNN.imageset/boss_NN.png
差し替えるときはファイル名（boss_NN.png）を変えずに上書きする。
"""
import json
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEST = os.path.join(ROOT, "DenkiQuest", "Assets.xcassets", "Bosses")
SIZE = 768

# (番号, ボス ID, 二つ名, 名前, 輪郭の色)
BOSSES = [
    (1, "galvos", "黒雷狼", "ガルヴォス", (120, 170, 255)),
    (2, "nexal", "電核獣", "ネクサル", (255, 210, 60)),
    (3, "magnaroa", "磁界巨獣", "マグナロア", (170, 180, 200)),
    (4, "valzarn", "雷蛇帝", "ヴァルザーン", (110, 230, 180)),
    (5, "zephalt", "雷翼獣", "ゼファルト", (150, 210, 255)),
    (6, "volgrave", "雷獄竜", "ヴォルグレイヴ", (255, 90, 90)),
    (7, "zerk", "電蝕魔", "ゼルク", (180, 140, 255)),
    (8, "valg", "紅雷鬼", "ヴァルグ", (255, 120, 80)),
    (9, "azur", "蒼雷鯨", "アズール", (90, 180, 255)),
    (10, "granbolt", "轟天獣", "グランボルト", (255, 170, 60)),
    (11, "gradon", "稲妻喰らい", "グラドーン", (200, 255, 120)),
    (12, "arcvein", "終雷獣", "アークヴェイン", (255, 240, 200)),
]

CONTENTS = {
    "images": [
        {"filename": "", "idiom": "universal", "scale": "1x"},
        {"idiom": "universal", "scale": "2x"},
        {"idiom": "universal", "scale": "3x"},
    ],
    "info": {"author": "xcode", "version": 1},
}


def silhouette(draw, rng, color):
    """ギザギザの塊 + 稲妻。ボスらしい影だけの仮絵。"""
    cx, cy = SIZE / 2, SIZE / 2 + 30
    points = []
    spikes = rng.randint(9, 14)
    for i in range(spikes * 2):
        angle = math.pi * 2 * i / (spikes * 2) - math.pi / 2
        far = i % 2 == 0
        r = rng.uniform(250, 300) if far else rng.uniform(150, 200)
        points.append((cx + math.cos(angle) * r, cy + math.sin(angle) * r * 0.95))
    draw.polygon(points, fill=(18, 20, 40, 235), outline=color + (255,))

    # 目
    for sign in (-1, 1):
        ex = cx + sign * 68
        ey = cy - 60
        draw.ellipse([ex - 30, ey - 16, ex + 30, ey + 16], fill=color + (255,))

    # 稲妻
    x, y = cx + rng.uniform(-60, 60), cy - 300
    path = [(x, y)]
    while y < cy + 250:
        y += rng.uniform(50, 90)
        x += rng.uniform(-70, 70)
        path.append((x, y))
    draw.line(path, fill=(255, 255, 255, 200), width=7)
    draw.line(path, fill=color + (140,), width=18)


def make(number, boss_id, epithet, name, color):
    rng = random.Random(number * 7919)
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([80, 110, SIZE - 80, SIZE - 60], fill=color + (70,))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(70)))

    draw = ImageDraw.Draw(img)
    silhouette(draw, rng, color)

    try:
        font = ImageFont.load_default(size=90)
    except TypeError:  # 古い Pillow
        font = ImageFont.load_default()
    label = "%02d" % number
    draw.text((SIZE / 2, 78), label, font=font, fill=(255, 255, 255, 230), anchor="mm")

    folder = os.path.join(DEST, "Boss%02d.imageset" % number)
    os.makedirs(folder, exist_ok=True)
    filename = "boss_%02d.png" % number
    img.save(os.path.join(folder, filename))

    contents = json.loads(json.dumps(CONTENTS))
    contents["images"][0]["filename"] = filename
    with open(os.path.join(folder, "Contents.json"), "w", encoding="utf-8") as f:
        json.dump(contents, f, indent=2, ensure_ascii=False)
        f.write("\n")
    return "Boss%02d.imageset/%s  %s%s" % (number, filename, epithet, name)


def main():
    os.makedirs(DEST, exist_ok=True)
    with open(os.path.join(DEST, "Contents.json"), "w", encoding="utf-8") as f:
        json.dump({"info": {"author": "xcode", "version": 1}}, f, indent=2)
        f.write("\n")
    for row in BOSSES:
        print(make(*row))


if __name__ == "__main__":
    main()
