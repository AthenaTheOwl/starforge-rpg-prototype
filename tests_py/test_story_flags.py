import json
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[1]
DIALOGUE = ROOT / "data" / "dialogue"
sys.path.insert(0, str(ROOT / "tools"))
from validate_project import dialogue_flag_reads, unwritten_flag_reads  # noqa: E402


def nodes(scene: str) -> dict:
    return json.loads((DIALOGUE / f"{scene}.json").read_text(encoding="utf-8"))["nodes"]


def written(scene_nodes: dict) -> set[str]:
    return {holder["set_flag"] for node in scene_nodes.values() for holder in [node, *node.get("choices", [])] if "set_flag" in holder}


def test_bond_flags_use_the_name_the_climax_reads() -> None:
    climax_reads = {flag for node in nodes("act1_climax_setup").values()
                    for flag in (node.get("text_variants") if isinstance(node.get("text_variants"), dict) else {})
                    if flag.endswith("_bonded")}
    for name in ["elisira", "jalen", "nyx", "rho", "vesper"]:
        assert f"{name}_bonded" in climax_reads
        assert f"{name}_bonded" in written(nodes(f"act1_bonding_{name}"))
    assert not [flag for path in DIALOGUE.glob("*.json") for flag in written(nodes(path.stem)) if flag.startswith("bonded_with_")]
    # Neither this port nor the Ren'Py port has an Elia bonding scene to set it.
    assert "elia_bonded" in climax_reads


def test_rho_militia_story_records_that_he_mentioned_his_past() -> None:
    [loyalty] = [choice for choice in nodes("act1_bonding_rho")["rho_continues"]["choices"] if choice["next"] == "ask_loyalty"]
    assert loyalty.get("set_flag") == "rho_mentioned_past"
    assert nodes("act1_deep_rho")["militia_squad_4"]["text_variants"][0]["conditions"]["flags"] == ["rho_mentioned_past"]


def test_dialogue_flag_reads_cover_every_runtime_test() -> None:
    node = {
        "text_variants": {"default": "x", "dict_gate": "y"},
        "variants": [{"conditions": {"flags": ["all_of"], "flag": "one", "not_flag": "none_of"}, "next": "a"}],
        "choices": [{"text": "Go", "requires_flag": "choice_gate", "next": "a"}],
        "echoes": [{"flag": "callback", "text": "Line."}],
    }
    assert dialogue_flag_reads(node) == {"dict_gate", "all_of", "one", "none_of", "choice_gate", "callback"}
    assert dialogue_flag_reads({"text_variants": [{"conditions": {"flags": ["listed"]}, "text": "z"}]}) == {"listed"}


def test_unwritten_reads_fail_unless_listed_and_the_list_cannot_go_stale() -> None:
    reads = {"ghost": {"b.json:n2", "a.json:n1"}, "real": {"a.json:n3"}, "known": {"c.json:n4"}}
    assert unwritten_flag_reads(reads, {"real"}, {"known"}) == [
        "a.json:n1: reads flag 'ghost', which nothing writes (and 1 more)"]
    assert unwritten_flag_reads(reads, {"real", "ghost", "known"}, {"known"}) == [
        "known-unset flag 'known' is now written or no longer read; drop it from the list"]
    assert unwritten_flag_reads({"real": {"a.json:n3"}}, {"real"}, {"known"}) == [
        "known-unset flag 'known' is now written or no longer read; drop it from the list"]
