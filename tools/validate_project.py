#!/usr/bin/env python3
"""Static validation for the cleaned Starforge Godot prototype."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def rel(path: Path) -> str:
    return str(path.relative_to(ROOT)).replace("\\", "/")


def parse_json_files() -> list[str]:
    errors: list[str] = []
    for path in sorted((ROOT / "data").rglob("*.json")):
        try:
            json.loads(path.read_text(encoding="utf-8"))
        except Exception as exc:  # noqa: BLE001 - report every parse failure
            errors.append(f"{rel(path)}: invalid JSON: {exc}")
    return errors


def validate_dialogue_graphs() -> list[str]:
    errors: list[str] = []
    dialogue_root = ROOT / "data" / "dialogue"
    for path in sorted(dialogue_root.glob("*.json")):
        payload = json.loads(path.read_text(encoding="utf-8"))
        nodes = payload.get("nodes", {})
        if not isinstance(nodes, dict) or not nodes:
            errors.append(f"{rel(path)}: nodes must be a non-empty object")
            continue
        start = payload.get("start_node") or payload.get("start") or "start"
        if start not in nodes:
            errors.append(f"{rel(path)}: start node {start!r} missing")
        for node_id, node in nodes.items():
            if not isinstance(node, dict):
                errors.append(f"{rel(path)}:{node_id}: node must be object")
                continue
            next_node = node.get("next")
            if isinstance(next_node, str) and next_node != "end" and next_node not in nodes:
                errors.append(f"{rel(path)}:{node_id}: next target {next_node!r} missing")
            for choice in node.get("choices", []):
                target = choice.get("next")
                if isinstance(target, str) and target != "end" and target not in nodes:
                    errors.append(f"{rel(path)}:{node_id}: choice target {target!r} missing")
    return errors


def validate_quest_locations() -> list[str]:
    errors: list[str] = []
    quest_root = ROOT / "data" / "quests"
    locations = {path.stem for path in quest_root.glob("*.json")}
    graph_path = ROOT / "data" / "act1_location_graph.json"
    if graph_path.exists():
        graph = json.loads(graph_path.read_text(encoding="utf-8"))
        if isinstance(graph, dict):
            locations.update(graph.keys())

    for path in sorted(quest_root.glob("*.json")):
        payload = json.loads(path.read_text(encoding="utf-8"))
        for action in payload.get("actions", []):
            target = action.get("target_location")
            if target and target not in locations:
                errors.append(f"{rel(path)}: target_location {target!r} missing")
    return errors


def validate_project_paths() -> list[str]:
    errors: list[str] = []
    project_path = ROOT / "project.godot"
    text = project_path.read_text(encoding="utf-8")

    main_match = re.search(r'run/main_scene="res://([^"]+)"', text)
    if not main_match:
        errors.append("project.godot: run/main_scene missing")
    elif not (ROOT / main_match.group(1)).exists():
        errors.append(f"project.godot: main scene missing: {main_match.group(1)}")

    for match in re.finditer(r'="\*?res://([^"]+)"', text):
        target = ROOT / match.group(1)
        if not target.exists():
            errors.append(f"project.godot: missing resource {match.group(1)}")
    return errors


def validate_clean_copy() -> list[str]:
    errors: list[str] = []
    forbidden = {".godot", ".beads", "daemon", "mayor", "refinery", "polecats"}
    unreleased_act = re.compile(r"act([2-9]|[1-9][0-9])", re.IGNORECASE)
    for path in ROOT.iterdir():
        if path.name in forbidden:
            errors.append(f"forbidden workshop/editor state present: {path.name}")
    for path in ROOT.rglob("*"):
        if ".git" in path.parts:
            continue
        if any(unreleased_act.search(part) for part in path.parts):
            errors.append(f"unreleased act reference in public source path: {rel(path)}")
    return errors


def main() -> int:
    checks = [
        parse_json_files,
        validate_dialogue_graphs,
        validate_quest_locations,
        validate_project_paths,
        validate_clean_copy,
    ]
    errors: list[str] = []
    for check in checks:
        errors.extend(check())

    if errors:
        print("validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
