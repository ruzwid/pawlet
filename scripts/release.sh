#!/bin/bash
set -euo pipefail
task_root=$(cd -- "$(dirname -- "$0")/.." && pwd)
task_output="${BUILD_OUTPUT:-$task_root/build}"
task_dist="${DIST_OUTPUT:-$task_root/dist}"
task_temporary=$(mktemp -d "${TMPDIR:-/tmp}/pawlet-release.XXXXXX")
trap 'rm -rf "$task_temporary"' EXIT
task_app="$task_output/Pawlet.app"
task_version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$task_root/Resources/Info.plist")
if [[ -n "${NOTARY_PROFILE:-}" && -z "${SIGN_IDENTITY:-}" ]]; then
    printf 'NOTARY_PROFILE requires a Developer ID SIGN_IDENTITY.\n' >&2; exit 1
fi
BUILD_OUTPUT="$task_output" bash "$task_root/scripts/build.sh"
"$task_app/Contents/MacOS/Pawlet" --self-test
codesign --verify --deep --strict "$task_app"
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    ditto -c -k --sequesterRsrc --keepParent "$task_app" "$task_temporary/notarize.zip"
    xcrun notarytool submit "$task_temporary/notarize.zip" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$task_app"
    xcrun stapler validate "$task_app"
fi
mkdir -p "$task_dist" "$task_temporary/image"
ditto "$task_app" "$task_temporary/image/Pawlet.app"
ln -s /Applications "$task_temporary/image/Applications"
cp "$task_root/docs/INSTALL.txt" "$task_temporary/image/Read Me.txt"
ditto -c -k --sequesterRsrc --keepParent "$task_app" "$task_dist/Pawlet-$task_version-Mac.zip"
hdiutil create -volname 'Pawlet' -srcfolder "$task_temporary/image" -ov -format UDZO "$task_dist/Pawlet-$task_version-Mac.dmg"
if [[ -n "${SIGN_IDENTITY:-}" ]]; then codesign --force --sign "$SIGN_IDENTITY" --timestamp "$task_dist/Pawlet-$task_version-Mac.dmg"; fi
(
    cd "$task_dist"
    shasum -a 256 "Pawlet-$task_version-Mac.zip" "Pawlet-$task_version-Mac.dmg" > SHA256SUMS.txt
)
printf 'Release artifacts: %s\n' "$task_dist"
