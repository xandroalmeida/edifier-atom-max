#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
ICONSET="$PWD/.build/AtomControl.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" Resources/AtomControl-icon.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    retina=$((size * 2))
    sips -z "$retina" "$retina" Resources/AtomControl-icon.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
if ! iconutil -c icns "$ICONSET" -o Resources/AtomControl.icns 2>/dev/null; then
    xcrun swift -module-cache-path "$PWD/.build/ModuleCache" scripts/pack-icon.swift "$ICONSET" Resources/AtomControl.icns
fi
