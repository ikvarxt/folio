#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT_DIR/scripts/build-app.sh" debug >/dev/null
open "$ROOT_DIR/dist/MarkdownPreviewer.app"
