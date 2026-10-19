extends GutTest
## Exercise the public entrances through actual available DialogueManager choices.
## A graph-only reference cannot prove a gated choice is selectable at runtime.

var saved_flags: Dictionary
var saved_reputation: Dictionary
var saved_played: Array[String]


func before_each():
	saved_flags = GameManager.story_flags.duplicate(true)
	saved_reputation = GameManager.faction_reputation.duplicate(true)
	saved_played = StoryManager.played_dialogues.duplicate()
	GameManager.story_flags.clear()
	StoryManager.played_dialogues.clear()
	seed(1342)


func after_each():
	DialogueManager.end_dialogue()
	GameManager.story_flags = saved_flags
	GameManager.faction_reputation = saved_reputation
	StoryManager.played_dialogues = saved_played


func test_needing_time_for_name_does_not_softlock_later_story():
	assert_false(StoryManager.is_dialogue_available("act1_first_watch"))
	assert_false(StoryManager.is_dialogue_available("act1_bee_manifestation"))
	DialogueManager.start_dialogue("act1_naming_scene")
	assert_true(_walk_to("time_response"), "Actually choose the authored need-time branch")
	_finish_dialogue()
	assert_true(StoryManager.has_played_dialogue("act1_naming_scene"))
	assert_true(GameManager.get_flag("naming_complete", false))
	assert_false(GameManager.has_flag("has_lagrange_name"), "Consent is preserved; no surname is imposed")
	assert_has(StoryManager.get_available_story_dialogues(3), "act1_first_watch")
	assert_true(StoryManager.is_dialogue_available("act1_bee_manifestation"))
	var first_watch := DialogueManager._load_dialogue("act1_first_watch")
	assert_false(DialogueManager._get_node_text(first_watch["nodes"]["waffle_observation"]).contains("Lagrange"), "The next scene must respect the unanswered surname offer")


func test_accepting_name_preserves_both_name_and_progression():
	DialogueManager.start_dialogue("act1_naming_scene")
	assert_true(_walk_to("naming_complete_flag"), "Actually choose an acceptance path")
	_finish_dialogue()
	assert_true(GameManager.get_flag("has_lagrange_name", false))
	assert_true(GameManager.get_flag("naming_complete", false))
	assert_has(StoryManager.get_available_story_dialogues(3), "act1_first_watch")
	assert_true(StoryManager.is_dialogue_available("act1_bee_manifestation"))
	var first_watch := DialogueManager._load_dialogue("act1_first_watch")
	var observation: Dictionary = first_watch["nodes"]["waffle_observation"]
	assert_eq(DialogueManager._get_node_text(observation), observation["text"], "The original accepted-name line is preserved exactly")


func _finish_dialogue() -> void:
	for _step in range(500):
		if not DialogueManager.is_active:
			return
		var node: Dictionary = DialogueManager.dialogue_data["nodes"][DialogueManager.current_node_id]
		if not DialogueManager._get_available_choices(node).is_empty():
			DialogueManager.select_choice(0)
		else:
			DialogueManager._display_node(DialogueManager.current_node_id)
	assert_false(DialogueManager.is_active, "Dialogue must end within a bounded number of advances")


func test_nyx_safeguard_lesson_can_be_selected_and_completed():
	DialogueManager.start_dialogue("act1_deep_nyx")
	assert_true(_walk_to("choice_bee_resolution"), "Reach the existing choice from the authored start")
	assert_true(_select_destination("offer_training_path"), "New lesson is an actually available choice")
	assert_eq(DialogueManager.get_history().back().get("node_id"), "offer_training_path")
	assert_true(_walk_to("nyx_confirms_feeling"), "Traverse the lesson to its authored conclusion")
	assert_false(DialogueManager.is_active, "The lesson exits normally")
	assert_true(GameManager.get_flag("nyx_lattice_training", false))
	assert_true(GameManager.get_flag("deep_nyx_complete", false))


func test_forbidden_alternative_question_rejoins_existing_stakes_and_exits():
	DialogueManager.start_dialogue("act1_forbidden_citizens")
	assert_true(_walk_to("choice_personhood"), "Reach the existing question from the authored start")
	assert_true(_select_destination("elia_moral_imperative"), "Alternative protection question is available")
	assert_eq(DialogueManager.get_history().back().get("node_id"), "elia_moral_imperative")
	assert_true(_walk_to("elia_stakes_clear"), "The rebuttal rejoins the original conversation")
	assert_true(_walk_to("bubbles_final"), "The scene still reaches its original exit")
	assert_false(DialogueManager.is_active)
	assert_true(GameManager.get_flag("ai_illegality_revealed", false))


func test_authored_check_hints_enter_standalone_check_once_in_both_outcomes():
	var exercised := 0
	for scene in ["act1_crew_meal", "act1_first_watch"]:
		var data := DialogueManager._load_dialogue(scene)
		for node_id in data["nodes"]:
			var node: Dictionary = data["nodes"][node_id]
			for choice in node.get("choices", []):
				if not choice.has("skill_check") or DialogueManager._skill_check_has_outcomes(choice["skill_check"]):
					continue
				var check_node: String = choice["next"]
				var check: Dictionary = data["nodes"][check_node]["skill_check"]
				for roll in [1, 20]:
					GameManager.story_flags.clear()
					DialogueManager.dialogue_data = data
					DialogueManager.current_dialogue_id = scene
					DialogueManager.current_node_id = node_id
					DialogueManager.is_active = true
					DialogueManager.dialogue_history.clear()
					DialogueManager._display_node(node_id)
					_seed_exact_roll(roll)
					assert_true(_select_destination(check_node), "%s/%s choice remains available" % [scene, node_id])
					var checks := 0
					var reached := false
					var expected: String = check["on_failure"] if roll == 1 else check["on_success"]
					for entry in DialogueManager.get_history():
						if entry.get("type") == "skill_check":
							checks += 1
							assert_eq(entry.get("node_id"), check_node, "Only the standalone node rolls")
						if entry.get("node_id") == expected: reached = true
					assert_eq(checks, 1, "The choice hint must not cause a second roll")
					assert_true(reached, "The actual authored outcome is displayed")
					assert_true(DialogueManager.is_active, "A display hint must not prematurely finish the scene")
					exercised += 1
	assert_eq(exercised, 16, "All eight canonical hints exercise both outcome routes")


func _seed_exact_roll(wanted: int) -> void:
	for value in range(10000):
		seed(value)
		if randi() % 20 + 1 == wanted:
			seed(value)
			return
	fail_test("Cannot find deterministic d20 fixture")


func test_authored_staging_is_displayed_before_one_check_in_both_outcomes():
	var routes := [
		["act1_ai_citizens_intro", "choice_waffle_response", 2, ["branch_waffle_empathy", "waffle_empathy_01"], "waffle_empathy_01_resolve"],
		["act1_ai_citizens_intro", "choice_cinnamon_interact", 1, ["branch_cinnamon_tech_check", "cinnamon_tech_check_system"], "cinnamon_tech_check_system_resolve"],
		["act1_ai_citizens_intro", "choice_ai_understanding", 3, ["branch_elia_secret", "elia_secret_check_system"], "elia_secret_check_system_resolve"],
		["act1_deep_rho", "empathy_check", 0, ["empathy_roll"], "empathy_roll_resolve"],
		["act1_deep_vesper", "killed_reaction", 1, ["empathy_check"], "empathy_check_resolve"],
		["act1_deep_vesper", "night_aftermath_response", 2, ["insight_check_math"], "insight_check_math_resolve"],
		["act1_deep_vesper", "coping_response", 1, ["empathy_check_2"], "empathy_check_2_resolve"],
		["act1_deep_vesper", "vesper_fear_response", 2, ["insight_check_caring"], "insight_check_caring_resolve"],
		["act1_forbidden_citizens", "choice_early_reaction", 2, ["empathy_check"], "empathy_check_resolve"],
	]
	for route in routes:
		var data := DialogueManager._load_dialogue(route[0])
		var router: Dictionary = data["nodes"][route[4]]
		var check := DialogueManager._normalize_skill_check(router.get("check", router.get("skill_check", {})))
		for roll in [1, 20]:
			GameManager.story_flags.clear()
			DialogueManager.dialogue_data = data
			DialogueManager.current_dialogue_id = route[0]
			DialogueManager.current_node_id = route[1]
			DialogueManager.is_active = true
			DialogueManager.dialogue_history.clear()
			DialogueManager._display_node(route[1])
			_seed_exact_roll(roll)
			DialogueManager.select_choice(route[2])
			var expected: String = check["on_failure"] if roll == 1 else check["on_success"]
			for _step in range(10):
				if DialogueManager.get_history().back().get("node_id") == expected or not DialogueManager.is_active:
					break
				DialogueManager._display_node(DialogueManager.current_node_id)
			var displayed: Array = []
			var checks := 0
			for entry in DialogueManager.get_history():
				if entry.get("type") == "dialogue": displayed.append(entry["node_id"])
				if entry.get("type") == "skill_check":
					checks += 1
					assert_eq(entry.get("node_id"), route[4])
			for staging in route[3]:
				assert_has(displayed, staging, "Original staging text is actually displayed before the roll")
				assert_eq(DialogueManager.get_history()[displayed.find(staging)]["text"], data["nodes"][staging]["text"])
			assert_eq(checks, 1)
			assert_eq(DialogueManager.get_history().back().get("node_id"), expected)
			assert_true(DialogueManager.is_active)


func _select_destination(target: String) -> bool:
	var node: Dictionary = DialogueManager.dialogue_data.get("nodes", {}).get(DialogueManager.current_node_id, {})
	var choices: Array = DialogueManager._get_available_choices(node)
	for index in range(choices.size()):
		if choices[index].get("next", "") == target:
			DialogueManager.select_choice(index)
			return true
	return false


func _walk_to(target: String) -> bool:
	for _step in range(500):
		var history: Array[Dictionary] = DialogueManager.get_history()
		if not history.is_empty() and history.back().get("node_id", "") == target:
			return true
		if not DialogueManager.is_active:
			return false
		var current: String = DialogueManager.current_node_id
		var nodes: Dictionary = DialogueManager.dialogue_data["nodes"]
		var node: Dictionary = nodes[current]
		# Text-only nodes queue their successor for the UI to display on Advance.
		if history.is_empty() or history.back().get("node_id", "") != current:
			DialogueManager._display_node(current)
			continue
		var choices: Array = DialogueManager._get_available_choices(node)
		var selected := false
		for index in range(choices.size()):
			var choice: Dictionary = choices[index]
			# Use a deterministic non-check route; separate unit tests cover both rolls.
			if not choice.has("skill_check") and _has_route(nodes, choice.get("next", ""), target):
				DialogueManager.select_choice(index)
				selected = true
				break
		if not selected:
			return false
	return false


func _has_route(nodes: Dictionary, start: String, target: String) -> bool:
	var pending: Array = [start]
	var seen := {}
	while not pending.is_empty():
		var current: String = pending.pop_front()
		if current == target:
			return true
		if seen.has(current) or not nodes.has(current):
			continue
		seen[current] = true
		var node: Dictionary = nodes[current]
		if node.has("next"):
			pending.append(node["next"])
		for choice in node.get("choices", []):
			if not choice.has("skill_check"):
				pending.append(choice.get("next", ""))
	return false
