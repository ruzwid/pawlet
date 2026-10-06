#!/usr/bin/env python3
"""Fail if PawletTheme hex roles diverge from shared/tokens/pawlet.tokens.json."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
JSON_PATH = ROOT / "shared" / "tokens" / "pawlet.tokens.json"
THEME_SWIFT = ROOT / "Sources" / "Pawlet" / "design-theme.swift"

ROLE_PATTERN = re.compile(
    r"static\s+let\s+(\w+)\s*=\s*color\(\s*light:\s*0x([0-9A-Fa-f]+)\s*,\s*dark:\s*0x([0-9A-Fa-f]+)\s*\)"
)


def fail(message: str) -> None:
    print(f"check-tokens: {message}", file=sys.stderr)
    raise SystemExit(1)


def hex_to_css(value: str) -> str:
    if len(value) > 6:
        fail(f"Swift hex 0x{value} is longer than 6 digits")
    return f"#{value.upper().zfill(6)}"


def parse_swift_roles(source: str) -> dict[str, dict[str, str]]:
    roles: dict[str, dict[str, str]] = {}
    for match in ROLE_PATTERN.finditer(source):
        name, light, dark = match.group(1), match.group(2), match.group(3)
        if name in roles:
            fail(f"duplicate Swift role `{name}`")
        roles[name] = {"light": hex_to_css(light), "dark": hex_to_css(dark)}
    if not roles:
        fail(f"no PawletTheme color roles in {THEME_SWIFT.relative_to(ROOT)}")
    return roles


def css_hex(value: object, path: str) -> str:
    if not isinstance(value, str) or not re.fullmatch(r"#[0-9A-Fa-f]{6}", value):
        fail(f"{path} must be a #RRGGBB string")
    return value.upper()


def parse_json_roles(data: object) -> dict[str, dict[str, str]]:
    if not isinstance(data, dict):
        fail("pawlet.tokens.json root must be an object")
    color = data.get("color")
    if not isinstance(color, dict) or not color:
        fail("pawlet.tokens.json: `color` must be a non-empty object")
    roles: dict[str, dict[str, str]] = {}
    for name, pair in color.items():
        if not isinstance(pair, dict):
            fail(f"color.{name} must be an object with light and dark")
        extra = set(pair) - {"light", "dark"}
        if extra:
            fail(f"color.{name} has unexpected keys {sorted(extra)}")
        if "light" not in pair or "dark" not in pair:
            fail(f"color.{name} must include light and dark")
        roles[name] = {
            "light": css_hex(pair["light"], f"color.{name}.light"),
            "dark": css_hex(pair["dark"], f"color.{name}.dark"),
        }
    return roles


def main() -> None:
    if not JSON_PATH.is_file():
        fail(f"missing {JSON_PATH.relative_to(ROOT)}")
    if not THEME_SWIFT.is_file():
        fail(f"missing {THEME_SWIFT.relative_to(ROOT)}")

    swift_roles = parse_swift_roles(THEME_SWIFT.read_text(encoding="utf-8"))
    json_roles = parse_json_roles(json.loads(JSON_PATH.read_text(encoding="utf-8")))

    errors: list[str] = []
    swift_names = set(swift_roles)
    json_names = set(json_roles)
    for name in sorted(swift_names - json_names):
        errors.append(f"JSON missing role `{name}`")
    for name in sorted(json_names - swift_names):
        errors.append(f"JSON extra role `{name}`")
    for name in sorted(swift_names & json_names):
        for mode in ("light", "dark"):
            swift_hex = swift_roles[name][mode]
            json_hex = json_roles[name][mode]
            if swift_hex != json_hex:
                errors.append(f"{name}.{mode}: Swift {swift_hex} != JSON {json_hex}")

    if errors:
        for line in errors:
            print(f"check-tokens: {line}", file=sys.stderr)
        raise SystemExit(1)

    print(f"check-tokens: ok ({len(swift_roles)} color roles)")


if __name__ == "__main__":
    main()
