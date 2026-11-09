#!/usr/bin/env bash
# Builds shell and controller into one GitHub Pages site under output/.
#   output/              the shell
#   output/controller/   the controller (QR code target)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/output"

# Both Vite configs read env files from the repo root; a VITE_E2E there would ship the test game.
if [ -z "${VITE_E2E:-}" ] && grep -qsE '^[[:space:]]*(export[[:space:]]+)?VITE_E2E[[:space:]]*=' "$ROOT"/.env*; then
  echo "error: a root .env file defines VITE_E2E; remove it, the e2e test game must not ship." >&2
  exit 1
fi

npm run build -w @couch/shell
npm run build -w @couch/controller

rm -rf "$OUT"
mkdir -p "$OUT/controller"
cp -R "$ROOT/apps/shell/dist/." "$OUT/"
cp -R "$ROOT/apps/controller/dist/." "$OUT/controller/"
# Serve files as-is; no Jekyll processing.
touch "$OUT/.nojekyll"

# The e2e fixture game must only ship in e2e builds.
if [ -z "${VITE_E2E:-}" ] && grep -rqE "e2e-test-game|Test Game" "$OUT"; then
  echo "error: the e2e test game leaked into the production build." >&2
  exit 1
fi

echo "Build ready: $OUT"
