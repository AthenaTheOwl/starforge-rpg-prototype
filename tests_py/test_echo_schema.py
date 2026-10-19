from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from validate_project import validate_check_text, validate_echoes, validate_echo_provenance, story_dialogue_order, dialogue_targets


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
