#!/usr/bin/env python3
"""Deterministic playtest audit for the Godot RPG prototype data."""

from __future__ import annotations

import json
import re
from collections import deque
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
QUEUE_MARKERS = re.compile(r"\b(TODO|FIXME|DEAD[- ]?LETTER|PLAYTEST[- ]?QUEUE|BALANCE[- ]?QUEUE)\b|\bBUG:", re.IGNORECASE)


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def load_json_dir(path: Path) -> dict[str, dict]:
    return {item.stem: load_json(item) for item in sorted(path.glob("*.json"))}


def main() -> int:
    errors: list[str] = []
    warnings: list[str] = []

    graph = load_json(ROOT / "data" / "act1_location_graph.json").get("locations", {})
    enemies = load_json_dir(ROOT / "data" / "enemies")
    encounters = load_json_dir(ROOT / "data" / "encounters")
    quests = load_json_dir(ROOT / "data" / "quests")

    location_ids = set(graph)
    for location_id, location in graph.items():
        for target in location.get("connections", []):
            if target not in location_ids:
                errors.append(f"location {location_id}: missing connection target {target}")
            elif location_id not in graph[target].get("connections", []):
                warnings.append(f"location {location_id}: one-way connection to {target}")

    start = "act1_site_k9"
    reached: set[str] = set()
    queue: deque[str] = deque([start])
    while queue:
        current = queue.popleft()
        if current in reached or current not in graph:
            continue
        reached.add(current)
        queue.extend(graph[current].get("connections", []))

    for location_id in sorted(location_ids - reached):
        warnings.append(f"location is not directly reachable from {start}; verify story unlock: {location_id}")

    for quest_id, quest in quests.items():
        if quest_id not in location_ids:
            warnings.append(f"quest has no matching location id: {quest_id}")
        for action in quest.get("actions", []):
            target = action.get("target_location")
            if target and target not in location_ids:
                errors.append(f"quest {quest_id}: missing target_location {target}")

    threat_scores = []
    for encounter_id, encounter in encounters.items():
        total_hp = 0
        total_attack = 0
        for wave in encounter.get("waves", []):
            for entry in wave.get("enemies", []):
                enemy_id = entry.get("type")
                count = int(entry.get("count", 1))
                if enemy_id not in enemies:
                    errors.append(f"encounter {encounter_id}: missing enemy {enemy_id}")
                    continue
                enemy = enemies[enemy_id]
                total_hp += int(enemy.get("hp_max", 0)) * count
                total_attack += int(enemy.get("attack", 0)) * count
        threat_scores.append((encounter_id, total_hp, total_attack))
        if total_hp <= 0 or total_attack <= 0:
            errors.append(f"encounter {encounter_id}: threat score is zero")

    marker_hits = []
    for path in [*ROOT.glob("data/**/*.json"), *ROOT.glob("scripts/**/*.gd")]:
        text = path.read_text(encoding="utf-8", errors="replace")
        for line_no, line in enumerate(text.splitlines(), start=1):
            if QUEUE_MARKERS.search(line):
                marker_hits.append(f"{path.relative_to(ROOT).as_posix()}:{line_no}: {line.strip()}")
    warnings.extend(marker_hits)

    print("Godot playtest audit")
    print(f"- locations: {len(graph)}")
    print(f"- reachable locations: {len(reached)}")
    print(f"- quests: {len(quests)}")
    print(f"- encounters: {len(encounters)}")
    print(f"- enemies: {len(enemies)}")
    print(f"- dead-letter marker hits: {len(marker_hits)}")
    if threat_scores:
        min_threat = min(threat_scores, key=lambda item: item[1] + item[2])
        max_threat = max(threat_scores, key=lambda item: item[1] + item[2])
        print(f"- lowest encounter threat: {min_threat[0]} hp={min_threat[1]} atk={min_threat[2]}")
        print(f"- highest encounter threat: {max_threat[0]} hp={max_threat[1]} atk={max_threat[2]}")

    if warnings:
        print("\nDead-letter / balance queue:")
        for warning in warnings[:50]:
            print(f"- {warning}")
        if len(warnings) > 50:
            print(f"- ... {len(warnings) - 50} more queue item(s)")

    if errors:
        print("\nplaytest audit failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("playtest audit passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())


