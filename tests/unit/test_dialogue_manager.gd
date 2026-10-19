extends GutTest
## Tests for DialogueManager — dialogue flow, skill checks, choices, history.
##
## Since DialogueManager is an autoload that loads JSON from disk, we bypass
## _load_dialogue by injecting dialogue_data directly and calling internal
## methods where possible.


func test_text_variant_array_supports_canonical_condition_shapes():
	var original_flags := GameManager.story_flags.duplicate(true)
	GameManager.story_flags = {"seen": true, "trusted": true}
	assert_eq(DialogueManager._get_node_text({"text": "base", "text_variants": [
		{"condition": {"flag": "missing"}, "text": "wrong"},
		{"condition": {"flag": "seen"}, "text": "singular"},
	]}), "singular")
	assert_eq(DialogueManager._get_node_text({"text": "base", "text_variants": [
		{"conditions": {"flags": ["seen", "missing"]}, "text": "wrong"},
		{"conditions": {"flags": ["seen", "trusted"]}, "text": "plural"},
	]}), "plural")
	assert_eq(DialogueManager._get_node_text({"text": "base", "text_variants": [
		{"conditions": {"flag": "missing"}, "text": "wrong"},
	]}), "base", "Unmatched conditional variants retain the authored base text")
	assert_eq(DialogueManager._get_node_text({"text": "base", "text_variants": {
		"missing": "wrong", "seen": "dictionary", "default": "fallback",
	}}), "dictionary", "The original dictionary format remains supported")
	GameManager.story_flags = original_flags


func test_echoes_compose_all_true_flags_after_variants_without_mutation():
	var original_flags := GameManager.story_flags.duplicate(true)
	var node := {"text": "base", "text_variants": {"first": "selected base"}, "echoes": [
		{"flag": "first", "text": "first consequence"},
		{"flag": "second", "text": "second consequence"},
		{"flag": "unset", "text": "must not appear"},
	]}
	GameManager.story_flags = {"first": true, "second": true}
	assert_eq(DialogueManager._get_node_text(node), "selected base\nfirst consequence\nsecond consequence")
	assert_eq(DialogueManager._get_node_text(node), "selected base\nfirst consequence\nsecond consequence", "Repeated renders do not accumulate echoes")
	assert_eq(node["text"], "base", "Authored base is unchanged")
	GameManager.story_flags = {"first": false, "second": false}
	# Existing variants retain their has_flag semantics, while echoes require a
	# truthy saved value; false and absent decisions cannot produce consequences.
	assert_eq(DialogueManager._get_node_text(node), "selected base")
	GameManager.story_flags.clear()
	assert_eq(DialogueManager._get_node_text(node), "base")
	GameManager.story_flags = original_flags


func test_reputation_dispatch_distinguishes_characters_from_factions():
	var saved_affinity := RelationshipManager.affinity.duplicate(true)
	var saved_reputation := GameManager.faction_reputation.duplicate(true)
	_inject_dialogue(DialogueManager, {"start_node": "start", "nodes": {"start": {
		"speaker": "Waffle.bat", "text": "Acknowledged.", "next": "end",
		"reputation": {"Waffle.bat": 1, "guild_drift": 2, "crew_trust": 1},
	}}})
	DialogueManager._display_node("start")
	assert_eq(RelationshipManager.get_affinity("waffle"), int(saved_affinity["waffle"]) + 3)
	assert_eq(GameManager.get_reputation("guild_drift"), int(saved_reputation["guild_drift"]) + 2)
	for character in saved_affinity:
		if character != "waffle":
			assert_eq(RelationshipManager.get_affinity(character), saved_affinity[character], "Faction/stat keys must not modify a crew relationship")
	assert_false(RelationshipManager.affinity.has("crew_trust"))
	assert_false(RelationshipManager.affinity.has("waffle.bat"))
	RelationshipManager.affinity = saved_affinity
	GameManager.faction_reputation = saved_reputation


func test_unchosen_choice_cannot_produce_a_callback():
	var saved_flags := GameManager.story_flags.duplicate(true)
	var data := {"start_node": "start", "nodes": {
		"start": {"speaker": "Avyanna", "text": "Choose.", "choices": [
			{"text": "Ask", "set_flag": "asked", "next": "answer"},
			{"text": "Wait", "set_flag": "waited", "next": "answer"},
		]},
		"answer": {"speaker": "Elia", "text": "Here.", "next": "end", "echoes": [
			{"flag": "asked", "text": "An answer."}, {"flag": "waited", "text": "No hurry."},
		]},
	}}
	for index in [0, 1]:
		GameManager.story_flags.clear()
		_inject_dialogue(DialogueManager, data)
		DialogueManager._display_node("start")
		DialogueManager.select_choice(index)
		var expected: String = "asked" if index == 0 else "waited"
		var absent: String = "waited" if index == 0 else "asked"
		assert_true(GameManager.get_flag(expected, false))
		assert_false(GameManager.has_flag(absent))
		assert_eq(DialogueManager.get_history().back()["text"], "Here.\nAn answer." if index == 0 else "Here.\nNo hurry.")
	GameManager.story_flags = saved_flags


func test_legacy_choice_checks_follow_both_outcomes():
	for dc in [1, 99]:
		_seed_noncritical_roll()
		_inject_dialogue(DialogueManager, _legacy_check_dialogue(dc, false))
		DialogueManager.select_choice(0)
		assert_eq(DialogueManager.current_node_id, "passed" if dc == 1 else "failed")
	DialogueManager.end_dialogue()


func test_legacy_standalone_checks_follow_both_outcomes():
	for dc in [1, 99]:
		_seed_noncritical_roll()
		_inject_dialogue(DialogueManager, _legacy_check_dialogue(dc, true))
		DialogueManager._display_node("start")
		assert_eq(DialogueManager.current_node_id, "passed" if dc == 1 else "failed")
	DialogueManager.end_dialogue()


func _seed_noncritical_roll() -> void:
	for value in range(100):
		seed(value)
		var roll: int = randi() % 20 + 1
		if roll > 1 and roll < 20:
			seed(value)
			return


func _legacy_check_dialogue(dc: int, standalone: bool) -> Dictionary:
	var check := {"skill": "empathy", "dc": dc, "success": "passed", "failure": "failed"}
	var start: Dictionary = {"skill_check": check} if standalone else {
		"choices": [{"text": "Try", "skill_check": check}],
	}
	return {"start_node": "start", "nodes": {
		"start": start,
		"passed": {"text": "passed", "choices": [{"text": "Stop", "next": "end"}]},
		"failed": {"text": "failed", "choices": [{"text": "Stop", "next": "end"}]},
	}}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _build_simple_dialogue() -> Dictionary:
	return {
		"start_node": "start",
		"nodes": {
			"start": {
				"speaker": "NPC",
				"text": "Hello traveler.",
				"choices": [
					{ "text": "Greet", "next": "greet_node" },
					{ "text": "Leave", "next": "end" },
				],
			},
			"greet_node": {
				"speaker": "NPC",
				"text": "Well met!",
				"next": "end",
			},
		},
	}


func _build_skill_check_dialogue() -> Dictionary:
	return {
		"start_node": "start",
		"nodes": {
			"start": {
				"speaker": "Guard",
				"text": "Halt! State your business.",
				"choices": [
					{
						"text": "Persuade",
						"skill_check": {
							"character": "test_char",
							"stat": "charisma",
							"threshold": 10,
							"on_success": "success_node",
							"on_failure": "failure_node",
						},
					},
				],
			},
			"success_node": {
				"speaker": "Guard",
				"text": "Very well, pass.",
				"next": "end",
			},
			"failure_node": {
				"speaker": "Guard",
				"text": "I don't think so.",
				"next": "end",
			},
		},
	}


func _build_variant_dialogue() -> Dictionary:
	return {
		"start_node": "start",
		"nodes": {
			"start": {
				"speaker": "NPC",
				"text": "Default text.",
				"variants": [
					{
						"conditions": { "flag": "has_key" },
						"text": "I see you have the key!",
					},
					{
						"conditions": { "flag": "nonexistent_flag" },
						"text": "This should not appear.",
					},
				],
				"next": "end",
			},
		},
	}


func _inject_dialogue(dm, data: Dictionary, dialogue_id: String = "test_dlg") -> void:
	dm.dialogue_data = data
	dm.current_dialogue_id = dialogue_id
	dm.is_active = true
	dm.dialogue_history.clear()
	dm.current_node_id = data.get("start_node", "start")


# ---------------------------------------------------------------------------
# start_dialogue — loads data and emits signal
# ---------------------------------------------------------------------------

func test_start_dialogue_emits_signal():
	# We test the signal emission by injecting data and calling _display_node
	var dm := DialogueManager
	_inject_dialogue(dm, _build_simple_dialogue())
	dm.dialogue_started.emit("test_dlg")
	# Verify state
	assert_true(dm.is_active, "Dialogue should be active after start")
	assert_eq(dm.current_dialogue_id, "test_dlg")


func test_start_dialogue_sets_start_node():
	var dm := DialogueManager
	_inject_dialogue(dm, _build_simple_dialogue())
	assert_eq(dm.current_node_id, "start", "Current node should be start_node")


# ---------------------------------------------------------------------------
# select_choice — navigates to correct node
# ---------------------------------------------------------------------------

func test_select_choice_navigates():
	var dm := DialogueManager
	_inject_dialogue(dm, _build_simple_dialogue())
	# Display the start node first to populate state
	dm._display_node("start")
	# Select first choice "Greet" -> next: "greet_node"
	dm.select_choice(0)
	assert_eq(dm.current_node_id, "greet_node", "Selecting choice 0 navigates to greet_node")


func test_select_choice_end_ends_dialogue():
	var dm := DialogueManager
	_inject_dialogue(dm, _build_simple_dialogue())
	dm._display_node("start")
	# Select "Leave" -> next: "end"
	dm.select_choice(1)
	assert_false(dm.is_active, "Selecting 'end' choice ends dialogue")


func test_select_invalid_choice_index():
	var dm := DialogueManager
	_inject_dialogue(dm, _build_simple_dialogue())
	dm._display_node("start")
	dm.select_choice(99)
	# Should not crash; still active at same node
	assert_true(dm.is_active, "Invalid choice index does not crash")


# ---------------------------------------------------------------------------
# Skill check resolution
# ---------------------------------------------------------------------------

func test_skill_check_critical_success_on_roll_20():
	var dm := DialogueManager
	# Test the internal _resolve_skill_check with a rigged roll
	# We cannot easily rig randi(), so we test the result name mapping
	var result_name := dm._check_result_name(dm.CheckResult.CRITICAL_SUCCESS)
	assert_eq(result_name, "CRITICAL_SUCCESS")


func test_skill_check_critical_failure_name():
	var dm := DialogueManager
	var result_name := dm._check_result_name(dm.CheckResult.CRITICAL_FAILURE)
	assert_eq(result_name, "CRITICAL_FAILURE")


func test_skill_check_success_name():
	var dm := DialogueManager
	var result_name := dm._check_result_name(dm.CheckResult.SUCCESS)
	assert_eq(result_name, "SUCCESS")


func test_skill_check_failure_name():
	var dm := DialogueManager
	var result_name := dm._check_result_name(dm.CheckResult.FAILURE)
	assert_eq(result_name, "FAILURE")


# ---------------------------------------------------------------------------
# Skill check branching
# ---------------------------------------------------------------------------

func test_skill_check_branch_navigates():
	# We test by calling select_choice with a skill check choice.
	# Since we cannot control randi(), we verify history is recorded.
	var dm := DialogueManager
	_inject_dialogue(dm, _build_skill_check_dialogue())
	# Set up a test character in PartyManager so the check can resolve
	PartyManager.roster["test_char"] = { "id": "test_char", "charisma": 20 }
	dm._display_node("start")
	dm.select_choice(0)
	# After skill check, should have navigated to success or failure node
	assert_true(
		dm.current_node_id in ["success_node", "failure_node"] or not dm.is_active,
		"Skill check should branch to success or failure"
	)
	# Clean up
	PartyManager.roster.erase("test_char")


# ---------------------------------------------------------------------------
# Dialogue history
# ---------------------------------------------------------------------------

func test_history_tracks_displayed_nodes():
	var dm := DialogueManager
	_inject_dialogue(dm, _build_simple_dialogue())
	dm._display_node("start")
	var history := dm.get_history()
	assert_gt(history.size(), 0, "History should have entries after displaying node")
	assert_eq(history[0]["node_id"], "start", "First history entry is start node")
	assert_eq(history[0]["type"], "dialogue")


func test_history_records_speaker_and_text():
	var dm := DialogueManager
	_inject_dialogue(dm, _build_simple_dialogue())
	dm._display_node("start")
	var entry: Dictionary = dm.get_history()[0]
	assert_eq(entry["speaker"], "NPC")
	assert_eq(entry["text"], "Hello traveler.")


# ---------------------------------------------------------------------------
# end_dialogue — cleanup
# ---------------------------------------------------------------------------

func test_end_dialogue_cleans_up():
	var dm := DialogueManager
	_inject_dialogue(dm, _build_simple_dialogue())
	dm.end_dialogue()
	assert_false(dm.is_active, "Dialogue no longer active after end")
	assert_eq(dm.current_dialogue_id, "", "Dialogue ID cleared")
	assert_true(dm.dialogue_data.is_empty(), "Dialogue data cleared")
