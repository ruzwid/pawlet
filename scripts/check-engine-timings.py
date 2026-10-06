#!/usr/bin/env python3
"""Fail if Mac Swift engine timings diverge from shared/engine-timings.json."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
JSON_PATH = ROOT / "shared" / "engine-timings.json"
ENGINE_SWIFT = ROOT / "Sources" / "Pawlet" / "engine.swift"
CONSTANTS_SWIFT = ROOT / "Sources" / "Pawlet" / "constants.swift"

MOTION_MAP = {
    "defaultIntervalSeconds": "DEFAULT_INTERVAL_SECONDS",
    "maxIntervalSeconds": "MAX_INTERVAL_SECONDS",
    "minSpeed": "MIN_SPEED_MULTIPLIER",
    "maxSpeed": "MAX_SPEED_MULTIPLIER",
    "minScale": "MIN_PET_SCALE",
    "maxScale": "MAX_PET_SCALE",
}


def fail(message: str) -> None:
    print(f"check-engine-timings: {message}", file=sys.stderr)
    raise SystemExit(1)


def parse_numeric_array(source: str, property_name: str) -> list[float]:
    pattern = rf"var\s+{re.escape(property_name)}\s*:\s*\w+\s*\{{\s*\[([^\]]+)\]"
    match = re.search(pattern, source)
    if not match:
        fail(f"could not find `{property_name}` array in {ENGINE_SWIFT.relative_to(ROOT)}")
    values: list[float] = []
    for token in match.group(1).split(","):
        token = token.strip()
        if not token:
            continue
        try:
            values.append(float(token))
        except ValueError:
            fail(f"non-numeric token {token!r} in `{property_name}` array")
    if not values:
        fail(f"`{property_name}` array is empty")
    return values


def parse_motion_constants(source: str) -> dict[str, float]:
    found: dict[str, float] = {}
    for json_key, swift_name in MOTION_MAP.items():
        pattern = rf"static\s+let\s+{re.escape(swift_name)}\s*=\s*([0-9]+(?:\.[0-9]+)?)"
        match = re.search(pattern, source)
        if not match:
            fail(f"could not find `{swift_name}` in {CONSTANTS_SWIFT.relative_to(ROOT)}")
        found[json_key] = float(match.group(1))
    return found


def nearly_equal(a: float, b: float) -> bool:
    return abs(a - b) <= 1e-9


def main() -> None:
    if not JSON_PATH.is_file():
        fail(f"missing {JSON_PATH.relative_to(ROOT)}")
    if not ENGINE_SWIFT.is_file():
        fail(f"missing {ENGINE_SWIFT.relative_to(ROOT)}")
    if not CONSTANTS_SWIFT.is_file():
        fail(f"missing {CONSTANTS_SWIFT.relative_to(ROOT)}")

    data = json.loads(JSON_PATH.read_text(encoding="utf-8"))
    states = data.get("states")
    motion = data.get("motion")
    if not isinstance(states, list) or not states:
        fail("shared/engine-timings.json: `states` must be a non-empty array")
    if not isinstance(motion, dict):
        fail("shared/engine-timings.json: `motion` must be an object")

    engine_source = ENGINE_SWIFT.read_text(encoding="utf-8")
    counts = parse_numeric_array(engine_source, "count")
    seconds = parse_numeric_array(engine_source, "secondsPerFrame")

    ordered = sorted(states, key=lambda s: s["row"])
    expected_rows = list(range(len(ordered)))
    actual_rows = [s["row"] for s in ordered]
    if actual_rows != expected_rows:
        fail(f"states rows must be contiguous from 0; got {actual_rows}")

    if len(counts) != len(ordered):
        fail(f"count array length {len(counts)} != states length {len(ordered)}")
    if len(seconds) != len(ordered):
        fail(f"secondsPerFrame array length {len(seconds)} != states length {len(ordered)}")

    errors: list[str] = []
    for spec, count, spf in zip(ordered, counts, seconds):
        row = spec["row"]
        state_id = spec.get("id", "?")
        if int(count) != int(spec["frameCount"]):
            errors.append(
                f"row {row} ({state_id}): count {int(count)} != frameCount {spec['frameCount']}"
            )
        if not nearly_equal(spf, float(spec["secondsPerFrame"])):
            errors.append(
                f"row {row} ({state_id}): secondsPerFrame {spf} != {spec['secondsPerFrame']}"
            )

    swift_motion = parse_motion_constants(CONSTANTS_SWIFT.read_text(encoding="utf-8"))
    for json_key, swift_name in MOTION_MAP.items():
        if json_key not in motion:
            errors.append(f"motion missing `{json_key}`")
            continue
        expected = float(motion[json_key])
        actual = swift_motion[json_key]
        if not nearly_equal(actual, expected):
            errors.append(
                f"motion.{json_key}: {swift_name}={actual} != JSON {expected}"
            )

    if errors:
        for line in errors:
            print(f"check-engine-timings: {line}", file=sys.stderr)
        raise SystemExit(1)

    print(
        f"check-engine-timings: ok ({len(ordered)} states, {len(MOTION_MAP)} motion constants)"
    )


if __name__ == "__main__":
    main()
