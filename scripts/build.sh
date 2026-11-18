#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
APP="$PWD/dist/Atom Control.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$PWD/.build/ModuleCache"
if [[ ! -f Resources/AtomControl.icns || Resources/AtomControl-icon.png -nt Resources/AtomControl.icns || scripts/build-icon.sh -nt Resources/AtomControl.icns ]]; then
    zsh scripts/build-icon.sh
fi
xcrun swiftc -swift-version 5 -O -whole-module-optimization \
    -target "$(uname -m)-apple-macosx13.0" \
    -module-cache-path "$PWD/.build/ModuleCache" \
    -framework AppKit -framework CoreBluetooth -framework ServiceManagement \
    Sources/Localization.swift Sources/EdifierProtocol.swift Sources/AppState.swift Sources/HeadphoneController.swift Sources/main.swift \
    -o "$PWD/.build/AtomControl"
# Replace the inode instead of modifying executable pages of a running version.
mv -f "$PWD/.build/AtomControl" "$APP/Contents/MacOS/AtomControl"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AtomControl.icns "$APP/Contents/Resources/AtomControl.icns"
# Translations: macOS picks en, pt-BR or es from the system language (fallback: en).
rm -rf "$APP/Contents/Resources/"*.lproj(N)
for lproj in Resources/*.lproj; do ditto "$lproj" "$APP/Contents/Resources/${lproj:t}"; done
codesign --force --sign - "$APP"
codesign --verify --strict "$APP"
printf 'App criado: %s\n' "$APP"
