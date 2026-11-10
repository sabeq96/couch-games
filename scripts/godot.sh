#!/usr/bin/env bash
# Runs the Godot editor binary: $GODOT, else the macOS app, else `godot` on PATH.
set -euo pipefail

if [ -n "${GODOT:-}" ]; then
  GODOT_BIN="$GODOT"
elif [ -x /Applications/Godot.app/Contents/MacOS/Godot ]; then
  GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
else
  GODOT_BIN=godot
fi

exec "$GODOT_BIN" "$@"
