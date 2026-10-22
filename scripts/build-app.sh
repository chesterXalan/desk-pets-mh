#!/bin/sh
# Builds build/DeskPets.app: release binaries, bundled characters, ad-hoc signature.
set -eu
cd "$(dirname "$0")/.."

VERSION="${VERSION:-0.1.0}"
APP="build/DeskPets.app"
# Assemble next to the target and swap at the end: installed hooks call build/DeskPets.app's
# deskpets-hook, and running sessions should never see it missing mid-build.
STAGE="build/.DeskPets.app.staging"

command -v ffmpeg >/dev/null || { echo "FFmpeg is required: brew install ffmpeg" >&2; exit 1; }
swift tools/build-monsters.swift .

# The native build system works with only the Command Line Tools installed (no Xcode needed).
swift build -c release --build-system native --arch arm64 2>&1 | grep -v "has been deprecated" || true
BIN="$(swift build -c release --build-system native --arch arm64 --show-bin-path 2>/dev/null | tail -n 1)"
test -x "$BIN/DeskPets" || { echo "release build failed" >&2; exit 1; }

rm -rf "$STAGE"
mkdir -p "$STAGE/Contents/MacOS" "$STAGE/Contents/Resources"
cp "$BIN/DeskPets" "$BIN/deskpets-hook" "$STAGE/Contents/MacOS/"
strip -x "$STAGE/Contents/MacOS/DeskPets" "$STAGE/Contents/MacOS/deskpets-hook"
cp -R .build/Characters "$STAGE/Contents/Resources/Characters"
cp Resources/AppIcon.icns "$STAGE/Contents/Resources/AppIcon.icns"
sed "s/__VERSION__/$VERSION/g" Resources/Info.plist > "$STAGE/Contents/Info.plist"

# Sign the helper first, then the bundle.
codesign --force --sign - --options runtime "$STAGE/Contents/MacOS/deskpets-hook"
codesign --force --sign - --options runtime "$STAGE"
codesign --verify --strict "$STAGE"

if [ -d "$APP" ]; then
    mv "$APP" "build/.DeskPets.app.old"
fi
mv "$STAGE" "$APP"
rm -rf "build/.DeskPets.app.old"
du -sh "$APP"
