#!/usr/bin/env python3
"""content/lessons/*.md を検証する。
- 見出し `# <id> タイトル` の id がファイル名と一致するか
- <!-- quiz: --> / <!-- session-quiz: --> の問題 ID が content/units の新形式ファイルに存在するか
- <!-- figure: --> の名前が Assets の Figures に存在するか（警告のみ）
- セッション見出し・画面区切りの数
"""
import json, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LESSONS = ROOT / "content" / "lessons"
UNITS = ROOT / "content" / "units"
FIGURES = ROOT / "DenkiQuest" / "Assets.xcassets" / "Figures"

qids = set()
for f in UNITS.glob("*.json"):
    u = json.loads(f.read_text(encoding="utf-8"))
    for q in u["questions"]:
        qids.add(q["id"])
figures = {p.name.replace(".imageset", "") for p in FIGURES.glob("*.imageset")} if FIGURES.exists() else set()

errors, warnings = [], []
total_sessions = total_pages = total_quiz = 0
for f in sorted(LESSONS.glob("*.md")):
    if f.stem.upper() == "README":
        continue
    text = f.read_text(encoding="utf-8")
    lines = text.splitlines()
    head = next((l for l in lines if l.startswith("# ")), "")
    m = re.match(r"# ([A-Z]{1,2}\d{2}) ", head)
    if not m or m.group(1) != f.stem:
        errors.append(f"{f.name}: 見出しの id がファイル名と一致しない: {head!r}")
    sessions = sum(1 for l in lines if l.startswith("## "))
    pages = sum(1 for l in lines if re.fullmatch(r"-{3,}", l.strip()))
    quiz_ids = []
    for l in lines:
        mm = re.match(r"<!--\s*(session-quiz|quiz):\s*(.*?)\s*-->", l.strip())
        if mm:
            quiz_ids += [x.strip() for x in mm.group(2).split(",") if x.strip()]
        mf = re.match(r"<!--\s*figure:\s*(.*?)\s*-->", l.strip())
        if mf and mf.group(1) not in figures:
            warnings.append(f"{f.name}: 図 {mf.group(1)} は未作成（プレースホルダ表示）")
    for qid in quiz_ids:
        if qid not in qids:
            errors.append(f"{f.name}: 問題 ID {qid} が content/units にない")
    total_sessions += sessions; total_pages += pages; total_quiz += len(quiz_ids)
    print(f"{f.name}: {sessions} セッション / 画面区切り {pages} / 差し込み {len(quiz_ids)} 問")

for w in warnings:
    print("warn:", w)
if errors:
    print("\n".join(errors)); print(f"NG: {len(errors)}"); sys.exit(1)
print(f"OK: 合計 {total_sessions} セッション / 画面区切り {total_pages} / 差し込み {total_quiz}")
