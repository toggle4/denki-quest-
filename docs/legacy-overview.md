# 旧ゲームの構成（統合の土台）

旧ゲーム = GitHub `claude/trusting-dirac-tprx3b` ブランチ（2026-09-14 作成）。チャット側の教材・設計はこの上に継ぎ足す。

## 画面
| 画面 | ファイル | 内容 |
|---|---|---|
| ホーム | Views/UnitListView.swift | マスコット（長押しで充電・6 秒でショート）、200 時間ゲージ、単元一覧、設定メニュー（効果音・振動） |
| ドリル（クエスト） | Views/SessionView.swift | 10 問ランダム出題。4 択・○×・数値入力、ヒント、コンボ、正解バウンス・不正解シェイク。`QuestionView` は教材の差し込み問題でも再利用 |
| 結果 | Views/SessionView.swift 内 ResultView | ランク S〜C、星、最大コンボ、ヒント回数、学習時間 |
| 学習記録 | Views/StudyLogView.swift | 直近 7 日のグラフと履歴 |
| 200 時間ゲージ | Views/StudyGaugeView.swift | カウントアップ、150 h 安心ライン、200 h 超で虹色オーバーフロー |
| マスコット | Views/ChargeMascotView.swift | ChargeController と連動した充電・ショート演出 |

## データ
- `LearningUnit` / `Question`（Models/ContentModels.swift）: 旧形式 JSON（u01〜u16、446 問）
- `StudyRecord`（SwiftData）: 1 セッションの学習時間・正答数。`StudyStats` で合計・今日・連続日数を集計
- `QuizSession`: 1 セッションの進行（回答・コンボ・ヒント）。`init(unit:questions:)` で任意の問題列を渡せる

## 演出
- `Theme`: ダークネイビー × 電気イエロー。`gameCard()`、`VoltButtonStyle`、`GameBackground`
- `GameFeedback` = `Haptics` + `SoundPlayer`（効果音 9 種は tools/gen_sounds.py で自作合成）

## チャット側から移植したもの
- `LessonParser` / `LessonLibrary` / `Lesson` モデル / `LessonBlockView` / `Curriculum`（ステージ 0 の順序）
- 差し込みマーカー `<!-- quiz: -->` `<!-- session-quiz: -->` はパーサに追加し、`LessonFlow` が説明↔問題の一本道を制御する
- 新形式 JSON（schemaVersion 2）は `QuestionBank` が読み、`TemplateEngine` が template 問題の数値を生成して旧ゲームの `Question` に変換する
