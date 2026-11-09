#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
[[ "$(uname -s)" == Darwin ]] || { echo "macOS wird benötigt."; exit 1; }
OUT="${1:-$PWD/build}"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
APP="$OUT/FinderExtras.app"
[[ ! -e "$APP" ]] || { echo "Build-Ziel existiert bereits: $APP"; exit 1; }
EXT="$APP/Contents/PlugIns/FinderExtrasSync.appex"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$EXT/Contents/MacOS"
cp Info.plist "$APP/Contents/Info.plist"
cp Extension/Info.plist "$EXT/Contents/Info.plist"
xcrun swiftc -swift-version 5 -O -target "$(uname -m)-apple-macosx12.0" \
 -framework AppKit -framework ApplicationServices -framework FinderSync -framework Carbon \
 Sources/main.swift Sources/TransferEngine.swift -o "$APP/Contents/MacOS/FinderExtras"
xcrun clang -fobjc-arc -mmacosx-version-min=12.0 -framework Cocoa -framework FinderSync \
 -Wl,-e,_NSExtensionMain Extension/FinderSync.m -o "$EXT/Contents/MacOS/FinderExtrasSync"
xcrun swift Tools/Icon.swift "$OUT/AppIcon.iconset"
iconutil -c icns "$OUT/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
SIGNING_IDENTITY="${FINDEREXTRAS_SIGNING_IDENTITY:--}"
codesign --force --sign "$SIGNING_IDENTITY" --entitlements Extension/Entitlements.plist "$EXT"
codesign --force --sign "$SIGNING_IDENTITY" "$APP"
codesign --verify --deep --strict "$APP"
echo "$APP"
