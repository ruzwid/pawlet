#!/bin/bash
set -euo pipefail
task_root=$(cd -- "$(dirname -- "$0")/.." && pwd)
task_temporary=$(mktemp -d "${TMPDIR:-/tmp}/desktop-pets-icon.XXXXXX")
trap 'rm -rf "$task_temporary"' EXIT
mkdir -p "$task_temporary/AppIcon.iconset" "$task_temporary/module-cache"
xcrun swiftc "$task_root/Tools/make-icon.swift" -module-cache-path "$task_temporary/module-cache" -o "$task_temporary/make-icon"
"$task_temporary/make-icon" "$task_temporary/base.png"
for task_size in 16 32 128 256 512; do
    sips -z "$task_size" "$task_size" "$task_temporary/base.png" --out "$task_temporary/AppIcon.iconset/icon_${task_size}x${task_size}.png" >/dev/null
    task_double=$((task_size * 2))
    sips -z "$task_double" "$task_double" "$task_temporary/base.png" --out "$task_temporary/AppIcon.iconset/icon_${task_size}x${task_size}@2x.png" >/dev/null
done
iconutil -c icns "$task_temporary/AppIcon.iconset" -o "$task_root/Resources/AppIcon.icns"
