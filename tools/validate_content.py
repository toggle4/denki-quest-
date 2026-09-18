#!/usr/bin/env python3
"""content/units/*.json を content/schema.md の形式に沿って検証する。"""
import json
import re
import sys
from pathlib import Path

UNITS = Path(__file__).resolve().parent.parent / "content" / "units"
STAGES = {"review", "memorize", "calculate", "practical"}
TYPES = {"choice", "truefalse", "number"}

errors = []
seen_ids = set()
V2_TYPES = {"multipleChoice", "numericInput", "trueFalse", "matching", "imageChoice", "template"}
v2_total = 0


def validate_v2(path, unit, err):
    """schemaVersion 2（チャット側の形式）の最低限のチェック。"""
    global v2_total
    meta = unit.get("unit", {})
    if meta.get("id") != path.stem:
        err(f"unit.id '{meta.get('id')}' がファイル名 '{path.stem}' と一致しない")
    ids = set()
    for q in unit.get("questions", []):
        qid = q.get("id", "?")
        if qid in ids:
            err(f"{qid}: id が重複")
        ids.add(qid)
        t = q.get("type")
        if t not in V2_TYPES:
            err(f"{qid}: type '{t}' が不正")
            continue
        v2_total += 1
        for key in ("prompt", "explanation"):
            if key not in q:
                err(f"{qid}: {key} がない")
        if t == "multipleChoice":
            ch = q.get("choices", [])
            a = q.get("answerIndex")
            if not isinstance(a, int) or not (0 <= a < len(ch)):
                err(f"{qid}: answerIndex が choices の範囲外")
        elif t == "trueFalse" and not isinstance(q.get("answer"), bool):
            err(f"{qid}: answer が true/false でない")
        elif t == "numericInput" and not isinstance(q.get("answer"), (int, float)):
            err(f"{qid}: answer が数値でない")
        elif t == "template":
            for key in ("variables", "answerFormula", "answerType"):
                if key not in q:
                    err(f"{qid}: {key} がない")
            if q.get("answerType") not in ("numeric", "choice"):
                err(f"{qid}: answerType が numeric/choice でない")
            if q.get("answerType") == "choice" and len(q.get("distractors", [])) < 3:
                err(f"{qid}: choice 形式は distractors が 3 つ以上必要")
    boss = unit.get("boss")
    if boss:
        for qid in boss.get("questionIds", []):
            if qid not in ids:
                err(f"boss.questionIds の {qid} が存在しない")
seen_orders = set()
total = 0
by_type = {}

for path in sorted(UNITS.glob("*.json")):
    try:
        unit = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        errors.append(f"{path.name}: JSON エラー {e}")
        continue

    def err(msg):
        errors.append(f"{path.name}: {msg}")

    if unit.get("schemaVersion") == 2:
        validate_v2(path, unit, err)
        continue

    for key in ("id", "title", "order", "stage", "description", "questions"):
        if key not in unit:
            err(f"単元に {key} がない")
    if unit.get("id") != path.stem:
        err(f"id '{unit.get('id')}' がファイル名 '{path.stem}' と一致しない")
    if unit.get("stage") not in STAGES:
        err(f"stage '{unit.get('stage')}' が不正")
    if unit.get("order") in seen_orders:
        err(f"order {unit.get('order')} が重複")
    seen_orders.add(unit.get("order"))
    if "boss" in unit:
        for key in ("questionCount", "timeLimitSeconds"):
            if not isinstance(unit["boss"].get(key), int):
                err(f"boss.{key} が整数でない")

    questions = unit.get("questions", [])
    if len(questions) < 10:
        err(f"問題数が {len(questions)} 問（10 問以上にする）")

    for i, q in enumerate(questions):
        qid = q.get("id", f"#{i}")
        for key in ("id", "type", "prompt", "explanation"):
            if key not in q:
                err(f"{qid}: {key} がない")
        if not re.fullmatch(rf"{re.escape(unit.get('id',''))}_q\d{{3}}", qid):
            err(f"{qid}: id の形式が <単元id>_q### でない")
        if qid in seen_ids:
            err(f"{qid}: id が重複")
        seen_ids.add(qid)
        t = q.get("type")
        if t not in TYPES:
            err(f"{qid}: type '{t}' が不正")
            continue
        by_type[t] = by_type.get(t, 0) + 1
        total += 1
        if t == "choice":
            ch = q.get("choices")
            if not isinstance(ch, list) or len(ch) < 2:
                err(f"{qid}: choices が 2 つ未満")
            elif len(set(ch)) != len(ch):
                err(f"{qid}: choices に重複がある")
            a = q.get("answer")
            if not isinstance(a, int) or isinstance(a, bool) or not (0 <= a < len(ch or [])):
                err(f"{qid}: answer が choices の範囲外")
        elif t == "truefalse":
            if not isinstance(q.get("answer"), bool):
                err(f"{qid}: answer が true/false でない")
        elif t == "number":
            if not isinstance(q.get("answer"), (int, float)) or isinstance(q.get("answer"), bool):
                err(f"{qid}: answer が数値でない")
            if "tolerance" in q and not isinstance(q["tolerance"], (int, float)):
                err(f"{qid}: tolerance が数値でない")
        if "hint" in q and not isinstance(q["hint"], str):
            err(f"{qid}: hint が文字列でない")

if errors:
    print("\n".join(errors))
    print(f"\nNG: {len(errors)} 件")
    sys.exit(1)
print(f"OK: {len(list(UNITS.glob('*.json')))} ファイル / 旧形式 {total} 問 {by_type} / 新形式 {v2_total} 問")
