# 教材データの形式（content/units/*.json）

1 ファイル = 1 単元。ファイル名は `u<2桁の順番>_<英語スラッグ>.json`（例: `u01_basics_review.json`）。
アプリ起動時に `content/units/` 内のすべての JSON を読み込み、`order` の昇順に並べる。

チェック: `python3 tools/validate_content.py` で全ファイルの形式を検証できる。

## 単元（ファイル直下のオブジェクト）

| キー | 型 | 必須 | 説明 |
|---|---|---|---|
| `id` | string | ○ | 単元の一意な ID。ファイル名と揃える（例: `u01_basics_review`） |
| `title` | string | ○ | 画面に表示する単元名 |
| `order` | integer | ○ | 学習順（`docs/curriculum.md` に従う）。小さいほど先 |
| `stage` | string | ○ | `review`（中学理科の復習）/ `memorize`（暗記系）/ `calculate`（計算系）/ `practical`（技能） |
| `description` | string | ○ | 単元の説明（1〜2 文） |
| `questions` | Question[] | ○ | 問題の配列。1 単元あたり 20 問以上を目安にする |
| `boss` | Boss | – | ボス戦の設定。省略時はボス戦なし |

## Question（問題）

すべての出題形式に共通するキー:

| キー | 型 | 必須 | 説明 |
|---|---|---|---|
| `id` | string | ○ | 問題の一意な ID。`<単元id>_q<3桁>` の形式（例: `u01_basics_review_q001`）。間隔反復の記録キーになるので、公開後は変更しない |
| `type` | string | ○ | 出題形式。下記の一覧から選ぶ |
| `prompt` | string | ○ | 問題文 |
| `explanation` | string | ○ | 解説。正誤にかかわらず回答後に表示する |
| `hint` | string | – | ヒント。回答前に「ヒントを見る」で表示できる。ヒントを使って正解してもコンボは増えない。答えそのものは書かず、考え方や覚え方を書く |
| `image` | string | – | Assets に登録した画像名（SVG）。図記号や器具の写真代わりに使う |

### 出題形式の一覧

#### `choice` — 4 択（単一正解）

| キー | 型 | 必須 | 説明 |
|---|---|---|---|
| `choices` | string[] | ○ | 選択肢。4 つを基本とする。表示時にシャッフルされるので「上記すべて」のような選択肢は使わない |
| `answer` | integer | ○ | 正解の選択肢のインデックス（0 始まり） |

#### `truefalse` — ○×

| キー | 型 | 必須 | 説明 |
|---|---|---|---|
| `answer` | boolean | ○ | 文が正しければ `true`、誤りなら `false` |

問題文は「〜である。」のような断定文にする。誤りの文は、数値や用語を 1 か所だけ変えたものにすると学習効果が高い。

#### `number` — 数値入力

| キー | 型 | 必須 | 説明 |
|---|---|---|---|
| `answer` | number | ○ | 正解の数値 |
| `tolerance` | number | – | 許容誤差（絶対値）。省略時は 0。四捨五入が絡む問題では必ず指定する（例: 正解 0.333 なら `0.005`） |
| `unit` | string | – | 入力欄の横に表示する単位（例: `"Ω"`, `"A"`, `"W"`） |

問題文に「小数第 1 位まで」「整数で」のように、どこまで求めるかを書く。

> 新しい出題形式を追加するときは、ここに節を追加し、`Models/ContentModels.swift` の `Question.QuestionType` と `init(from:)`、`Services/QuizSession.swift` の回答処理、`Views/SessionView.swift` の回答 UI を追加する。

## Boss（ボス戦）

| キー | 型 | 必須 | 説明 |
|---|---|---|---|
| `questionCount` | integer | ○ | 連続で正解する必要がある問題数 |
| `timeLimitSeconds` | integer | ○ | 全問に対する制限時間（秒） |

## 例

```json
{
  "id": "u01_basics_review",
  "title": "電気の基礎（中学理科の復習）",
  "order": 1,
  "stage": "review",
  "description": "電流・電圧・抵抗の意味と単位を思い出す。",
  "questions": [
    {
      "id": "u01_basics_review_q001",
      "type": "choice",
      "prompt": "電流の大きさを表す単位はどれか。",
      "choices": ["A（アンペア）", "V（ボルト）", "Ω（オーム）", "W（ワット）"],
      "answer": 0,
      "hint": "「アンペア」は電流計の名前にも使われる。",
      "explanation": "電流の単位はアンペア（A）。電圧は V、抵抗は Ω、電力は W。"
    },
    {
      "id": "u01_basics_review_q002",
      "type": "truefalse",
      "prompt": "直列回路では、どの部分にも同じ大きさの電流が流れる。",
      "answer": true,
      "explanation": "直列回路は電流の通り道が 1 本なので、電流はどこでも等しい。"
    },
    {
      "id": "u01_basics_review_q003",
      "type": "number",
      "prompt": "10 Ω の抵抗に 2 A の電流が流れている。抵抗の両端の電圧 [V] を整数で答えよ。",
      "answer": 20,
      "unit": "V",
      "hint": "V = I × R",
      "explanation": "V = I × R = 2 × 10 = 20 V。"
    }
  ],
  "boss": { "questionCount": 10, "timeLimitSeconds": 90 }
}
```

## 執筆ルール
- 問題文・解説はすべて自作する。市販問題集や過去問の文章をそのまま使わない
- 1 問は 30 秒以内に答えられる長さにする（1 セッション 10 問で 5〜10 分）
- 解説は「なぜそうなるか」を 1〜3 文で書く
- ヒントは答えを直接言わず、公式・語呂・着眼点を書く
