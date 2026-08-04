#!/bin/zsh
# Builds Bundle/AppIcon.icns from the SVG sources in Bundle/Icon.
#
# Slots at 32px and below use icon-small.svg: the full mark's five bars fall
# below one device pixel there and smear into a grey block.
#
# Requires rsvg-convert (brew install librsvg). Run after editing either SVG.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ICON_DIR="$ROOT_DIR/Bundle/Icon"
ICONSET="$(mktemp -d)/AppIcon.iconset"
OUTPUT="$ROOT_DIR/Bundle/AppIcon.icns"

if ! command -v rsvg-convert >/dev/null; then
  print -u2 "make-icon.sh: rsvg-convert not found. brew install librsvg"
  exit 1
fi

mkdir -p "$ICONSET"

# slot name -> pixel size
typeset -A slots=(
  icon_16x16          16
  icon_16x16@2x       32
  icon_32x32          32
  icon_32x32@2x       64
  icon_128x128       128
  icon_128x128@2x    256
  icon_256x256       256
  icon_256x256@2x    512
  icon_512x512       512
  icon_512x512@2x   1024
)

for slot size in ${(kv)slots}; do
  if (( size <= 32 )); then
    source_svg="$ICON_DIR/icon-small.svg"
  else
    source_svg="$ICON_DIR/icon.svg"
  fi

  rsvg-convert -w "$size" -h "$size" "$source_svg" -o "$ICONSET/$slot.png"
done

iconutil --convert icns "$ICONSET" --output "$OUTPUT"
rm -rf "$(dirname "$ICONSET")"

print "Built $OUTPUT"
