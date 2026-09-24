#!/usr/bin/env python3
"""docs/app-store.md の各欄が App Store Connect の文字数制限に収まっているか確かめる。

使い方: python3 tools/check_app_store_text.py
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DOC = ROOT / "docs" / "app-store.md"

LIMITS = {
    "名前": 30,
    "サブタイトル": 30,
    "プロモーション用テキスト": 170,
    "概要": 4000,
    "キーワード": 100,
}


def blocks(text):
    """「## 見出し」ごとに、最初のコードブロックの中身を返す。"""
    out = {}
    for m in re.finditer(r"^## (.+?)\n(.*?)(?=^## |\Z)", text, re.S | re.M):
        head = m.group(1)
        code = re.search(r"```\n(.*?)\n```", m.group(2), re.S)
        if code:
            for key in LIMITS:
                if head.startswith(key):
                    out[key] = code.group(1)
    return out


def main():
    found = blocks(DOC.read_text(encoding="utf-8"))
    ok = True
    for key, limit in LIMITS.items():
        if key not in found:
            print(f"NG  {key}: 見つからない")
            ok = False
            continue
        body = found[key]
        n = len(body)
        mark = "OK" if n <= limit else "NG"
        ok &= n <= limit
        extra = ""
        if key == "キーワード":
            words = body.split(",")
            dup = {w for w in words if words.count(w) > 1}
            spaced = [w for w in words if w != w.strip() or not w]
            extra = f"  語数 {len(words)}"
            if dup:
                extra += f"  重複 {sorted(dup)}"
                ok = False
            if spaced:
                extra += "  前後に空白・空の語あり"
                ok = False
        print(f"{mark}  {key}: {n} / {limit} 文字{extra}")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
