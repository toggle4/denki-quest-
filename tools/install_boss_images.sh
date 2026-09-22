#!/bin/bash
# ボスの絵を Assets に取り込む。
#
#   sh tools/install_boss_images.sh ~/Downloads/denki-monster-image
#
# 元ファイルは boss-01 / boss_01 / boss01 のどれでもよく、拡張子は png・webp・jpg など何でもよい。
# PNG に変換し、長辺 1200px に縮めて Boss01.imageset/boss_01.png として置く。
set -uo pipefail

SRC="${1:-$HOME/Downloads/denki-monster-image}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/DenkiQuest/Assets.xcassets/Bosses"

if [ ! -d "$SRC" ]; then
  echo "元のフォルダが見つかりません: $SRC" >&2
  echo "フォルダの場所を引数で渡してください。例: sh tools/install_boss_images.sh ~/Downloads/denki-monster-image" >&2
  exit 1
fi

if command -v sips >/dev/null 2>&1; then
  HAS_SIPS=1
else
  HAS_SIPS=0
fi

copied=0
missing=""

for n in 01 02 03 04 05 06 07 08 09 10 11 12; do
  src=""
  for stem in "boss-$n" "boss_$n" "boss$n"; do
    for f in "$SRC/$stem".*; do
      [ -e "$f" ] || continue
      src="$f"
      break
    done
    [ -n "$src" ] && break
  done

  if [ -z "$src" ]; then
    echo "見つかりません: boss-$n.*"
    missing="$missing $n"
    continue
  fi

  out="$DEST/Boss$n.imageset/boss_$n.png"
  mkdir -p "$(dirname "$out")"

  ext="$(echo "${src##*.}" | tr '[:upper:]' '[:lower:]')"
  if [ "$HAS_SIPS" = "1" ] && sips -s format png -Z 1200 "$src" --out "$out" >/dev/null 2>&1; then
    :
  elif [ "$ext" = "png" ]; then
    cp "$src" "$out"
  else
    echo "PNG に変換できませんでした: $src" >&2
    echo "  プレビューで開いて「ファイル > 書き出す」から PNG にしてから、もう一度実行してください。" >&2
    missing="$missing $n"
    continue
  fi

  echo "OK  $(basename "$src")  ->  Boss$n.imageset/boss_$n.png"
  copied=$((copied + 1))
done

echo ""
echo "取り込み $copied / 12 枚"
if [ -n "$missing" ]; then
  echo "足りない番号:$missing"
  echo "元フォルダの中身:"
  ls "$SRC"
  exit 1
fi
echo "Xcode でビルドすれば絵が入れ替わります（追加操作は不要）。"
