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
    dialogues = {path.stem: json.loads(path.read_text(encoding="utf-8")) for path in sorted(dialogue_root.glob("*.json"))}
    order = story_dialogue_order((ROOT / "autoload/story_manager.gd").read_text(encoding="utf-8"))
    for path in sorted(dialogue_root.glob("*.json")):
        payload = dialogues[path.stem]
        nodes = payload.get("nodes", {})
        if not isinstance(nodes, dict) or not nodes:
            errors.append(f"{rel(path)}: nodes must be a non-empty object")
            continue
        start = payload.get("start_node") or payload.get("start") or "start"
        if start not in nodes:
            errors.append(f"{rel(path)}: start node {start!r} missing")
        prior_flags = {
            flag for scene, earlier in dialogues.items()
            if scene in order and path.stem in order and order[scene] < order[path.stem]
            for flag in dialogue_flag_writes(earlier)
        }
        errors.extend(f"{rel(path)}: {error}" for error in validate_echo_provenance(nodes, prior_flags))
        for node_id, node in nodes.items():
            if not isinstance(node, dict):
                errors.append(f"{rel(path)}:{node_id}: node must be object")
                continue
            errors.extend(f"{rel(path)}:{node_id}: {error}" for error in validate_echoes(node))
            next_node = node.get("next")
            if isinstance(next_node, str) and next_node != "end" and next_node not in nodes:
                errors.append(f"{rel(path)}:{node_id}: next target {next_node!r} missing")
            for choice in node.get("choices", []):
                target = choice.get("next")
                if isinstance(target, str) and target != "end" and target not in nodes:
                    errors.append(f"{rel(path)}:{node_id}: choice target {target!r} missing")
    return errors


def dialogue_targets(value: object) -> set[str]:
    """Executable node successors, mirroring DialogueManager's dispatch order."""
    if not isinstance(value, dict):
        return set()
    if value.get("type") == "skill_check" or "skill_check" in value:
        check = value.get("check", value.get("skill_check", {}))
        return {value.get("on_success", check.get("on_success", check.get("success", "end"))),
                value.get("on_failure", check.get("on_failure", check.get("failure", "end")))}
    targets = displayed_node_targets(value)
    for variant in value.get("variants", []):
        targets.update(displayed_node_targets({**value, **variant}))
    return targets


def choice_targets(choice: dict) -> set[str]:
    check = choice.get("skill_check", {})
    if any(key in check for key in ["on_success", "on_failure", "success", "failure"]):
        return {check.get("on_success", check.get("success", "end")), check.get("on_failure", check.get("failure", "end"))}
    return {choice.get("next", "end")}


def displayed_node_targets(node: dict) -> set[str]:
    choices = node.get("choices", [])
    targets = {target for choice in choices for target in choice_targets(choice)}
    if not choices or all("requires_flag" in choice or "requires_reputation" in choice for choice in choices):
        targets.add(node.get("next", "end"))
    return targets


def story_dialogue_order(source: str) -> dict[str, tuple[int, int]]:
    """Read the runtime's chapter order, including ordered story conversations.

    Optional scenes can precede later chapters, but do not establish an order
    relative to other scenes in their own chapter.
    """
    sequence = source.split("const CHAPTER_SEQUENCE:", 1)[1].split("const DIALOGUE_REQUIREMENTS:", 1)[0]
    result = {}
    for chapter, body in re.findall(r"\n\t(\d+): \{(.*?)\n\t\},", sequence, re.DOTALL):
        for field in ["story_dialogues", "optional_dialogues"]:
            match = re.search(rf'"{field}": \[(.*?)\]', body, re.DOTALL)
            if match:
                for index, scene in enumerate(re.findall(r'"(act1_[^\"]+)"', match[1])):
                    # Optional scenes share a position: no fabricated ordering.
                    position = index if field == "story_dialogues" else 1000
                    result.setdefault(scene, (int(chapter), position))
    return result


def dialogue_flag_writes(value: object) -> set[str]:
    flags = set()
    if isinstance(value, dict):
        if isinstance(value.get("set_flag"), str) and value.get("flag_value", True):
            flags.add(value["set_flag"])
        for child in value.values():
            if isinstance(child, (dict, list)):
                flags.update(dialogue_flag_writes(child))
    elif isinstance(value, list):
        for child in value:
            flags.update(dialogue_flag_writes(child))
    return flags


def validate_echo_provenance(nodes: dict, prior_scene_flags: set[str] | None = None) -> list[str]:
    """A callback must have a possible route after an actual same-scene write.

    This is structural evidence; native counterfactual tests establish rendering,
    and explicit route tests establish availability of the repaired entrances.
    Earlier chapters and explicitly ordered story scenes may supply a saved
    decision. A node's own effects occur after text resolution and cannot justify
    an echo on that same node.
    """
    writers: dict[str, set[str]] = {}

    def collect(value: object, is_choice: bool = False) -> None:
        if isinstance(value, dict):
            flag = value.get("set_flag")
            if isinstance(flag, str) and value.get("flag_value", True):
                writers.setdefault(flag, set()).update(choice_targets(value) if is_choice else dialogue_targets(value))
            for key, child in value.items():
                if isinstance(child, (dict, list)):
                    collect(child, key == "choices")
        elif isinstance(value, list):
            for child in value:
                collect(child, is_choice)

    collect(nodes)
    errors = []
    for node_id, node in nodes.items():
        if not isinstance(node, dict) or not isinstance(node.get("echoes", []), list):
            continue
        for echo in node.get("echoes", []):
            if not isinstance(echo, dict) or not isinstance(echo.get("flag"), str):
                continue
            pending = list(writers.get(echo["flag"], set()))
            seen = set()
            while pending:
                current = pending.pop()
                if current in seen or current not in nodes:
                    continue
                seen.add(current)
                pending.extend(dialogue_targets(nodes[current]) - seen)
            if node_id not in seen and echo["flag"] not in (prior_scene_flags or set()):
                errors.append(f"{node_id}: echo {echo['flag']!r} has no downstream route from a state write")
    return errors


def validate_echoes(node: dict) -> list[str]:
    """Echoes are executable same-speaker text, not arbitrary reference metadata."""
    if "echoes" not in node:
        return []
    echoes = node["echoes"]
    if not isinstance(echoes, list) or not echoes:
        return ["echoes must be a non-empty array"]
    errors = []
    if not isinstance(node.get("text"), str) or not node.get("speaker"):
        errors.append("echoes require a displayed text node with a speaker")
    if node.get("type") == "skill_check" or "skill_check" in node:
        errors.append("echoes cannot be attached to a non-displayed skill-check node")
    seen = set()
    for echo in echoes:
        if not isinstance(echo, dict) or set(echo) != {"flag", "text"}:
            errors.append("each echo must contain exactly flag and text")
            continue
        flag, text = echo["flag"], echo["text"]
        if not isinstance(flag, str) or not flag.strip() or not isinstance(text, str) or not text.strip():
            errors.append("echo flag and text must be non-empty strings")
            continue
        if flag in seen:
            errors.append(f"duplicate echo flag: {flag}")
        seen.add(flag)
        if text == flag:
            errors.append("echo text must be authored prose, not a flag identifier")
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
