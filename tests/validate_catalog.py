#!/usr/bin/env python3
"""Validate the localized catalog, event coverage and balanced per-title totals."""

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
OPERATORS = {"any", "equals", "at_least", "truthy", "one_of", "one_of_true", "ends_with"}
MODES = {"instant", "counter"}
BASE_EVENTS = {
    "pokemon.caught", "pokemon.level_up", "pokemon.evolved",
    "pokemon.move_learned", "battle.ended", "battle.started",
    "map.entered", "flag.changed",
}
GEN2_EVENTS = {
    "bug_contest.scored", "unown.unlocked", "apricorn.converted",
    "egg.hatched", "pokerus.infected", "happiness.changed",
}
GEN3_EVENTS = {"egg.hatched", "pokerus.infected", "happiness.changed"}
# One signature objective per title. These assertions make the catalog's
# per-game identity a checked contract rather than a naming convention.
SIGNATURES = {
    "red": ("red_electabuzz_captured",
            ("pokemon.caught", "species", "equals", "ELECTABUZZ", "instant", "")),
    "blue": ("blue_magmar_captured",
             ("pokemon.caught", "species", "equals", "MAGMAR", "instant", "")),
    "yellow": ("yellow_pikachu_growth_15",
               ("pokemon.level_up", "mon.species", "equals", "PIKACHU", "counter", "15")),
    "gold": ("gold_mankey_captured",
             ("pokemon.caught", "species", "equals", "MANKEY", "instant", "")),
    "silver": ("silver_delibird_captured",
               ("pokemon.caught", "species", "equals", "DELIBIRD", "instant", "")),
    "crystal": ("crystal_battle_tower_entered",
                ("map.entered", "mapId", "ends_with", "BATTLE_TOWER_1F", "instant", "")),
    "firered": ("firered_wooper_captured",
                ("pokemon.caught", "species", "equals", "WOOPER", "instant", "")),
    "leafgreen": ("leafgreen_slowpoke_captured",
                  ("pokemon.caught", "species", "equals", "SLOWPOKE", "instant", "")),
    "ruby": ("ruby_zangoose_captured",
             ("pokemon.caught", "species", "equals", "ZANGOOSE", "instant", "")),
    "sapphire": ("sapphire_seviper_captured",
                 ("pokemon.caught", "species", "equals", "SEVIPER", "instant", "")),
    "emerald": ("emerald_battle_frontier_tower_entered",
                ("map.entered", "mapId", "ends_with",
                 "BATTLE_FRONTIER_BATTLE_TOWER_LOBBY", "instant", "")),
}
SUPPORTED_EVENTS = {}
for game in ("red", "blue", "yellow"):
    SUPPORTED_EVENTS[game] = BASE_EVENTS
for game in ("gold", "silver", "crystal"):
    SUPPORTED_EVENTS[game] = BASE_EVENTS | GEN2_EVENTS
for game in ("firered", "leafgreen", "ruby", "sapphire", "emerald"):
    SUPPORTED_EVENTS[game] = BASE_EVENTS | GEN3_EVENTS


def load_json(relative: str):
    with (ROOT / relative).open("r", encoding="utf-8") as handle:
        return json.load(handle)


def valid_field_path(value: str) -> bool:
    if value == "*":
        return True
    if not value or value.startswith(".") or value.endswith(".") or ".." in value:
        return False
    return all(part.replace("_", "").isalnum() for part in value.split("."))


def validate_catalog() -> int:
    manifest = load_json("manifest.json")
    fullscreen_fit = load_json("addons/fullscreen_fit/manifest.json")
    games_data = load_json("data/games.json")
    catalog_data = load_json("data/achievements.json")
    locales = load_json("data/ui_locales.json")

    assert manifest.get("api") == 3, "manifest must target Portable Mod API 3"
    assert manifest.get("games") == GAMES, "manifest must list all eleven games"
    assert fullscreen_fit.get("id") == "fullscreen_fit"
    assert fullscreen_fit.get("api") == 3
    assert fullscreen_fit.get("entry") == "main.lua"
    assert fullscreen_fit.get("games") == ["all"]
    assert fullscreen_fit.get("version") == "1.0.0"
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

    locale_rows = {language: {} for language in LANGUAGES}
    with (ROOT / "data/ui_locales.tsv").open("r", encoding="utf-8") as handle:
        for raw in handle:
            line = raw.rstrip("\r\n")
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

    seen = set()
    ids_by_game = {game: [] for game in GAMES}
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
            assert event in SUPPORTED_EVENTS[game], (
                f"row {line_number}: {event!r} is not available for {game}"
            )
            assert valid_field_path(match_field), (
                f"row {line_number}: invalid event field path {match_field!r}"
            )
            assert operator in OPERATORS, f"row {line_number}: invalid operator"
            if operator == "equals":
                assert match_value != "", f"row {line_number}: equals requires a value"
            if operator in {"one_of", "one_of_true"}:
                values = match_value.split("|")
                assert all(values) and len(values) == len(set(values)), (
                    f"row {line_number}: one_of needs unique, nonempty pipe-separated values"
                )
            if operator == "ends_with":
                assert match_field == "mapId" and match_value.strip(), (
                    f"row {line_number}: ends_with is reserved for nonempty mapId suffixes"
                )
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
                assert target in {"", "0"}, (
                    f"row {line_number}: instant target must be empty"
                )

            ids_by_game[game].append(achievement_id)
            rows += 1

    for game in GAMES:
        count = len(ids_by_game[game])
        assert 19 <= count <= 20, (
            f"{game}: expected 19–20 achievements including its signature goal, got {count}"
        )
        assert catalog_data["games"][game] == ids_by_game[game], (
            f"{game}: JSON index does not match achievements.tsv"
        )

    rows_by_id = {}
    with (ROOT / "data/achievements.tsv").open("r", encoding="utf-8") as handle:
        for raw in handle:
            line = raw.rstrip("\r\n")
            if not line or line.startswith("#"):
                continue
            fields = line.split("\t")
            rows_by_id[fields[1]] = fields
    signature_contracts = set()
    for game in GAMES:
        achievement_id, expected = SIGNATURES[game]
        assert achievement_id in ids_by_game[game], (
            f"{game}: missing its own signature achievement {achievement_id}"
        )
        row = rows_by_id[achievement_id]
        observed = tuple(row[index] for index in (2, 3, 4, 5, 6, 7))
        assert observed == expected, (
            f"{game}: signature objective {achievement_id} changed its event condition"
        )
        signature_contracts.add(observed)
    assert len(signature_contracts) == len(GAMES), (
        "each game must have a distinct event condition for its signature achievement"
    )

    # Limited-time distribution and online-only events are intentionally not
    # admitted in the event allowlist above.
    forbidden_events = {"trade.completed", "pokemon.received", "link.connected"}
    assert not any(forbidden_events & events for events in SUPPORTED_EVENTS.values())

    print(
        f"Catalog contract OK: {len(GAMES)} independent games, "
        f"{rows} achievements ({min(map(len, ids_by_game.values()))}–"
        f"{max(map(len, ids_by_game.values()))} per game), "
        f"{len(LANGUAGES)} languages."
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(validate_catalog())
    except (AssertionError, OSError, json.JSONDecodeError) as error:
        print(f"Validation failed: {error}", file=sys.stderr)
        raise SystemExit(1)
