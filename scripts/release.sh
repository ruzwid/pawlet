#!/bin/bash
set -euo pipefail
task_root=$(cd -- "$(dirname -- "$0")/.." && pwd)
task_output="${BUILD_OUTPUT:-$task_root/build}"
task_dist="${DIST_OUTPUT:-$task_root/dist}"
task_temporary=$(mktemp -d "${TMPDIR:-/tmp}/pawlet-release.XXXXXX")
trap 'rm -rf "$task_temporary"' EXIT
task_app="$task_output/Pawlet.app"
task_version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$task_root/Resources/Info.plist")
if ! "${RELEASE_PYTHON:-python3}" -c 'import dmgbuild' 2>/dev/null; then
    printf 'Release packaging needs requirements-release.txt. See docs/distribution.md.\n' >&2
    exit 1
fi
if [[ -n "${NOTARY_PROFILE:-}" && -z "${SIGN_IDENTITY:-}" ]]; then
    printf 'NOTARY_PROFILE requires a Developer ID SIGN_IDENTITY.\n' >&2; exit 1
fi
ARCHS='arm64 x86_64' BUILD_OUTPUT="$task_output" bash "$task_root/scripts/build.sh"
"$task_app/Contents/MacOS/Pawlet" --self-test
codesign --verify --deep --strict "$task_app"
xcrun lipo "$task_app/Contents/MacOS/Pawlet" -verify_arch arm64 x86_64
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    ditto -c -k --sequesterRsrc --keepParent "$task_app" "$task_temporary/notarize.zip"
    xcrun notarytool submit "$task_temporary/notarize.zip" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$task_app"
    xcrun stapler validate "$task_app"
fi
mkdir -p "$task_dist"
mkdir -p "$task_temporary/zip"
ditto "$task_app" "$task_temporary/zip/Pawlet.app"
cp "$task_root/docs/INSTALL.txt" "$task_temporary/zip/Read Me.txt"
ditto -c -k --sequesterRsrc "$task_temporary/zip" "$task_dist/Pawlet-$task_version-Mac.zip"
bash "$task_root/scripts/package-dmg.sh" "$task_app" "$task_dist/Pawlet-$task_version-Mac.dmg"
if [[ -n "${SIGN_IDENTITY:-}" ]]; then codesign --force --sign "$SIGN_IDENTITY" --timestamp "$task_dist/Pawlet-$task_version-Mac.dmg"; fi
(
    cd "$task_dist"
    shasum -a 256 "Pawlet-$task_version-Mac.zip" "Pawlet-$task_version-Mac.dmg" > SHA256SUMS.txt
)
printf 'Release artifacts: %s\n' "$task_dist"
