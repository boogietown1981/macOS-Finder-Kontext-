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
if pgrep -x FinderExtras >/dev/null; then
    echo "Bitte FinderExtras über das Menüleistensymbol beenden und diesen Installer erneut starten."
    exit 1
fi
if [[ -e "$APP" ]]; then
    EXISTING_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")
    [[ "$EXISTING_ID" == "de.itso.FinderExtras" ]] || { echo "Unerwartete App am Ziel; Abbruch."; exit 1; }
fi
BUILD="$(mktemp -d "${TMPDIR:-/tmp}/finderextras.XXXXXX")"
trap 'rm -rf "$BUILD"' EXIT
bash Build.command "$BUILD"
BUNDLE="$BUILD/FinderExtras.app"
mkdir -p "$HOME/Applications"
if [[ -e "$APP" ]]; then
    BACKUP="$HOME/Library/Application Support/FinderExtras/Backups/$(date +%Y%m%d-%H%M%S)-$$.zip"
    mkdir -p "$(dirname "$BACKUP")"
    /usr/bin/ditto -c -k --keepParent "$APP" "$BACKUP"
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$APP" || true
    OLD="$BUILD/Previous-FinderExtras.app"
    mv "$APP" "$OLD"
    if ! mv "$BUNDLE" "$APP"; then
        mv "$OLD" "$APP"
        exit 1
    fi
    echo "Sicherung der alten Version: $BACKUP"
else
    mv "$BUNDLE" "$APP"
fi
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP"
# Ask the user-session Services agent to refresh; never reset global preferences.
if [[ -x /System/Library/CoreServices/pbs ]]; then
    /System/Library/CoreServices/pbs -update || echo "Dienste bitte nach Ab-/Anmelden erneut prüfen."
fi
/usr/bin/pluginkit -a "$APP/Contents/PlugIns/FinderExtrasSync.appex"
open "$APP"
echo "Installiert: $APP"
echo "Die Einrichtung steht unter FinderExtras → Einrichtung & Status."
