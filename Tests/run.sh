#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
TMP_TEST="$(mktemp -d)"
MOUNT=""
cleanup() {
 if [[ -n "$MOUNT" ]]; then hdiutil detach "$MOUNT" >/dev/null || true; fi
 rm -rf "$TMP_TEST"
}
trap cleanup EXIT
xcrun swiftc -swift-version 5 Sources/TransferEngine.swift Tests/main.swift -o "$TMP_TEST/tests"
"$TMP_TEST/tests"
if [[ "${TEST_CROSS_VOLUME:-0}" == 1 ]]; then
 hdiutil create -size 32m -fs HFS+ -volname FinderExtrasTest "$TMP_TEST/test.dmg" >/dev/null
 MOUNT="$TMP_TEST/volume"
 mkdir "$MOUNT"
 hdiutil attach "$TMP_TEST/test.dmg" -mountpoint "$MOUNT" -nobrowse >/dev/null
 "$TMP_TEST/tests" "$MOUNT"
fi
