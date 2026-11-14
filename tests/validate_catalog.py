#!/usr/bin/env python3
"""Validate the data contract for Gen1 Achievements."""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SUPPORTED_GAMES = [
    "red",
    "blue",
    "yellow",
    "gold",
    "silver",
    "crystal",
    "firered",
    "leafgreen",
    "ruby",
    "sapphire",
    "emerald",
]
SUPPORTED_LANGUAGES = ["en", "pt-BR", "es"]


def load_json(relative_path: str):
    path = ROOT / relative_path
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def main() -> int:
    games_data = load_json("data/games.json")
    catalog = load_json("data/achievements.json")
    ui_locales = load_json("data/ui_locales.json")
    manifest = load_json("manifest.json")

    game_rows = games_data.get("games")
    if not isinstance(game_rows, list):
        raise AssertionError("data/games.json: 'games' must be a list")

    game_ids = [row.get("id") for row in game_rows]
    if game_ids != SUPPORTED_GAMES:
        raise AssertionError(f"Unexpected game order/list: {game_ids!r}")

    catalog_games = catalog.get("games")
    if not isinstance(catalog_games, dict):
        raise AssertionError("data/achievements.json: 'games' must be an object")
    if list(catalog_games.keys()) != SUPPORTED_GAMES:
        raise AssertionError("Every game must have its own catalog in canonical order")

    if catalog.get("supported_languages") != SUPPORTED_LANGUAGES:
        raise AssertionError("Catalog languages must be en, pt-BR and es")

    manifest_games = manifest.get("games")
    if manifest_games != SUPPORTED_GAMES:
        raise AssertionError("manifest.json must explicitly target all eleven games")
    if manifest.get("api") != 3:
        raise AssertionError("The mod must opt into Portable Mod API 3")

    if list(ui_locales.keys()) != SUPPORTED_LANGUAGES:
        raise AssertionError("UI locale files must define all three languages")

    required_ui_keys = {
        "extras",
        "achievements",
        "language",
        "unlocked",
        "locked",
        "progress",
        "completion",
        "hidden",
        "empty_title",
        "empty_description",
    }
    for language in SUPPORTED_LANGUAGES:
        missing = required_ui_keys - set(ui_locales[language])
        if missing:
            raise AssertionError(f"{language}: missing UI keys: {sorted(missing)}")

    seen_ids: set[str] = set()
    for game_id in SUPPORTED_GAMES:
        entries = catalog_games[game_id]
        if not isinstance(entries, list):
            raise AssertionError(f"{game_id}: catalog must be a list")

        for achievement in entries:
            achievement_id = achievement.get("id")
            if not isinstance(achievement_id, str) or not achievement_id:
                raise AssertionError(f"{game_id}: achievement without a valid id")
            if achievement_id in seen_ids:
                raise AssertionError(f"Duplicate achievement id across games: {achievement_id}")
            seen_ids.add(achievement_id)

            for field in ("title", "description"):
                translations = achievement.get(field)
                if not isinstance(translations, dict):
                    raise AssertionError(f"{game_id}/{achievement_id}: missing {field}")
                for language in SUPPORTED_LANGUAGES:
                    value = translations.get(language)
                    if not isinstance(value, str) or not value.strip():
                        raise AssertionError(
                            f"{game_id}/{achievement_id}: {field}.{language} is empty"
                        )

    print(
        "Catalog contract OK: "
        f"{len(SUPPORTED_GAMES)} games, "
        f"{len(seen_ids)} achievements, "
        f"{len(SUPPORTED_LANGUAGES)} languages."
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AssertionError, OSError, json.JSONDecodeError) as exc:
        print(f"Catalog validation failed: {exc}", file=sys.stderr)
        raise SystemExit(1)
