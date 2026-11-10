#!/usr/bin/env bash
# Exports the Godot project for the web into the shell's public folder.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../../.." && pwd)"
godot="$root/scripts/godot.sh"
project="$here/../godot"
out="$root/apps/shell/public/games/racing-carts"

mkdir -p "$out"
# Clear the previous export so a failed run cannot pass the check below with stale files.
rm -f "$out"/index.*
"$godot" --headless --path "$project" --import
"$godot" --headless --path "$project" --export-release Web "$out/index.html"

# Godot can exit 0 on a failed export, so check the output.
if [ ! -f "$out/index.wasm" ]; then
  echo "export failed: $out/index.wasm is missing" >&2
  exit 1
fi
