#!/bin/bash
set -euo pipefail
task_root=$(cd -- "$(dirname -- "$0")/.." && pwd)
if [[ $# != 2 ]]; then
    printf 'Usage: package-dmg.sh APP_PATH OUTPUT_DMG\n' >&2
    exit 1
fi
task_app="$1"
task_dmg="$2"
task_python="${RELEASE_PYTHON:-python3}"
if ! "$task_python" -c 'import dmgbuild' 2>/dev/null; then
    printf 'DMG packaging needs requirements-release.txt. See docs/distribution.md.\n' >&2
    exit 1
fi
task_temporary=$(mktemp -d "${TMPDIR:-/tmp}/pawlet-dmg.XXXXXX")
task_mounted=false
cleanup() {
    if [[ "$task_mounted" == true ]]; then
        # Leave a failed-to-detach mount recoverable rather than deleting into it.
        hdiutil detach "$task_temporary/verify" >/dev/null || return
    fi
    rm -rf "$task_temporary"
}
trap cleanup EXIT
mkdir -p "$task_temporary/art" "$task_temporary/module-cache" "$(dirname -- "$task_dmg")"
xcrun swiftc "$task_root/Tools/make-dmg-background.swift" \
    -module-cache-path "$task_temporary/module-cache" -o "$task_temporary/render"
"$task_temporary/render" "$task_root/Resources" "$task_temporary/art"
tiffutil -cathidpicheck "$task_temporary/art/background.png" \
    "$task_temporary/art/background@2x.png" -out "$task_temporary/art/background.tiff" >/dev/null
"$task_python" -m dmgbuild -s "$task_root/Tools/dmg-settings.py" \
    -D "app=$task_app" -D "readme=$task_root/docs/INSTALL.txt" \
    -D "icon=$task_root/Resources/AppIcon.icns" \
    -D "background=$task_temporary/art/background.tiff" \
    'Pawlet' "$task_dmg"

# Verify the exact signed bundle stored in the finished image, after all Finder
# decoration has been applied. Metadata changes can break an otherwise valid app.
mkdir "$task_temporary/verify"
hdiutil attach -readonly -nobrowse -mountpoint "$task_temporary/verify" "$task_dmg" >/dev/null
task_mounted=true
codesign --verify --deep --strict "$task_temporary/verify/Pawlet.app"
cmp "$task_app/Contents/MacOS/Pawlet" "$task_temporary/verify/Pawlet.app/Contents/MacOS/Pawlet"
hdiutil detach "$task_temporary/verify" >/dev/null
task_mounted=false
