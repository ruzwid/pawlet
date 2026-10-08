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
trap 'rm -rf "$task_temporary"' EXIT
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
