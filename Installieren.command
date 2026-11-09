#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
trap 'echo "Build/Installation abgebrochen. Die Meldung oben enthält die Ursache."; read -r -p "Enter zum Schließen … "' ERR
if [[ "$(uname -s)" != Darwin ]]; then
    echo "Dieser Installer benötigt macOS 12 oder neuer."; exit 1
fi
if ! xcrun --find swiftc >/dev/null 2>&1; then
    echo "Bitte zuerst die Apple Command Line Tools installieren: xcode-select --install"
    xcode-select --install || true
    echo "Danach diesen Installer erneut starten."; exit 1
fi
APP="$HOME/Applications/FinderExtras.app"
if [[ -e "$APP" ]]; then
    echo "FinderExtras existiert bereits. Bitte App beenden und vor dem Neubau umbenennen oder entfernen."
    exit 1
fi
BUILD="$(mktemp -d "${TMPDIR:-/tmp}/finderextras.XXXXXX")"
trap 'rm -rf "$BUILD"' EXIT
BUNDLE="$BUILD/FinderExtras.app"
mkdir -p "$BUNDLE/Contents/MacOS"
cp Info.plist "$BUNDLE/Contents/Info.plist"
# Build for the Mac running this installer, including Intel Macs.
xcrun swiftc -swift-version 5 -O -target "$(uname -m)-apple-macosx12.0" \
    -framework AppKit -framework ApplicationServices Sources/main.swift \
    -o "$BUNDLE/Contents/MacOS/FinderExtras"
codesign --force --sign - "$BUNDLE"
codesign --verify --strict "$BUNDLE"
mkdir -p "$HOME/Applications"
mv "$BUNDLE" "$APP"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP"
open "$APP"
echo "Installiert: $APP"
echo "Die Einrichtung steht unter FinderExtras → Hilfe und Einrichtung."
