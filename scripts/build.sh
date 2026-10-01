#!/bin/bash
set -euo pipefail
task_root=$(cd -- "$(dirname -- "$0")/.." && pwd)
task_output="${BUILD_OUTPUT:-$task_root/build}"
task_temporary=$(mktemp -d "${TMPDIR:-/tmp}/pawlet-build.XXXXXX")
trap 'rm -rf "$task_temporary"' EXIT
task_app="$task_output/Pawlet.app"
task_sdk=$(xcrun --show-sdk-path)
mkdir -p "$task_app/Contents/MacOS" "$task_app/Contents/Resources" "$task_temporary/module-cache"
for task_arch in ${ARCHS:-arm64 x86_64}; do
    xcrun swiftc -O -swift-version 5 -target "$task_arch-apple-macosx13.0" \
        -sdk "$task_sdk" -module-cache-path "$task_temporary/module-cache" \
        "$task_root"/Sources/Pawlet/*.swift "$task_root/Tests/project-tests.swift" \
        -o "$task_temporary/Pawlet-$task_arch"
done
task_binaries=("$task_temporary"/Pawlet-*)
if [[ ${#task_binaries[@]} -gt 1 ]]; then
    xcrun lipo -create "${task_binaries[@]}" -output "$task_app/Contents/MacOS/Pawlet"
else
    cp "${task_binaries[0]}" "$task_app/Contents/MacOS/Pawlet"
fi
cp "$task_root/Resources/Info.plist" "$task_app/Contents/Info.plist"
cp "$task_root/LICENSE" "$task_app/Contents/Resources/LICENSE.txt"
ditto "$task_root/Resources/Pets" "$task_app/Contents/Resources/Pets"
ditto "$task_root/.agents/skills/create-desktop-pet" "$task_app/Contents/Resources/CreationSkill"
if [[ -f "$task_root/Resources/AppIcon.icns" ]]; then cp "$task_root/Resources/AppIcon.icns" "$task_app/Contents/Resources/"; fi
cp "$task_root/Resources/PawMark.png" "$task_app/Contents/Resources/"
chmod +x "$task_app/Contents/MacOS/Pawlet"
if [[ -n "${SIGN_IDENTITY:-}" ]]; then
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$task_app"
else
    codesign --force --sign - --timestamp=none "$task_app"
fi
printf 'Built %s\n' "$task_app"
