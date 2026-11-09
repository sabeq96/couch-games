#!/usr/bin/env bash
# Builds shell and controller into one GitHub Pages site under output/.
#   output/              the shell
#   output/controller/   the controller (QR code target)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/output"

npm run build -w @couch/shell
npm run build -w @couch/controller

rm -rf "$OUT"
mkdir -p "$OUT/controller"
cp -R "$ROOT/apps/shell/dist/." "$OUT/"
cp -R "$ROOT/apps/controller/dist/." "$OUT/controller/"
# Serve files as-is; no Jekyll processing.
touch "$OUT/.nojekyll"

echo "Build ready: $OUT"
