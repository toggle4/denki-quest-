# content/schema.md — 問題データの仕様

## ファイル
`content/units/<unitId>.json`（例：`F02.json`）。1単元1ファイル。

## トップレベル
```json
{
  "schemaVersion": 2,
  "unit": { "id": "F02", "stage": 0, "order": 2, "title": "…", "lessonFile": "F02.md",
            "prerequisites": ["F01"], "masteryThreshold": 0.95 },
  "questions": [ … ],
  "boss": { "id": "F02-boss", "title": "…", "questionIds": [ … ], "timeLimitSeconds": 90 }
}
```

## 問題の共通フィールド
| フィールド | 型 | 説明 |
|---|---|---|
| id | string | 単元内で一意 |
| type | string | 下記のいずれか |
| difficulty | 1〜4 | curriculum.md の L1〜L4 に対応 |
| prompt | string | 問題文。template では `{変数名}` を埋め込む |
| explanation | string | 解説。template では `{変数名}` `{answer}` を埋め込める |
| tags | string[] | 分類 |
| srsWeight | number | 間隔反復の重み（1.0 標準） |
| figure | string? | `Assets/figures/<名前>.svg` を表示 |
| hint | string? | 回答前に見られるヒント（使うとコンボが増えない） |
| origin | string? | 英語の語源・略語の意味（例: `WP = Water Proof`）。正誤に関係なく解説の下に「英語で覚える」として表示 |
| tip | string? | 現場ではこう使われている、という豆知識。解説の下に「現場では」として表示 |

## type 一覧
### multipleChoice
`choices: string[]`, `answerIndex: int`

### numericInput
`answer: number`, `unitLabel: string`, `tolerance: number`（許容誤差、絶対値）

### trueFalse
`answer: bool`

### matching
`pairs: [{left, right}]`

### imageChoice
`figure` を問題として表示し、`choices` から選ぶ（ステージ1以降）

### template（パラメータ化問題）
数値をアプリ側でランダム生成し、答えを式で計算する。
```json
{
  "id": "F02-t01",
  "type": "template",
  "difficulty": 1,
  "prompt": "{V}V の電源に {R}Ω の抵抗をつないだ。流れる電流は何 A か。",
  "variables": {
    "V": { "min": 10, "max": 200, "step": 10 },
    "R": { "min": 2, "max": 50, "step": 2 }
  },
  "constraints": ["V % R == 0"],
  "answerFormula": "V / R",
  "answerType": "numeric",
  "unitLabel": "A",
  "roundTo": 2,
  "distractors": ["V * R", "R / V", "V - R"],
  "explanation": "I = V / R = {V} / {R} = {answer}A。",
  "tags": ["計算", "オームの法則"],
  "srsWeight": 1.0
}
```
- `variables`：各変数の範囲と刻み。`step` 省略時は 1
- `constraints`：満たすまで再生成する条件（割り切れる、など）。省略可
- `answerFormula`：四則演算・`sqrt()`・`pow()`・定数 `SQRT2`, `SQRT3` を使える
- `answerType`：`numeric`（数値入力）または `choice`（`distractors` から誤答を作り四択にする）
- `roundTo`：小数点以下の桁数
- `distractors`：誤答を作る式。正答と同値になったものは捨てて再生成する
- 表示時の数値は `roundTo` に従って丸める
- 同じテンプレートでも生成された数値ごとに別の出題として扱うが、間隔反復の履歴はテンプレート単位で管理する

## 評価ルール
- numericInput / template(numeric)：`|入力 − 正答| <= tolerance` で正解。tolerance 省略時は 正答の 1%
- 弱点検知：同じ template で difficulty 2 以上を 3 回連続で間違えたら、difficulty 1 の同系統テンプレートを優先出題する

---

## 旧形式（旧ゲームの u01〜u16 単元。`schemaVersion` なし）

旧ゲームで作成した 16 単元 446 問（`content/units/u01_*.json` 〜 `u16_*.json`）は次の形式で、`schemaVersion` キーを持たない。
アプリは `schemaVersion` の有無で新旧を判別し、両方を読み込む。旧形式の問題は「ドリル」として単元一覧に並ぶ。

```json
{
  "id": "u01_basics_review", "title": "…", "order": 1,
  "stage": "review | memorize | calculate | practical",
  "description": "…",
  "questions": [
    { "id": "u01_basics_review_q001", "type": "choice",    "prompt": "…", "choices": ["…"], "answer": 0, "hint": "…", "explanation": "…" },
    { "id": "…_q002",                "type": "truefalse", "prompt": "…", "answer": true, "explanation": "…" },
    { "id": "…_q003",                "type": "number",    "prompt": "…", "answer": 20, "tolerance": 0.5, "unit": "V", "explanation": "…" }
  ],
  "boss": { "questionCount": 10, "timeLimitSeconds": 90 }
}
```

- `hint` は任意。ヒントを使って正解してもコンボは増えない
- `origin`（英語の語源）と `tip`（現場の豆知識）も任意。新形式と同じ意味
- 新形式との対応: `choice` ≒ `multipleChoice`（`answer` = `answerIndex`）、`truefalse` = `trueFalse`、`number` ≒ `numericInput`（`unit` = `unitLabel`）
- 検証: `python3 tools/validate_content.py`（新旧両方を検証する）

## 試験型ドリル（教材のない新形式ファイル）
`unit.lessonFile` が null で、対応する `content/lessons/<id>.md` がない新形式ファイルは、ホームの「試験型ドリル」に並ぶ。
template 問題は 1 セッションごとに数値が変わる。docs/exam-patterns.md の型から作成している（E01, D01〜D06, K02〜K09, S08, G03）。
ID の付け方: 固定問題は `<単元>-q01`、template は `<単元>-t01`。

## アプリ側の対応状況
| type | 状態 |
|---|---|
| multipleChoice / trueFalse / numericInput | 対応（旧ゲームの 4 択・○×・数値入力 UI で表示） |
| template | 対応（`answerType` が `choice` なら 4 択、`numeric` なら数値入力。数値は出題ごとに生成） |
| matching / imageChoice | 未対応（読み飛ばす）。UI を追加するときにここを更新する |
