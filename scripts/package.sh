#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"

zsh scripts/build.sh
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
ARCH=$(uname -m)
PACKAGE="$PWD/dist/Atom-Control-${VERSION}-${ARCH}.pkg"
STAGING=$(mktemp -d "$PWD/.build/package.XXXXXX")
trap 'rm -rf "$STAGING"' EXIT

mkdir -p "$STAGING/root/Applications"
ditto "$PWD/dist/Atom Control.app" "$STAGING/root/Applications/Atom Control.app"
codesign --verify --strict "$STAGING/root/Applications/Atom Control.app"

# Prevent Installer from relocating the installation into a development checkout.
cat > "$STAGING/components.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><array><dict>
    <key>RootRelativeBundlePath</key><string>Applications/Atom Control.app</string>
    <key>BundleIsRelocatable</key><false/>
    <key>BundleIsVersionChecked</key><true/>
    <key>BundleHasStrictIdentifier</key><true/>
    <key>BundleOverwriteAction</key><string>upgrade</string>
</dict></array></plist>
PLIST

pkgbuild --root "$STAGING/root" \
    --component-plist "$STAGING/components.plist" \
    --identifier br.com.local.AtomControl.installer \
    --version "$VERSION" --install-location / --ownership recommended \
    "$PACKAGE"

# Extract the actual payload and verify both its destination and code signature.
pkgutil --expand-full "$PACKAGE" "$STAGING/expanded"
codesign --verify --strict "$STAGING/expanded/Payload/Applications/Atom Control.app"
test -x "$STAGING/expanded/Payload/Applications/Atom Control.app/Contents/MacOS/AtomControl"
cmp "$STAGING/expanded/Payload/Applications/Atom Control.app/Contents/MacOS/AtomControl" \
    "$PWD/dist/Atom Control.app/Contents/MacOS/AtomControl"

cd "$PWD/dist"
shasum -a 256 "${PACKAGE:t}" > "${PACKAGE:t}.sha256"
printf 'Instalador validado: %s\n' "$PACKAGE"
