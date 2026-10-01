#!/bin/bash
set -euo pipefail
task_root=$(cd -- "$(dirname -- "$0")/.." && pwd)
task_output="${BUILD_OUTPUT:-$task_root/build}"
task_binary="$task_output/Desktop Pets.app/Contents/MacOS/DesktopPets"
if [[ ! -x "$task_binary" ]]; then bash "$task_root/scripts/build.sh"; fi
"$task_binary" --self-test
"${PYTHON:-python3}" -m unittest discover -s "$task_root/Tests" -p 'test_*.py' -v
if [[ "${1:-}" == "--ui" ]]; then
    mkdir -p "$task_output/ui-test"
    "$task_binary" --ui-smoke-test "$task_output/ui-test"
fi
