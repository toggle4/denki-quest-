# denki-quest — 第二種電気工事士 学習ゲーム（iOS）

## 目的
未経験者が中学理科の復習から始めて第二種電気工事士（筆記・技能）に合格するための学習ゲーム。
目標学習時間は 200 時間。1 セッション 5〜10 分で区切り、集中が途切れない設計にする。

## 技術方針
- Swift / SwiftUI、iOS 17 以上
- 進捗・間隔反復のデータは SwiftData に保存
- 教材データは `content/units/*.json`（形式は `content/schema.md` 参照）。コードに問題文を直書きしない
- 図記号や器具の画像は Assets に SVG で入れる。外部の画像・過去問を無断で使わない
- 外部ライブラリは原則使わない

## 学習設計
- 単元の順序は `docs/curriculum.md` に従う（暗記系を先、計算系を後）
- 間違えた問題は 1日→3日→7日→14日 後に再出題
- 各単元の最後にボス戦（制限時間つき連続正解）

## 作業ルール
- 1 回の依頼で 1 機能だけ実装する
- 変更後は必ず xcodebuild でビルドが通ることを確認する
- 新しい出題形式を追加するときは `content/schema.md` も更新する

## ビルド確認コマンド
```sh
xcodebuild -project DenkiQuest.xcodeproj -scheme DenkiQuest \
  -destination 'generic/platform=iOS Simulator' build
```

## ディレクトリ構成
- `DenkiQuest/` … アプリ本体（Xcode の同期フォルダ。ここに置いたファイルは自動でターゲットに含まれる）
  - `Models/` … 教材 JSON を表す Codable 型
  - `Services/` … 教材の読み込みなど
  - `Views/` … SwiftUI 画面
- `content/units/` … 単元ごとの教材 JSON（フォルダ参照としてアプリにバンドルされる）
- `content/schema.md` … 教材 JSON の形式
- `docs/curriculum.md` … 単元の順序と学習時間の配分
