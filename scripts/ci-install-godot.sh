#!/usr/bin/env bash
# Installs the Godot 4.7.1 editor and the web export template on a Linux CI runner.
# Editor goes to ~/godot, templates to ~/.local/share/godot/export_templates/4.7.1.stable.
set -euo pipefail

VERSION=4.7.1
BASE_URL="https://github.com/godotengine/godot-builds/releases/download/${VERSION}-stable"
EDITOR_NAME="Godot_v${VERSION}-stable_linux.x86_64"
EDITOR_SHA256=c7ff14fd28472c8d4f193043de30278dcf7e5241a1dcf7566b02e27addaa33ba
TEMPLATES_NAME="Godot_v${VERSION}-stable_export_templates.tpz"
TEMPLATES_SHA256=86409db6200b6f8fd3230989c2d2002851f3dd18acf11d7bdbafddf5a0dd0f72

EDITOR_DIR="$HOME/godot"
TEMPLATES_DIR="$HOME/.local/share/godot/export_templates/${VERSION}.stable"
DOWNLOAD_DIR="$(mktemp -d)"
trap 'rm -rf "$DOWNLOAD_DIR"' EXIT

cd "$DOWNLOAD_DIR"
curl --fail --location --silent --show-error -O "$BASE_URL/$EDITOR_NAME.zip"
curl --fail --location --silent --show-error -O "$BASE_URL/$TEMPLATES_NAME"

printf '%s  %s\n' "$EDITOR_SHA256" "$EDITOR_NAME.zip" "$TEMPLATES_SHA256" "$TEMPLATES_NAME" | sha256sum -c -

mkdir -p "$EDITOR_DIR" "$TEMPLATES_DIR"
unzip -o -q "$EDITOR_NAME.zip" -d "$EDITOR_DIR"
chmod +x "$EDITOR_DIR/$EDITOR_NAME"

# The .tpz is a zip with entries under templates/; keep only what the web export needs.
unzip -o -j -q "$TEMPLATES_NAME" templates/web_nothreads_release.zip templates/version.txt -d "$TEMPLATES_DIR"
rm -f "$TEMPLATES_NAME"

echo "Godot editor: $EDITOR_DIR/$EDITOR_NAME"
echo "Export templates in: $TEMPLATES_DIR"
ls -l "$TEMPLATES_DIR"
