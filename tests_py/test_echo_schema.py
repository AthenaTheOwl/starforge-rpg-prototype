import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from validate_project import (validate_check_text, validate_echoes, validate_echo_provenance, story_dialogue_order, dialogue_targets,
                              echo_variation_errors, story_flag_requirements)


def test_control_graph_matches_inline_and_delegated_check_dispatch():
    assert dialogue_targets({"choices": [{"next": "ghost", "skill_check": {"success": "passed", "failure": "failed"}}]}) == {"passed", "failed"}
    assert dialogue_targets({"choices": [{"next": "staging", "skill_check": {"skill": "empathy", "dc": 10}}]}) == {"staging"}
    assert dialogue_targets({"next": "ghost", "skill_check": {"success": "passed", "failure": "failed"}}) == {"passed", "failed"}


def test_echo_requires_a_real_upstream_write_not_self_reference():
    echo = {"speaker": "Nyx", "text": "base", "echoes": [{"flag": "decision", "text": "A consequence."}], "next": "end"}
    assert validate_echo_provenance({"start": echo})
    assert validate_echo_provenance({"start": {**echo, "set_flag": "decision"}})
    nodes = {"start": {"choices": [{"text": "Choose", "set_flag": "decision", "next": "callback"}]}, "callback": echo}
    assert validate_echo_provenance(nodes) == []
    nodes["start"]["choices"][0]["next"] = "elsewhere"
    assert validate_echo_provenance(nodes)


def test_cross_scene_provenance_uses_actual_chapter_and_story_order():
    order = story_dialogue_order('''const CHAPTER_SEQUENCE: Dictionary = {
\t8: {"story_dialogues": ["act1_decision"], "optional_dialogues": ["act1_optional_a", "act1_optional_b"]
\t},
\t10: {"story_dialogues": ["act1_briefing", "act1_climax"], "optional_dialogues": []
\t},
}
const DIALOGUE_REQUIREMENTS: Dictionary = {}''')
    assert order["act1_decision"] < order["act1_climax"]
    assert order["act1_briefing"] < order["act1_climax"]
    assert order["act1_optional_a"] == order["act1_optional_b"]


def test_echo_schema_accepts_composable_same_speaker_lines():
    assert not validate_echoes({"speaker": "Nyx", "text": "Base.", "echoes": [
        {"flag": "first", "text": "First consequence."}, {"flag": "second", "text": "Second consequence."}]})


def test_echo_schema_rejects_nonrendered_or_metadata_only_entries():
    for payload in [
        {"speaker": "Nyx", "text": "Base.", "echoes": {"first": "Wrong shape"}},
        {"speaker": "Nyx", "text": "Base.", "echoes": [{"flag": "first", "text": ""}]},
        {"speaker": "Nyx", "text": "Base.", "echoes": [{"flag": "first", "text": "first"}]},
        {"text": "Base.", "echoes": [{"flag": "first", "text": "Consequence."}]},
        {"speaker": "Nyx", "text": "Base.", "skill_check": {}, "echoes": [{"flag": "first", "text": "Consequence."}]},
        {"speaker": "Nyx", "text": "Base.", "echoes": [{"flag": "first", "text": "One."}, {"flag": "first", "text": "Duplicate."}]},
    ]:
        assert validate_echoes(payload), payload


def test_check_nodes_cannot_carry_text_the_runtime_never_shows():
    assert validate_check_text({"type": "skill_check", "speaker": "Nyx", "text": "Lost line.", "check": {}})
    assert validate_check_text({"speaker": "Nyx", "text": "Lost line.", "skill_check": {}})
    assert not validate_check_text({"speaker": "SYSTEM", "text": "", "skill_check": {}, "next": "x_success"})
    assert not validate_check_text({"type": "skill_check", "check": {}})
    assert not validate_check_text({"speaker": "Nyx", "text": "Shown.", "next": "x_resolve"})


def story_source(chapters, requirements=None):
    body = "".join(f'\n\t{index}: {{"story_dialogues": {json.dumps(story)}, "optional_dialogues": {json.dumps(optional)}\n\t}},'
                   for index, (story, optional) in enumerate(chapters))
    gates = "".join(f'\n\t"{scene}": {json.dumps(flags)},' for scene, flags in (requirements or {}).items())
    return f"const CHAPTER_SEQUENCE: Dictionary = {{{body}\n}}\nconst DIALOGUE_REQUIREMENTS: Dictionary = {{{gates}\n}}\n"


def scene(nodes):
    return {"start_node": "start", "nodes": nodes}


def callback(flag, next_node="end"):
    return {"speaker": "Elia", "text": "Base.", "echoes": [{"flag": flag, "text": "A consequence."}], "next": next_node}


def test_echo_set_on_every_path_to_its_node_is_rejected():
    choose = {"choices": [{"text": "A", "set_flag": "chosen", "next": "after"}, {"text": "B", "set_flag": "chosen", "next": "after"}]}
    errors = echo_variation_errors({"act1_a": scene({"start": choose, "after": callback("chosen")})}, story_source([(["act1_a"], [])]))
    assert errors == ["act1_a.json:after: echo 'chosen' always renders: every path to this node sets it"]
    choose["choices"][1].pop("set_flag")
    assert echo_variation_errors({"act1_a": scene({"start": choose, "after": callback("chosen")})}, story_source([(["act1_a"], [])])) == []


def test_echo_whose_flag_is_only_set_afterwards_is_rejected():
    nodes = {"start": callback("later", "choose"), "choose": {"choices": [{"text": "A", "set_flag": "later", "next": "end"}, {"text": "B", "next": "end"}]}}
    assert echo_variation_errors({"act1_a": scene(nodes)}, story_source([(["act1_a"], [])])) == [
        "act1_a.json:start: echo 'later' never renders: no path sets it before this node"]


def test_echo_constancy_follows_story_order_and_gates_across_scenes():
    always = scene({"start": {"speaker": "Elia", "text": "Done.", "set_flag": "briefed", "next": "end"}})
    later = scene({"start": callback("briefed")})
    # A mandatory earlier story scene that always sets the flag makes it constant.
    assert echo_variation_errors({"act1_brief": always, "act1_climax": later},
                                 story_source([(["act1_brief", "act1_climax"], [])])) == [
        "act1_climax.json:start: echo 'briefed' always renders: every path to this node sets it"]
    # An optional earlier scene can be skipped, so the callback varies.
    assert echo_variation_errors({"act1_brief": always, "act1_climax": later},
                                 story_source([([], ["act1_brief"]), (["act1_climax"], [])])) == []
    # ...unless a story gate means the later scene only plays after it.
    assert echo_variation_errors({"act1_brief": always, "act1_climax": later},
                                 story_source([([], ["act1_brief"]), (["act1_climax"], [])], {"act1_climax": ["briefed"]})) == [
        "act1_climax.json:start: echo 'briefed' always renders: every path to this node sets it"]


def test_echo_constancy_follows_variant_routing_and_skill_check_outcomes():
    nodes = {
        "start": {"choices": [{"text": "Close", "set_flag": "close", "next": "route"}, {"text": "Far", "next": "route"}]},
        "route": {"speaker": "Elia", "text": "Go.", "next": "plain", "variants": [{"conditions": {"flag": "close"}, "next": "close_end"}]},
        "close_end": callback("close"),
        "plain": {"type": "skill_check", "check": {"skill": "tactics", "dc": 10, "success": "won", "failure": "lost"}},
        "won": {"speaker": "SYSTEM", "text": "Won.", "set_flag": "won", "next": "lost"},
        "lost": callback("won"),
    }
    assert echo_variation_errors({"act1_a": scene(nodes)}, story_source([(["act1_a"], [])])) == [
        "act1_a.json:close_end: echo 'close' always renders: every path to this node sets it"]


def test_story_requirement_parser_reads_flag_gates_only():
    source = story_source([(["act1_a"], [])]).replace("const DIALOGUE_REQUIREMENTS: Dictionary = {\n}", (
        'const DIALOGUE_REQUIREMENTS: Dictionary = {\n\t# comment\n\t"act1_a": ["named"],'
        '\n\t"act1_b": {"flags": ["revealed"]},\n\t"act1_c": {"relationship": {"nyx": "trusted"}},\n}'))
    assert story_flag_requirements(source) == {"act1_a": ["named"], "act1_b": ["revealed"], "act1_c": []}
