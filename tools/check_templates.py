#!/usr/bin/env python3
"""template 問題を実際に何度も生成して、壊れていないか確かめる。

アプリの TemplateEngine / QuestionFactory と同じ手順で数値を作り、次を調べる。
- constraints を満たす組が作れるか（300 回以内）
- 答えが有限の数になるか
- 問題文・解説の {名前} がすべて埋まるか
- 4 択（answerType: choice）で、正答と重ならない誤答が 3 つ以上作れるか

使い方:
  python3 tools/check_templates.py            # 全ファイル
  python3 tools/check_templates.py F05 F08    # 単元を指定
  python3 tools/check_templates.py --show F08 # 生成例を表示
Python 標準ライブラリのみ。
"""
import json
import math
import random
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
UNITS = ROOT / "content" / "units"
EPS = 1e-9
TRIALS = 400


class Evaluator:
    """DenkiQuest/Services/TemplateEngine.swift の ExpressionEvaluator と同じ文法。"""

    def __init__(self, variables):
        self.vars = variables

    def evaluate(self, text):
        self.s = text
        self.i = 0
        v = self._comparison()
        self._spaces()
        if self.i != len(self.s):
            raise ValueError(f"式の末尾に余分な文字: {text!r}")
        return v

    def _spaces(self):
        while self.i < len(self.s) and self.s[self.i].isspace():
            self.i += 1

    def _match(self, tok):
        self._spaces()
        if self.s.startswith(tok, self.i):
            self.i += len(tok)
            return True
        return False

    def _comparison(self):
        left = self._additive()
        for op in ("==", "!=", "<=", ">=", "<", ">"):
            if self._match(op):
                right = self._additive()
                return 1.0 if self._cmp(op, left, right) else 0.0
        return left

    @staticmethod
    def _cmp(op, a, b):
        eps = 1e-9 * max(1.0, abs(a), abs(b))
        return {
            "==": abs(a - b) < eps, "!=": abs(a - b) >= eps,
            "<=": a <= b + eps, ">=": a >= b - eps, "<": a < b - eps, ">": a > b + eps,
        }[op]

    def _additive(self):
        v = self._term()
        while True:
            if self._match("+"):
                v += self._term()
            elif self._match("-"):
                v -= self._term()
            else:
                return v

    def _term(self):
        v = self._unary()
        while True:
            if self._match("*"):
                v *= self._unary()
            elif self._match("/"):
                d = self._unary()
                v = v / d if d != 0 else math.inf
            elif self._match("%"):
                d = self._unary()
                v = math.fmod(v, d) if d != 0 else math.nan
            else:
                return v

    def _unary(self):
        if self._match("-"):
            return -self._unary()
        if self._match("+"):
            return self._unary()
        return self._primary()

    def _primary(self):
        self._spaces()
        if self._match("("):
            v = self._comparison()
            if not self._match(")"):
                raise ValueError("閉じかっこがない")
            return v
        c = self.s[self.i] if self.i < len(self.s) else ""
        if c.isdigit() or c == ".":
            m = re.match(r"\d*\.?\d+(?:[eE][-+]?\d+)?", self.s[self.i:])
            self.i += m.end()
            return float(m.group(0))
        m = re.match(r"[A-Za-z_][A-Za-z0-9_]*", self.s[self.i:])
        if not m:
            raise ValueError(f"読めない文字: {self.s[self.i:]!r}")
        name = m.group(0)
        self.i += m.end()
        if self._match("("):
            args = []
            if not self._match(")"):
                while True:
                    args.append(self._comparison())
                    if self._match(")"):
                        break
                    if not self._match(","):
                        raise ValueError("引数の区切りがない")
            return self._call(name, args)
        consts = {"SQRT2": math.sqrt(2), "SQRT3": math.sqrt(3), "PI": math.pi}
        if name in consts:
            return consts[name]
        if name not in self.vars:
            raise KeyError(f"未定義の名前: {name}")
        return self.vars[name]

    @staticmethod
    def _call(name, a):
        def swift_round(x):
            return math.floor(x + 0.5) if x >= 0 else -math.floor(-x + 0.5)
        table = {
            ("sqrt", 1): lambda: math.sqrt(a[0]), ("pow", 2): lambda: a[0] ** a[1],
            ("abs", 1): lambda: abs(a[0]), ("round", 1): lambda: swift_round(a[0]),
            ("floor", 1): lambda: math.floor(a[0]), ("ceil", 1): lambda: math.ceil(a[0]),
            ("min", 2): lambda: min(a), ("max", 2): lambda: max(a),
        }
        if (name, len(a)) not in table:
            raise ValueError(f"使えない関数: {name}/{len(a)}")
        return table[(name, len(a))]()


def fmt(value, round_to=None):
    """TemplateEngine.format と同じ表示。"""
    if round_to is not None and round_to <= 0:
        return str(int(math.floor(value + 0.5)))
    digits = 4 if round_to is None else round_to
    t = f"{value:.{digits}f}"
    if "." in t:
        t = t.rstrip("0").rstrip(".")
    return "0" if t == "-0" else t


def rand_value(spec):
    step = spec.get("step", 1) or 1
    count = max(0, int(math.floor((spec["max"] - spec["min"]) / step + 1e-9)))
    return round(spec["min"] + random.randint(0, count) * step, 6)


def generate(q):
    for _ in range(300):
        values = {n: rand_value(s) for n, s in q["variables"].items()}
        ok = True
        for d in q.get("derived", []):
            try:
                v = Evaluator(values).evaluate(d["formula"])
            except (ValueError, ZeroDivisionError):
                ok = False
                break
            if not math.isfinite(v):
                ok = False
                break
            if d.get("roundTo") is not None:
                scale = 10 ** d["roundTo"]
                v = math.floor(v * scale + 0.5) / scale
            values[d["name"]] = v
        if not ok:
            continue
        ev = Evaluator(values)
        if not all(ev.evaluate(c) != 0 for c in q.get("constraints", [])):
            continue
        ans = ev.evaluate(q["answerFormula"])
        if math.isfinite(ans):
            return values, ans
    return None


def substitute(text, values, answer):
    for n, v in values.items():
        text = text.replace("{" + n + "}", fmt(v))
    return text.replace("{answer}", answer)


def check_question(q, show=False):
    problems = []
    fallback_used = 0
    rt = q.get("roundTo", 2)
    scale = 10 ** rt
    seen = set()
    for trial in range(TRIALS):
        g = generate(q)
        if g is None:
            problems.append("constraints を満たす組が作れない")
            break
        values, ans = g
        rounded = math.floor(ans * scale + 0.5) / scale
        ans_text = fmt(rounded, rt)
        prompt = substitute(q["prompt"], values, ans_text)
        expl = substitute(q.get("explanation", ""), values, ans_text)
        left = re.findall(r"\{[A-Za-z_][A-Za-z0-9_]*\}", prompt + expl)
        if left:
            problems.append(f"埋まらない名前 {sorted(set(left))}")
            break
        if q.get("answerType") == "choice":
            # アプリ（QuestionBank.makeTemplate）と同じ作り方
            seen_t = {ans_text}
            wrong = []
            for f in q.get("distractors", []):
                try:
                    v = Evaluator(values).evaluate(f)
                except (ValueError, KeyError) as e:
                    problems.append(f"誤答の式が読めない {f!r}: {e}")
                    break
                if math.isfinite(v):
                    t = fmt(math.floor(v * scale + 0.5) / scale, rt)
                    if t not in seen_t:
                        seen_t.add(t)
                        wrong.append(t)
            if problems:
                break
            if len(wrong) < 3:
                fallback_used += 1
                for v in (rounded * 2, rounded / 2, rounded * 10, rounded + 1, rounded - 1, rounded * 3):
                    if len(wrong) >= 3:
                        break
                    t = fmt(math.floor(v * scale + 0.5) / scale, rt)
                    if t not in seen_t:
                        seen_t.add(t)
                        wrong.append(t)
            if len(wrong) < 3:
                problems.append(f"誤答が 3 つ作れない例: 答え {ans_text}, 誤答 {wrong} / 値 {values}")
                break
        seen.add(prompt)
        if show and trial < 3:
            print(f"    例{trial + 1}: {prompt}")
            print(f"         答え {ans_text}{q.get('unitLabel', '')}  解説: {expl}")
    return problems, len(seen), fallback_used / TRIALS


def main(argv):
    show = "--show" in argv
    wanted = [a for a in argv if not a.startswith("--")]
    files = sorted(UNITS.glob("*.json"))
    if wanted:
        files = [f for f in files if f.stem in wanted]
    total = bad = 0
    for path in files:
        data = json.loads(path.read_text(encoding="utf-8"))
        if data.get("schemaVersion") != 2:
            continue
        for q in data.get("questions", []):
            if q.get("type") != "template":
                continue
            total += 1
            try:
                problems, variety, fallback = check_question(q, show)
            except (KeyError, ValueError) as e:
                problems, variety, fallback = [str(e)], 0, 0
            if problems:
                bad += 1
                print(f"NG  {q['id']}: {problems[0]}")
            else:
                if fallback > 0.25:
                    print(f"注意 {q['id']}: {fallback:.0%} の出題で誤答の式が足りず、2 倍・半分などで補っている")
                if show:
                    print(f"OK  {q['id']}: {variety} 通り以上")
    print(f"{'OK' if bad == 0 else 'NG'}: template {total} 問を {TRIALS} 回ずつ生成、問題あり {bad} 問")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
