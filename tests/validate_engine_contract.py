#!/usr/bin/env python3
"""Check achievement conditions against a pinned Portable Mod API event contract."""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONTRACT_PATH = ROOT / "tests" / "engine_event_contract.json"
CATALOG_PATH = ROOT / "data" / "achievements.tsv"
GAMES = {
    "red": 1, "blue": 1, "yellow": 1,
    "gold": 2, "silver": 2, "crystal": 2,
    "firered": 3, "leafgreen": 3, "ruby": 3,
    "sapphire": 3, "emerald": 3,
}
NUMERIC_TYPES = {"number", "integer"}


def read_rows() -> list[tuple[int, list[str]]]:
    rows: list[tuple[int, list[str]]] = []
    with CATALOG_PATH.open("r", encoding="utf-8") as handle:
        for line_number, raw in enumerate(handle, start=1):
            line = raw.rstrip("\r\n")
            if not line or line.startswith("#"):
                continue
            fields = line.split("\t")
            if len(fields) != 15:
                raise ValueError(
                    f"line {line_number}: expected 15 columns, found {len(fields)}"
                )
            rows.append((line_number, fields))
    return rows


def field_types(event: dict, field: str, generation: int) -> set[str]:
    declaration = event.get("fields", {}).get(field)
    if declaration is None:
        return set()
    value = declaration.get(str(generation))
    if isinstance(value, str):
        return {value}
    if isinstance(value, list):
        return set(value)
    return set()


def compatible_literal(value: str, types: set[str]) -> bool:
    if "string" in types and value != "":
        return True
    if "boolean" in types and value in {"true", "false"}:
        return True
    if types & NUMERIC_TYPES:
        try:
            number = float(value)
        except ValueError:
            return False
        if not math.isfinite(number):
            return False
        if "integer" in types and number.is_integer():
            return True
        if "number" in types:
            return True
    return False


def validate() -> int:
    contract = json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))
    source = contract.get("source", {})
    assert contract.get("schema_version") == 1, "unsupported contract schema version"
    assert source.get("repository") == "bryanthaboi/gen1recomp"
    assert source.get("commit") == "825f1670aeecb4a72345fb473d287fd8ea502ad2", (
        "update the pinned event contract source deliberately when changing revisions"
    )
    assert contract.get("games") == GAMES, "engine contract game map does not match the mod"
    events = contract.get("events", {})
    rows = read_rows()
    assert rows, "achievement catalog is empty"

    checked = set()
    for line_number, row in rows:
        game, achievement_id, event_name, field, operator, encoded = row[:6]
        assert game in GAMES, f"line {line_number}: unknown game {game!r}"
        generation = GAMES[game]
        declaration = events.get(event_name)
        assert declaration is not None, (
            f"line {line_number} ({achievement_id}): event {event_name!r} "
            "has no pinned engine contract"
        )
        assert generation in declaration.get("generations", []), (
            f"line {line_number} ({achievement_id}): {event_name} has no "
            f"call site in Gen {generation}"
        )

        if operator == "any":
            assert field == "*", (
                f"line {line_number} ({achievement_id}): operator any requires field *"
            )
        else:
            assert field != "*", (
                f"line {line_number} ({achievement_id}): {operator} requires a field"
            )
            types = field_types(declaration, field, generation)
            assert types, (
                f"line {line_number} ({achievement_id}): "
                f"{event_name}.{field} is not declared for Gen {generation}"
            )

            if operator == "truthy":
                assert types == {"boolean"} and encoded == "true", (
                    f"line {line_number} ({achievement_id}): truthy requires "
                    "a boolean field and the true value"
                )
            elif operator == "at_least":
                assert types & NUMERIC_TYPES and compatible_literal(encoded, NUMERIC_TYPES), (
                    f"line {line_number} ({achievement_id}): at_least requires "
                    "a numeric field and numeric threshold"
                )
            elif operator == "ends_with":
                assert types == {"string"} and encoded, (
                    f"line {line_number} ({achievement_id}): ends_with requires "
                    "a nonempty string field and suffix"
                )
            elif operator in {"equals", "one_of", "one_of_true"}:
                values = encoded.split("|") if operator != "equals" else [encoded]
                assert all(values), (
                    f"line {line_number} ({achievement_id}): empty comparison value"
                )
                assert all(compatible_literal(value, types) for value in values), (
                    f"line {line_number} ({achievement_id}): comparison values "
                    f"{values!r} do not match {event_name}.{field} types {sorted(types)}"
                )
                if operator == "one_of_true":
                    value_types = field_types(declaration, "value", generation)
                    assert value_types == {"boolean"}, (
                        f"line {line_number} ({achievement_id}): one_of_true "
                        "requires event.value to be boolean"
                    )
            else:
                raise AssertionError(
                    f"line {line_number} ({achievement_id}): unknown operator {operator!r}"
                )

        checked.add(event_name)

    assert checked == set(events), (
        "the event contract and catalog must cover exactly the same event names; "
        f"unused contracts={sorted(set(events) - checked)}, "
        f"missing contracts={sorted(checked - set(events))}"
    )
    print(
        f"Engine event contract OK: {len(rows)} catalog rows checked against "
        f"{len(checked)} event contracts (Gen 1, 2 and 3; source {source.get('commit')[:8]})."
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(validate())
    except (AssertionError, OSError, ValueError, json.JSONDecodeError) as error:
        print(f"Engine contract validation failed: {error}", file=sys.stderr)
        raise SystemExit(1)
