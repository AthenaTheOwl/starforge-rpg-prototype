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
            errors.extend(f"{rel(path)}:{node_id}: {error}" for error in validate_check_text(node))
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


def validate_check_text(node: dict) -> list[str]:
    """Standalone checks roll before any text is shown, so authored text there is lost."""
    if (node.get("type") == "skill_check" or "skill_check" in node) and node.get("text"):
        return ["skill-check node text is never displayed; stage it on a preceding text node"]
    return []


def validate_echo_variation() -> list[str]:
    dialogue_root = ROOT / "data" / "dialogue"
    dialogues = {path.stem: json.loads(path.read_text(encoding="utf-8")) for path in sorted(dialogue_root.glob("*.json"))}
    source = (ROOT / "autoload/story_manager.gd").read_text(encoding="utf-8")
    return [f"data/dialogue/{error}" for error in echo_variation_errors(dialogues, source)]


def chapter_sequence(source: str) -> list[tuple[list[str], list[str]]]:
    """Story and optional dialogues of each chapter, in chapter order."""
    sequence = source.split("const CHAPTER_SEQUENCE:", 1)[1].split("const DIALOGUE_REQUIREMENTS:", 1)[0]
    chapters = []
    for _, body in sorted(re.findall(r"\n\t(\d+): \{(.*?)\n\t\},", sequence, re.DOTALL), key=lambda item: int(item[0])):
        lists = []
        for field in ["story_dialogues", "optional_dialogues"]:
            match = re.search(rf'"{field}": \[(.*?)\]', body, re.DOTALL)
            lists.append(re.findall(r'"(act1_[^\"]+)"', match[1]) if match else [])
        chapters.append((lists[0], lists[1]))
    return chapters


def story_flag_requirements(source: str) -> dict[str, list[str]]:
    """Flags StoryManager requires before it offers a dialogue (relationship gates aside)."""
    body = source.split("const DIALOGUE_REQUIREMENTS:", 1)[1].split("\n}\n", 1)[0]
    requirements = {}
    for scene, value in re.findall(r'\n\t"(act1_[^"]+)": (.*)', body):
        flags = re.search(r'"flags": \[(.*?)\]', value)
        requirements[scene] = re.findall(r'"([^"]+)"', value if value.startswith("[") else flags[1] if flags else "")
    return requirements


def condition_flags(variant: dict) -> set[str]:
    conditions = variant.get("conditions", variant.get("condition", {}))
    return set(conditions.get("flags", [])) | {conditions[key] for key in ["flag", "not_flag"] if key in conditions}


def variant_holds(variant: dict, flags: frozenset) -> bool | None:
    """DialogueManager._check_variant_conditions; None when reputation decides."""
    conditions = variant.get("conditions", variant.get("condition", {}))
    required = list(conditions.get("flags", [])) + ([conditions["flag"]] if "flag" in conditions else [])
    if any(flag not in flags for flag in required):
        return False
    if "flag_value" in conditions and (True if conditions.get("flag", "") in flags else None) != conditions["flag_value"]:
        return False
    if "not_flag" in conditions and conditions["not_flag"] in flags:
        return False
    return None if "reputation" in conditions else True


def node_resolutions(node: dict, flags: frozenset):
    """The resolved nodes play can display: the first matching variant, else the base."""
    for variant in node.get("variants", []):
        holds = variant_holds(variant, flags)
        if holds is not False:
            yield {**node, **{key: value for key, value in variant.items() if key != "conditions"}}
        if holds:
            return
    yield node


def with_write(flags: frozenset, holder: dict, tracked: frozenset) -> frozenset:
    flag = holder.get("set_flag")
    return flags | {flag} if isinstance(flag, str) and flag in tracked and holder.get("flag_value", True) else flags


def scene_steps(node: dict, flags: frozenset, tracked: frozenset) -> list[tuple[frozenset | None, str, frozenset]]:
    """Executed transitions as (flags when its text resolves, successor, flags after).

    Mirrors DialogueManager: a check rolls either outcome with no display or
    effects; a displayed node resolves text before its own effects, then offers
    its available choices or follows next.
    """
    if node.get("type") == "skill_check" or "skill_check" in node:
        return [(None, target, flags) for target in dialogue_targets(node)]
    steps = []
    for resolved in node_resolutions(node, flags):
        after = with_write(flags, resolved, tracked)
        available = [choice for choice in resolved.get("choices", []) if "requires_flag" not in choice or choice["requires_flag"] in after]
        if all("requires_reputation" in choice for choice in available):
            steps.append((flags, resolved.get("next") or "end", after))
        for choice in available:
            steps.extend((flags, target, with_write(after, choice, tracked)) for target in choice_targets(choice))
    return steps


def explore_scene(nodes: dict, start: str, entry: frozenset, tracked: frozenset) -> tuple[set[frozenset], dict[str, set[frozenset]]]:
    """Exit flag states of one playthrough, and the states each node displays in."""
    exits, shown, seen = set(), {}, set()
    pending = [(start, entry)]
    while pending:
        node_id, flags = pending.pop()
        if (node_id, flags) in seen:
            continue
        seen.add((node_id, flags))
        node = nodes.get(node_id) if node_id != "end" else None
        if not isinstance(node, dict):
            exits.add(flags)
            continue
        for displayed, target, after in scene_steps(node, flags, tracked):
            if displayed is not None:
                shown.setdefault(node_id, set()).add(displayed)
            pending.append((target, after))
    return exits, shown


def echo_variation_errors(dialogues: dict, story_source: str) -> list[str]:
    """An echo must render on some route to its node and stay silent on another.

    Plays the whole act as ChapterFlow and StoryManager run it: story dialogues
    auto-play in order while their flag gates hold, optional ones may be played
    or skipped, and a chapter advances only after its story dialogues. Only flags
    that steer play (story gates, variant conditions, choice requirements) and
    the echo's own flag are tracked. A flag set on every path to the node makes
    the echo constant, as does a flag no path sets before it.
    """
    chapters = chapter_sequence(story_source)
    requirements = story_flag_requirements(story_source)
    guards = {flag for flags in requirements.values() for flag in flags}
    sites: dict[str, list[tuple[str, str]]] = {}
    for scene, payload in dialogues.items():
        for node_id, node in payload.get("nodes", {}).items():
            for variant in node.get("variants", []):
                guards |= condition_flags(variant)
            guards |= {choice["requires_flag"] for choice in node.get("choices", []) if "requires_flag" in choice}
            for echo in node.get("echoes", []) if isinstance(node.get("echoes"), list) else []:
                if isinstance(echo, dict) and isinstance(echo.get("flag"), str):
                    sites.setdefault(echo["flag"], []).append((scene, node_id))
    writes = {scene: dialogue_flag_writes(payload.get("nodes", {})) for scene, payload in dialogues.items()}
    cache: dict[tuple, tuple[set[frozenset], dict[str, set[frozenset]]]] = {}
    errors = []
    for flag, flag_sites in sorted(sites.items()):
        tracked_here = frozenset(guards | {flag})
        values: dict[tuple[str, str], set[bool]] = {site: set() for site in flag_sites}

        def play(scene: str, flags: frozenset) -> set[frozenset]:
            tracked = tracked_here if flag in writes[scene] else frozenset(guards)
            key = (scene, flags & tracked, tracked)
            if key not in cache:
                payload = dialogues[scene]
                cache[key] = explore_scene(payload.get("nodes", {}), payload.get("start_node", "start"), flags & tracked, tracked)
            exits, shown = cache[key]
            carried = flags - tracked
            for site_scene, node_id in flag_sites:
                if site_scene == scene:
                    values[(site_scene, node_id)].update(flag in state or flag in carried for state in shown.get(node_id, ()))
            return {state | carried for state in exits}

        later = [{scene for part in chapter for scene in part} for chapter in chapters]
        seen: set[tuple[int, frozenset, frozenset]] = set()
        pending = [(0, frozenset(), frozenset())]
        while pending:
            state = pending.pop()
            if state in seen or state[0] >= len(chapters):
                continue
            seen.add(state)
            index, played, flags = state
            story, optional = chapters[index]
            offered = [scene for scene in story + optional if scene in dialogues and scene not in played
                       and all(gate in flags for gate in requirements.get(scene, []))]
            ready = [scene for scene in offered if scene in story]
            for scene in ready[:1] or offered:
                pending.extend((index, played | {scene}, exit_flags) for exit_flags in play(scene, flags))
            if not ready and all(scene in played or scene not in dialogues for scene in story):
                keep = set().union(*later[index + 1:]) if index + 1 < len(later) else set()
                pending.append((index + 1, frozenset(played & keep), flags))
        for (scene, node_id), seen_values in values.items():
            if not seen_values:
                errors.append(f"{scene}.json:{node_id}: echo {flag!r} sits on a node play never displays")
            elif seen_values == {True}:
                errors.append(f"{scene}.json:{node_id}: echo {flag!r} always renders: every path to this node sets it")
            elif seen_values == {False}:
                errors.append(f"{scene}.json:{node_id}: echo {flag!r} never renders: no path sets it before this node")
    return errors


def validate_story_progression() -> list[str]:
    dialogue_root = ROOT / "data" / "dialogue"
    dialogues = {path.stem: json.loads(path.read_text(encoding="utf-8")) for path in sorted(dialogue_root.glob("*.json"))}
    source = (ROOT / "autoload/story_manager.gd").read_text(encoding="utf-8")
    return [f"autoload/story_manager.gd: {error}" for error in story_softlocks(dialogues, source)]


def story_softlocks(dialogues: dict, story_source: str) -> list[str]:
    """The act must be finishable on every route while every optional dialogue is skipped.

    Plays only the story dialogues, as ChapterFlow auto-plays them: the first
    unplayed one whose StoryManager flag gates hold, in chapter order, with
    each chapter's chapter_N_complete flag set on advancing. Every branch of
    each scene is followed. A chapter whose remaining story dialogues are all
    gated shows a hub with a disabled Continue button and nothing to play: a
    softlock. A gate flag written only by optional content is exactly this bug.
    """
    chapters = chapter_sequence(story_source)
    requirements = story_flag_requirements(story_source)
    optional_scenes = {scene for _, optional in chapters for scene in optional}
    tracked = {flag for flags in requirements.values() for flag in flags}
    for payload in dialogues.values():
        for node in payload.get("nodes", {}).values():
            if not isinstance(node, dict):
                continue
            for variant in node.get("variants", []):
                tracked |= condition_flags(variant)
            tracked |= {choice["requires_flag"] for choice in node.get("choices", []) if "requires_flag" in choice}
    tracked_flags = frozenset(tracked)
    writers: dict[str, set[str]] = {}
    for scene, payload in dialogues.items():
        for flag in dialogue_flag_writes(payload.get("nodes", {})):
            writers.setdefault(flag, set()).add(scene)
    cache: dict[tuple[str, frozenset], set[frozenset]] = {}
    errors: list[str] = []
    seen: set[tuple[int, frozenset, frozenset]] = set()
    pending = [(0, frozenset(), frozenset())]
    while pending:
        state = pending.pop()
        if state in seen or state[0] >= len(chapters):
            continue
        seen.add(state)
        index, played, flags = state
        remaining = [scene for scene in chapters[index][0] if scene in dialogues and scene not in played]
        if not remaining:
            pending.append((index + 1, frozenset(), flags | {f"chapter_{index}_complete"}))
            continue
        ready = [scene for scene in remaining if all(gate in flags for gate in requirements.get(scene, []))]
        if ready:
            scene = ready[0]
            payload = dialogues[scene]
            key = (scene, flags & tracked_flags)
            if key not in cache:
                cache[key] = explore_scene(payload.get("nodes", {}), payload.get("start_node", "start"), key[1], tracked_flags)[0]
            carried = flags - tracked_flags
            pending.extend((index, played | {scene}, exit_flags | carried) for exit_flags in cache[key])
            continue
        for scene in remaining:
            for gate in requirements.get(scene, []):
                if gate in flags:
                    continue
                sources = sorted(writers.get(gate, set()))
                optional_only = sources and all(source in optional_scenes for source in sources)
                detail = (f"written only by optional {', '.join(sources)}" if optional_only
                          else f"written by {', '.join(sources)}, but not on this route" if sources
                          else "written by no dialogue")
                message = (f"chapter {index}: story dialogue {scene} waits on flag {gate!r} ({detail}); "
                           "with optional content skipped the chapter cannot be completed")
                if message not in errors:
                    errors.append(message)
    return errors


# Read by authored dialogue but set nowhere in this port or the Ren'Py port, and
# no earlier choice clearly earns them, so their lines wait until the author
# decides where each is set. shard_whispers_heard is read at the start of
# act1_bee_manifestation, which always plays before the optional
# act1_shard_whispers, so no setter there could show its line.
UNSET_DIALOGUE_FLAGS = {
    "ai_citizens_discovered", "elia_bonded", "elia_trust_high", "elia_trust_low",
    "elisira_conflict_resolved", "first_watch_ai_citizens", "first_watch_bubbles",
    "first_watch_cinnamon", "first_watch_waffle", "nyx_trust_high", "nyx_trust_low",
    "rho_trust_high", "rho_trust_low", "shard_whispers_heard", "vesper_trust_high",
    "vesper_trust_low",
}
# Exploration location gates. ExplorationController ignores an examine action's
# flag, no location has a recruit action, and the exploration screen opens only
# from the party screen, which nothing routes to. They wait with the queued
# location routes.
UNSET_LOCATION_FLAGS = {
    "examined_equipment", "examined_shrine", "found_safehouse_evidence", "jalen_recruited",
    "naming_scene_available", "nyx_noticed", "nyx_recruited", "rho_recruited",
    "sensed_lattice", "vesper_noticed", "vesper_recruited",
}


def validate_flag_writers() -> list[str]:
    """Every flag the game reads must have a writer the game can run."""
    story_source = (ROOT / "autoload/story_manager.gd").read_text(encoding="utf-8")
    code = {rel(path): path.read_text(encoding="utf-8")
            for path in [*sorted((ROOT / "autoload").glob("*.gd")), *sorted((ROOT / "scripts").rglob("*.gd"))]}
    reads: dict[str, set[str]] = {}
    writes: set[str] = set()
    for path in sorted((ROOT / "data" / "dialogue").glob("*.json")):
        nodes = json.loads(path.read_text(encoding="utf-8")).get("nodes", {})
        writes |= dialogue_flag_writes(nodes)
        for node_id, node in nodes.items():
            for flag in dialogue_flag_reads(node):
                reads.setdefault(flag, set()).add(f"{rel(path)}:{node_id}")
    for scene, flags in story_flag_requirements(story_source).items():
        for flag in flags:
            reads.setdefault(flag, set()).add(f"autoload/story_manager.gd:{scene}")
    for path in sorted((ROOT / "data" / "quests").glob("*.json")):
        for action in json.loads(path.read_text(encoding="utf-8")).get("actions", []):
            for key in ["requires_flag", "excludes_flag"]:
                if key in action:
                    reads.setdefault(action[key], set()).add(rel(path))
            # ExplorationController._execute_action writes only these two kinds.
            if action.get("type") == "flag" and action.get("flag"):
                writes.add(action["flag"])
            elif action.get("type") == "recruit":
                writes.add(action.get("flag", "recruited_" + action.get("character_id", "")))
    for path, text in code.items():
        writes |= set(re.findall(r'set_flag\("([^"]+)"', text))
        for flag in re.findall(r'(?:has_flag|get_flag)\("([^"]+)"', text):
            reads.setdefault(flag, set()).add(path)
    # StoryManager.complete_chapter and RelationshipManager._on_tier_change.
    writes |= {f"chapter_{index}_complete" for index in range(len(chapter_sequence(story_source)))}
    relationships = code["autoload/relationship_manager.gd"]
    tiers = [tier.lower() for tier in re.findall(r'Tier\.\w+: return "(\w+)"', relationships)]
    writes |= {f"{character}_tier_{tier}" for character in re.findall(r'\n\t"(\w+)": \{"name"', relationships) for tier in tiers}
    return unwritten_flag_reads(reads, writes, UNSET_DIALOGUE_FLAGS | UNSET_LOCATION_FLAGS)


def dialogue_flag_reads(node: dict) -> set[str]:
    """Flags DialogueManager tests for a node: text, variants, choices and echoes."""
    flags = set()
    text_variants = node.get("text_variants", {})
    if isinstance(text_variants, dict):
        flags |= {flag for flag in text_variants if flag != "default"}
    else:
        for variant in text_variants:
            flags |= condition_flags(variant)
    for variant in node.get("variants", []):
        flags |= condition_flags(variant)
    flags |= {choice["requires_flag"] for choice in node.get("choices", []) if "requires_flag" in choice}
    flags |= {echo["flag"] for echo in node.get("echoes", []) if isinstance(echo, dict) and isinstance(echo.get("flag"), str)}
    return flags


def unwritten_flag_reads(reads: dict[str, set[str]], writes: set[str], known_unset: set[str]) -> list[str]:
    errors = [f"{min(sites)}: reads flag {flag!r}, which nothing writes"
              + (f" (and {len(sites) - 1} more)" if len(sites) > 1 else "")
              for flag, sites in sorted(reads.items()) if flag not in writes and flag not in known_unset]
    errors += [f"known-unset flag {flag!r} is now written or no longer read; drop it from the list"
               for flag in sorted(known_unset) if flag in writes or flag not in reads]
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
        validate_echo_variation,
        validate_story_progression,
        validate_flag_writers,
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
