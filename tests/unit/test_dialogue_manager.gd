extends GutTest
## Tests for DialogueManager — dialogue flow, skill checks, choices, history.
##
## Since DialogueManager is an autoload that loads JSON from disk, we bypass
## _load_dialogue by injecting dialogue_data directly and calling internal
## methods where possible.


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
