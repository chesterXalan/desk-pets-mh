#!/bin/sh
# Builds build/DeskPets.app: release binaries, bundled characters, ad-hoc signature.
set -eu
cd "$(dirname "$0")/.."

VERSION="${VERSION:-0.1.0}"
APP="build/DeskPets.app"

# The native build system works with only the Command Line Tools installed (no Xcode needed).
swift build -c release --build-system native --arch arm64 2>&1 | grep -v "has been deprecated" || true
BIN="$(swift build -c release --build-system native --arch arm64 --show-bin-path 2>/dev/null | tail -n 1)"
test -x "$BIN/DeskPets" || { echo "release build failed" >&2; exit 1; }

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/DeskPets" "$BIN/deskpets-hook" "$APP/Contents/MacOS/"
strip -x "$APP/Contents/MacOS/DeskPets" "$APP/Contents/MacOS/deskpets-hook"
cp -R Resources/Characters "$APP/Contents/Resources/Characters"
sed "s/__VERSION__/$VERSION/g" Resources/Info.plist > "$APP/Contents/Info.plist"

# Sign the helper first, then the bundle.
codesign --force --sign - --options runtime "$APP/Contents/MacOS/deskpets-hook"
codesign --force --sign - --options runtime "$APP"
codesign --verify --strict "$APP"
du -sh "$APP"
