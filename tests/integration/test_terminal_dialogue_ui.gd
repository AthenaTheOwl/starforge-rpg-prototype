extends GutTest
## Packed ChapterFlow/DialogueController lifecycle: terminal prose must be read
## before completion, including every newly authored terminal callback node.

var flow: Control
var saved_flags: Dictionary
var saved_played: Array[String]
var saved_chapter: int
var saved_state: int
var saved_time_scale: float


func before_each():
	saved_flags = GameManager.story_flags.duplicate(true)
	saved_played = StoryManager.played_dialogues.duplicate()
	saved_chapter = GameManager.current_chapter
	saved_state = GameManager.current_state
	saved_time_scale = Engine.time_scale
	Engine.time_scale = 80.0
	GameManager.current_chapter = 4
	# Keep background save/load test scene transitions from starting story UI.
	for chapter in StoryManager.CHAPTER_SEQUENCE.values():
		for scene in chapter.get("story_dialogues", []):
			StoryManager.mark_dialogue_played(scene)
	flow = load("res://scenes/story/chapter_flow.tscn").instantiate()
	add_child_autofree(flow)
	assert_true(await _wait_for(func(): return flow.hub_panel.visible))


func after_each():
	DialogueManager.end_dialogue()
	GameManager.story_flags = saved_flags
	StoryManager.played_dialogues = saved_played
	GameManager.current_chapter = saved_chapter
	GameManager.current_state = saved_state as GameManager.GameState
	Engine.time_scale = saved_time_scale


func _wait_for(predicate: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		await get_tree().process_frame
	return false


func _display_terminal(scene: String, node_id: String, node: Dictionary) -> void:
	StoryManager.played_dialogues.erase(scene)
	DialogueManager.current_dialogue_id = scene
	DialogueManager.current_node_id = node_id
	DialogueManager.dialogue_data = {"start_node": node_id, "nodes": {node_id: node}}
	DialogueManager.dialogue_history.clear()
	DialogueManager.is_active = true
	flow._playing_dialogue = true
	flow.hub_panel.visible = false
	flow.dialogue_controller.visible = true
	GameManager.change_state(GameManager.GameState.DIALOGUE)
	DialogueManager._display_node(node_id)


func test_terminal_text_and_authored_callbacks_wait_for_actual_continue():
	var cases: Array = [
		["terminal_explicit", "final", {"speaker": "Elia", "text": "Stay until the words are finished.", "next": "end"}],
		["terminal_implicit", "final", {"speaker": "Elia", "text": "There is no next node here."}],
		["terminal_filtered", "final", {"speaker": "Elia", "text": "No available answers.", "choices": [
			{"text": "Unavailable", "requires_flag": "unavailable_terminal_flag", "next": "end"}]}],
	]
	# Closing nodes from the story: two carry authored callbacks, two are plain prose.
	for route in [["act1_naming_scene", "dinner_after_answer", true], ["act1_elia_rescue", "beyond_k9", false],
			["act1_first_watch", "watch_released", false], ["act1_souffle_becoming", "citizen_at_rest", true]]:
		var data := DialogueManager._load_dialogue(route[0])
		var closing: Dictionary = data["nodes"][route[1]]
		assert_eq(not closing.get("echoes", []).is_empty(), route[2],
			"%s:%s callback presence matches this case's label" % [route[0], route[1]])
		cases.append([route[0], route[1], closing])
	for fixture in cases:
		var scene: String = fixture[0]
		var node: Dictionary = fixture[2]
		GameManager.story_flags.clear()
		for echo in node.get("echoes", []): GameManager.story_flags[echo["flag"]] = true
		_display_terminal(scene, fixture[1], node)
		await get_tree().process_frame
		var controller: Control = flow.dialogue_controller
		assert_true(DialogueManager.is_active, "%s remains active for acknowledgement" % scene)
		assert_true(controller.is_visible_in_tree(), "%s cannot hide its final prose" % scene)
		assert_false(StoryManager.has_played_dialogue(scene), "Display alone must not complete the story")
		assert_true(controller.continue_btn.visible, "Explicit, implicit and filtered-choice terminals offer Continue")
		assert_true(await _wait_for(func(): return not controller._typewriter_active), "Typewriter completes without dismissing the node")
		assert_true(controller.is_visible_in_tree())
		assert_true(DialogueManager.is_active)
		for echo in node.get("echoes", []):
			assert_true(controller.dialogue_text.text.contains(echo["text"]), "Actual packed UI retains the authored terminal callback")
		controller.continue_btn.pressed.emit()
		assert_false(DialogueManager.is_active)
		assert_false(controller.visible, "ChapterFlow hides the controller only after Continue")
		assert_true(StoryManager.has_played_dialogue(scene))
		assert_eq(GameManager.current_state, GameManager.GameState.EXPLORATION)
		await get_tree().process_frame


func test_legacy_check_button_uses_canonical_metadata_and_choice_end_is_explicit():
	_display_terminal("terminal_choice", "choice", {"speaker": "Avyanna", "text": "Choose.", "choices": [
		{"text": "Finish.", "next": "end"},
		{"text": "Try.", "skill_check": {"skill": "empathy", "dc": 12}, "next": "end"},
	]})
	await get_tree().process_frame
	var controller: Control = flow.dialogue_controller
	assert_false(controller.continue_btn.visible)
	assert_eq(controller.choices_container.get_child_count(), 2)
	var check_button: Button = controller.choices_container.get_child(1)
	assert_true(check_button.text.contains("Empathy 12"))
	assert_false(check_button.text.contains("???"))
	controller.choices_container.get_child(0).pressed.emit()
	assert_false(DialogueManager.is_active, "Selecting an explicit end choice is an acknowledgement")
	assert_true(StoryManager.has_played_dialogue("terminal_choice"))
	await get_tree().process_frame
