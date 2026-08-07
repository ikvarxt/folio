#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${1:-release}"
APP_NAME="MarkdownPreviewer"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"

cd "$ROOT_DIR"
BIN_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"

# The packaging step below copies every bundle it finds here, and SwiftPM never
# removes the ones a dropped dependency left behind. Clearing them first means
# the build re-creates exactly the set the current dependency graph declares.
rm -rf "$BIN_DIR"/*.bundle(N)

swift build -c "$CONFIGURATION"

EXECUTABLE="$BIN_DIR/$APP_NAME"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "Bundle/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$EXECUTABLE" "$APP_DIR/Contents/MacOS/$APP_NAME"

# Prebuilt so a plain build needs no librsvg. Regenerate with scripts/make-icon.sh
# after editing Bundle/Icon/*.svg.
if [[ -f "Bundle/AppIcon.icns" ]]; then
  cp "Bundle/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
else
  print -u2 "build-app.sh: Bundle/AppIcon.icns missing, run scripts/make-icon.sh"
fi

find "$BIN_DIR" -maxdepth 1 -name '*.bundle' -print0 | while IFS= read -r -d '' bundle; do
  cp -R "$bundle" "$APP_DIR/Contents/Resources/"
done

codesign --force --deep --sign - "$APP_DIR" >/dev/null

echo "Built $APP_DIR"
