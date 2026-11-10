#!/usr/bin/env bash
# Runs the GUT tests of the Godot project headless; exits non-zero on failures.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../../.." && pwd)"
godot="$root/scripts/godot.sh"
project="$here/../godot"

# Import first so class_name globals are registered.
"$godot" --headless --path "$project" --import
# --fixed-fps 60: each frame advances one 60 Hz physics tick, as fast as the CPU allows; tests count physics frames.
# GUT skips a test script that fails to load (a parse error) and still exits 0, so fail on that here.
log="$(mktemp)"
trap 'rm -f "$log"' EXIT
"$godot" --headless --path "$project" --fixed-fps 60 -s addons/gut/gut_cmdln.gd -gexit 2>&1 | tee "$log"
if grep -E 'Failed to load script "res://tests/|could not be loaded' "$log" >/dev/null; then
  echo "A GUT test script failed to load; see the errors above." >&2
  exit 1
fi
