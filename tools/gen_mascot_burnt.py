#!/usr/bin/env python3
"""感電してこげたマスコットの SVG を書き出す。

通常版 Mascot.imageset/mascot.svg と同じ形・同じ viewBox のまま、
色をすすけさせ、目をぐるぐるにし、煙と残り火を足したもの。
ユーザーが自分の絵を用意したら tools/install_mascot_burnt.sh で差し替える。
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEST = os.path.join(ROOT, "DenkiQuest", "Assets.xcassets", "MascotBurnt.imageset")

SVG = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200" width="200" height="200">
  <defs>
    <radialGradient id="ember" cx="50%" cy="58%" r="50%">
      <stop offset="0%" stop-color="#FF6A3D" stop-opacity="0.38"/>
      <stop offset="100%" stop-color="#FF6A3D" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="char" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#6B5A4A"/>
      <stop offset="55%" stop-color="#4A3E36"/>
      <stop offset="100%" stop-color="#2A2320"/>
    </linearGradient>
  </defs>

  <circle cx="100" cy="100" r="96" fill="url(#ember)"/>
  <circle cx="100" cy="100" r="78" fill="#141824" stroke="#39332C" stroke-width="4"/>

  <!-- すすの汚れ -->
  <ellipse cx="70" cy="120" rx="26" ry="16" fill="#0B0D12" opacity="0.55"/>
  <ellipse cx="132" cy="112" rx="22" ry="14" fill="#0B0D12" opacity="0.45"/>

  <!-- こげた稲妻本体 -->
  <polygon points="112,28 62,110 96,110 84,172 142,84 108,84"
           fill="url(#char)" stroke="#1C1714" stroke-width="5" stroke-linejoin="round"/>
  <!-- ひび割れ -->
  <path d="M104 44 L96 70 L106 74 L98 96" stroke="#8A7663" stroke-width="2.5" fill="none" opacity="0.8"/>
  <path d="M120 96 L108 118 L116 122" stroke="#8A7663" stroke-width="2" fill="none" opacity="0.6"/>
  <!-- 残り火 -->
  <circle cx="99" cy="58" r="2.6" fill="#FF7A33" opacity="0.9"/>
  <circle cx="111" cy="102" r="2.2" fill="#FFAA55" opacity="0.8"/>
  <circle cx="90" cy="134" r="2.0" fill="#FF7A33" opacity="0.7"/>

  <!-- ぐるぐる目 -->
  <path d="M92 66 m0,-8 a8,8 0 1,1 -5.6,2.4 a5,5 0 1,0 3.6,-1.6"
        stroke="#F2E7D5" stroke-width="2.6" fill="none" stroke-linecap="round"/>
  <path d="M112 64 m0,-8 a8,8 0 1,1 -5.6,2.4 a5,5 0 1,0 3.6,-1.6"
        stroke="#F2E7D5" stroke-width="2.6" fill="none" stroke-linecap="round"/>

  <!-- ぽかんと開いた口 -->
  <ellipse cx="102" cy="86" rx="8" ry="6" fill="#140F0C" stroke="#3B322B" stroke-width="2"/>

  <!-- 立ちのぼる煙 -->
  <path d="M78 34 q10,-12 0,-22 q-10,-10 2,-18" stroke="#C9C3BB" stroke-width="4"
        fill="none" stroke-linecap="round" opacity="0.5"/>
  <path d="M126 30 q-9,-11 1,-20" stroke="#C9C3BB" stroke-width="3.5"
        fill="none" stroke-linecap="round" opacity="0.38"/>
</svg>
'''

CONTENTS = {
    "images": [{"filename": "mascot_burnt.svg", "idiom": "universal"}],
    "info": {"author": "xcode", "version": 1},
    "properties": {"preserves-vector-representation": True},
}


def main():
    os.makedirs(DEST, exist_ok=True)
    with open(os.path.join(DEST, "mascot_burnt.svg"), "w", encoding="utf-8") as f:
        f.write(SVG)
    with open(os.path.join(DEST, "Contents.json"), "w", encoding="utf-8") as f:
        json.dump(CONTENTS, f, indent=2)
        f.write("\n")
    print("MascotBurnt.imageset/mascot_burnt.svg を書き出しました")


if __name__ == "__main__":
    main()
