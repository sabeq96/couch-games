#!/usr/bin/env bash
# Runs the GUT tests of the Godot project headless; exits non-zero on failures.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../../.." && pwd)"
godot="$root/scripts/godot.sh"
project="$here/../godot"

# Import first so class_name globals are registered.
"$godot" --headless --path "$project" --import
"$godot" --headless --path "$project" -s addons/gut/gut_cmdln.gd -gexit
