#!/usr/bin/env python3
"""Validate Gen1 Achievements' title-scoped catalog and localization contract."""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GAMES = [
    "red", "blue", "yellow",
    "gold", "silver", "crystal",
    "firered", "leafgreen", "ruby", "sapphire", "emerald",
]
LANGUAGES = ["en", "pt-BR", "es"]
OPERATORS = {"any", "equals", "at_least", "truthy"}
MODES = {"instant", "counter"}
EVENTS = {
    "pokemon.caught",
    "pokemon.level_up",
    "pokemon.evolved",
    "pokemon.move_learned",
    "battle.ended",
    "battle.started",
    "map.entered",
}


def load_json(relative: str):
    with (ROOT / relative).open("r", encoding="utf-8") as handle:
        return json.load(handle)


def validate_catalog() -> int:
    manifest = load_json("manifest.json")
    games_data = load_json("data/games.json")
    catalog_data = load_json("data/achievements.json")
    locales = load_json("data/ui_locales.json")

    assert manifest.get("api") == 3, "manifest must target Portable Mod API 3"
    assert manifest.get("games") == GAMES, "manifest must list all eleven games"
    assert [row.get("id") for row in games_data.get("games", [])] == GAMES
    assert catalog_data.get("catalog_source") == "achievements.tsv"
    assert list(catalog_data.get("games", {}).keys()) == GAMES
    assert catalog_data.get("supported_languages") == LANGUAGES
    assert list(locales.keys()) == LANGUAGES
    required_locale_keys = {
        "menu", "title", "progress", "all", "unlocked_filter",
        "locked_filter", "unlocked", "locked", "hidden_title",
        "hidden_description", "empty_title", "empty_description",
        "details", "back", "filter", "notification",
    }
    for language in LANGUAGES:
        assert required_locale_keys <= set(locales[language]), (
            f"{language}: missing localized UI strings"
        )

    locale_rows: dict[str, dict[str, str]] = {language: {} for language in LANGUAGES}
    with (ROOT / "data/ui_locales.tsv").open("r", encoding="utf-8") as handle:
        for raw in handle:
            line = raw.rstrip()
            if not line or line.startswith("#"):
                continue
            fields = line.split("\t")
            assert len(fields) == 3, "UI locale rows need language, key and value"
            language, key, value = fields
            assert language in LANGUAGES and key and value
            assert key not in locale_rows[language], (
                f"duplicate UI locale key: {language}.{key}"
            )
            locale_rows[language][key] = value

    for language in LANGUAGES:
        assert locale_rows[language] == locales[language], (
            f"{language}: JSON and TSV locale catalogs differ"
        )

    seen: set[str] = set()
    rows = 0
    with (ROOT / "data/achievements.tsv").open("r", encoding="utf-8") as handle:
        for line_number, raw in enumerate(handle, start=1):
            line = raw.rstrip("\r\n")
            if not line or line.startswith("#"):
                continue
            fields = line.split("\t")
            assert len(fields) == 15, (
                f"row {line_number}: expected 15 tab-separated columns, got {len(fields)}"
            )
            (game, achievement_id, event, match_field, operator, match_value,
             mode, target, secret, title_en, desc_en, title_pt, desc_pt,
             title_es, desc_es) = fields

            assert game in GAMES, f"row {line_number}: unknown game {game!r}"
            assert achievement_id and achievement_id.replace("_", "").replace("-", "").isalnum()
            assert achievement_id not in seen, f"duplicate achievement id: {achievement_id}"
            seen.add(achievement_id)
            assert event in EVENTS, f"row {line_number}: unverified event {event!r}"
            assert operator in OPERATORS, f"row {line_number}: invalid operator"
            assert mode in MODES, f"row {line_number}: invalid mode"
            assert secret in {"true", "false"}
            assert all(value.strip() for value in (
                title_en, desc_en, title_pt, desc_pt, title_es, desc_es
            )), f"row {line_number}: every achievement requires all translations"
            if mode == "counter":
                assert target.isdigit() and int(target) > 0, (
                    f"row {line_number}: counter target must be a positive integer"
                )
            else:
                assert target in {"", "0"}, f"row {line_number}: instant target must be empty"

            rows += 1

    print(
        f"Catalog contract OK: {len(GAMES)} independent games, "
        f"{rows} achievements, {len(LANGUAGES)} languages."
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(validate_catalog())
    except (AssertionError, OSError, json.JSONDecodeError) as error:
        print(f"Validation failed: {error}", file=sys.stderr)
        raise SystemExit(1)
