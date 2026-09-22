#!/bin/bash
# こげたマスコットの絵を差し替える。
#
#   sh tools/install_mascot_burnt.sh ~/Downloads/mascot-burnt.png
#
# SVG ならそのまま、それ以外は PNG（長辺 1024px）に変換して入れる。
set -uo pipefail

SRC="${1:-}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/DenkiQuest/Assets.xcassets/MascotBurnt.imageset"

if [ -z "$SRC" ] || [ ! -f "$SRC" ]; then
  echo "使い方: sh tools/install_mascot_burnt.sh <画像ファイル>" >&2
  exit 1
fi

mkdir -p "$DEST"
rm -f "$DEST"/mascot_burnt.*

ext="$(echo "${SRC##*.}" | tr '[:upper:]' '[:lower:]')"

if [ "$ext" = "svg" ]; then
  cp "$SRC" "$DEST/mascot_burnt.svg"
  cat > "$DEST/Contents.json" <<'JSON'
{
  "images" : [
    {
      "filename" : "mascot_burnt.svg",
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  },
  "properties" : {
    "preserves-vector-representation" : true
  }
}
JSON
  echo "OK  $(basename "$SRC")  ->  MascotBurnt.imageset/mascot_burnt.svg"
  exit 0
fi

out="$DEST/mascot_burnt.png"
if command -v sips >/dev/null 2>&1 && sips -s format png -Z 1024 "$SRC" --out "$out" >/dev/null 2>&1; then
  :
elif [ "$ext" = "png" ]; then
  cp "$SRC" "$out"
else
  echo "PNG に変換できませんでした: $SRC" >&2
  exit 1
fi

cat > "$DEST/Contents.json" <<'JSON'
{
  "images" : [
    {
      "filename" : "mascot_burnt.png",
      "idiom" : "universal",
      "scale" : "1x"
    },
    {
      "idiom" : "universal",
      "scale" : "2x"
    },
    {
      "idiom" : "universal",
      "scale" : "3x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON
echo "OK  $(basename "$SRC")  ->  MascotBurnt.imageset/mascot_burnt.png"
