# 第二種電気工事士 学習ゲーム（iOS）— DenkiQuest

## 最初に読むもの
- docs/HANDOFF.md（経緯・確定した設計・現在のタスク）。作業を始める前に必ず読む
- docs/legacy-overview.md（土台になっている旧ゲームの構成）

## 目的
未経験者が中学理科の復習から始めて第二種電気工事士（筆記・技能）に合格するための学習ゲーム。
基礎固めと網羅性を最重視する。1セッション5〜10分で区切り、集中が途切れない設計にする。

## 技術方針
- Swift / SwiftUI、iOS 17以上、Xcodeプロジェクト名は DenkiQuest
- 進捗・間隔反復のデータは SwiftData に保存
- 教材テキストは content/lessons/*.md（仕様は content/lessons/README.md）
- 問題データは content/units/*.json（仕様は content/schema.md）。コードに問題文を直書きしない
  - 新形式（schemaVersion 2、F02.json など）と旧形式（u01〜u16、schemaVersion なし）の両方を読む
- content/ フォルダは Xcode プロジェクトにフォルダ参照（青いフォルダ）として追加済み。Bundle の content/lessons, content/units から読む
- 図記号や器具の画像は Assets に SVG で置く。外部の画像・過去問を無断で使わない
- 外部ライブラリは原則使わない

## 学習設計
- 単元の順序とステージ構成は docs/curriculum.md に従う
- 各セッションは説明画面と問題画面を交互に並べる（<!-- quiz: --> で差し込み）。画面の流れと戻る・進むのルールは content/lessons/README.md に厳密に従う
- 計算問題は template 形式（数値をランダム生成）を基本とし、同じ構造の問題を数値を変えて繰り返せるようにする
- 間違えた問題は 1日→3日→7日→14日 後に再出題
- 単元クリアは直近10問の正答率90%以上（ステージ0は95%）
- 各単元の最後にボス戦（制限時間つき連続正解）。ボスは 12 体で、ステージを前半・後半に分けた区間ごとに 1 体が担当する（割り当ては docs/curriculum.md の付録）
- ボスは戦闘中は名前だけを出し、二つ名は登場演出とボス図鑑でだけ出す

## 作業ルール
- 1回の依頼で1機能だけ実装する
- 変更後は必ず xcodebuild -destination 'generic/platform=iOS Simulator' でビルドが通ることを確認する。プロジェクトの署名設定（CODE_SIGN_*）は変更しない
- 既存の動くコードを作り直さず、拡張する
- 新しい出題形式やMarkdown記法を追加するときは schema.md / lessons/README.md も更新する
- 教材（lessons, units）の中身は書き換えない。パーサやUI側で対応する
- 教材 JSON を追加・変更したら `python3 tools/validate_content.py` を通す（template を追加・変更したら `python3 tools/check_templates.py` も）。教材テキスト（lessons）を追加・変更したら `python3 tools/validate_lessons.py` を通す

## ビルド確認コマンド
```sh
xcodebuild -project DenkiQuest.xcodeproj -scheme DenkiQuest \
  -destination 'generic/platform=iOS Simulator' build
```

## ディレクトリ構成
- `DenkiQuest/` … アプリ本体（Xcode の同期フォルダ。ここに置いたファイルは自動でターゲットに含まれる）
  - `Models/` … 教材 JSON の Codable 型（旧形式 `LearningUnit`/`Question`、新形式 `UnitFileV2`/`QuestionV2`）、教材テキストの `Lesson`、SwiftData の `StudyRecord`（学習時間）と `ReviewItem`（間隔反復）、ボス名簿 `Boss`/`BossRoster`/`BossCollection`
  - `Services/` … 読み込み（`ContentLoader` 旧形式、`QuestionBank` 新形式、`LessonLibrary`/`LessonParser` 教材テキスト）、`TemplateEngine`（template 問題の数値生成）、セッション進行（`QuizSession` ドリル、`LessonFlow` 読む→解く、`BossEngine` ボス戦）、効果音・触覚
  - `Theme/` … 配色・カード・ボタンなど共通スタイル
  - `Views/` … SwiftUI 画面。ホーム `UnitListView`、教材 `LessonUnitView`/`LessonSessionView`/`LessonBlockView`、ドリル `SessionView`、1 問ぶんの出題画面 `QuestionView`（ドリルと教材の差し込み問題で共用）、ボス戦 `BossBattleView`、ボス図鑑 `BossCollectionView`
  - `Sounds/` … 効果音 WAV（`tools/gen_sounds.py` で自作合成）
  - `Assets.xcassets/Mascot.imageset` … 通常のマスコット SVG（自作）
  - `Assets.xcassets/MascotBurnt.imageset` … 感電してこげたマスコット（`tools/gen_mascot_burnt.py` で生成。差し替えは `tools/install_mascot_burnt.sh`）
  - `Assets.xcassets/Bosses/Boss01〜Boss12.imageset` … ボス 12 体の絵（背景透過 PNG。仮画像は tools/gen_boss_placeholders.py。差し替えはファイル名 boss_NN.png のまま上書き）
  - `Assets.xcassets/BossMonster.imageset` … 名簿にない単元用の予備画像、`Figures/` … 単線図 SVG（tools/gen_wiring_figures.py）と教材 F01〜F08 の図 37 枚（tools/gen_lesson_figures.py）、ステージ 1 の図記号・器具の図 103 枚（tools/gen_symbol_figures.py）
- `tools/` … 効果音・アイコンの生成、教材 JSON の検証 `validate_content.py`、template の生成チェック `check_templates.py`（Python 標準ライブラリのみ）
- `content/lessons/` … 教材テキスト（Markdown）
- `content/units/` … 問題データ（JSON）
- `docs/` … curriculum.md, HANDOFF.md, legacy-overview.md, app-store.md（App Store Connect に載せる文言。文字数の確認は `python3 tools/check_app_store_text.py`）
