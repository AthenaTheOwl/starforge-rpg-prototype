extends Control
## ChapterFlow — Orchestrates chapter progression: title card → dialogues → combat → next chapter.
##
## This is the main gameplay scene. It shows chapter titles, plays dialogues in sequence,
## triggers combat when appropriate, and advances the story.

@onready var dialogue_controller: Control = $DialogueController
@onready var transition_overlay: ColorRect = $TransitionOverlay
@onready var chapter_title_label: Label = $ChapterTitle
@onready var chapter_subtitle: Label = $ChapterSubtitle
@onready var continue_prompt: Button = $ContinuePrompt
@onready var hub_panel: Control = $HubPanel
@onready var hub_story_list: VBoxContainer = $HubPanel/VBox/StoryList
@onready var hub_optional_list: VBoxContainer = $HubPanel/VBox/OptionalList
@onready var hub_advance_btn: Button = $HubPanel/VBox/Actions/AdvanceBtn
@onready var hub_save_btn: Button = $HubPanel/VBox/Actions/SaveBtn

var _playing_dialogue: bool = false
var _awaiting_continue: bool = false


func _ready() -> void:
	transition_overlay.color = Color(0, 0, 0, 1)
	chapter_title_label.visible = false
	chapter_subtitle.visible = false
	continue_prompt.visible = false
	hub_panel.visible = false

	continue_prompt.pressed.connect(_on_continue_pressed)
	hub_advance_btn.pressed.connect(_on_advance_chapter)
	hub_save_btn.pressed.connect(_on_save_pressed)

	DialogueManager.dialogue_ended.connect(_on_dialogue_finished)

	# Start the current chapter (hub will check combat status automatically)
	_begin_chapter(GameManager.current_chapter)


func _begin_chapter(chapter_num: int) -> void:
	AudioManager.play_bgm("chapter_%d" % chapter_num)
	StoryManager.start_chapter(chapter_num)
	await _show_chapter_title(chapter_num)
	_show_hub()


func _show_chapter_title(chapter_num: int) -> void:
	var title := StoryManager.get_chapter_title(chapter_num)

	chapter_title_label.text = "Chapter %d" % chapter_num if chapter_num > 0 else "Prologue"
	chapter_subtitle.text = title
	chapter_title_label.visible = true
	chapter_subtitle.visible = true

	# Fade in
	var tween := create_tween()
	tween.tween_property(transition_overlay, "color:a", 0.0, 1.0)
	await tween.finished
	await get_tree().create_timer(2.0).timeout

	# Fade title out
	var fade := create_tween()
	fade.tween_property(chapter_title_label, "modulate:a", 0.0, 0.5)
	fade.parallel().tween_property(chapter_subtitle, "modulate:a", 0.0, 0.5)
	await fade.finished

	chapter_title_label.visible = false
	chapter_subtitle.visible = false
	chapter_title_label.modulate.a = 1.0
	chapter_subtitle.modulate.a = 1.0


func _show_hub() -> void:
	var chapter := GameManager.current_chapter
	var story := StoryManager.get_available_story_dialogues(chapter)
	var optional := StoryManager.get_available_optional_dialogues(chapter)

	# Clear old buttons
	for child in hub_story_list.get_children():
		child.queue_free()
	for child in hub_optional_list.get_children():
		child.queue_free()

	# If there are story dialogues that must be played, auto-play the first one
	if story.size() > 0:
		hub_panel.visible = false
		await _play_dialogue(story[0])
		# After dialogue ends, refresh hub
		_show_hub()
		return

	# Show hub with optional dialogues and advance button
	for d_id in optional:
		var btn := Button.new()
		var label := _get_dialogue_display_name(d_id)

		# Show NEW badge for unplayed dialogues
		if d_id not in StoryManager.played_dialogues:
			label = "[NEW] " + label

		# Check relationship gate
		var req_tier := StoryManager.get_dialogue_required_tier(d_id)
		if req_tier > 0:
			var char_id := StoryManager.get_dialogue_character(d_id)
			var current_tier := RelationshipManager.get_tier(char_id)
			if current_tier < req_tier:
				label = "🔒 " + label
				btn.disabled = true
				btn.tooltip_text = "Requires %s tier %d" % [char_id.capitalize(), req_tier]

		btn.text = label
		btn.pressed.connect(_on_hub_dialogue_pressed.bind(d_id))
		hub_optional_list.add_child(btn)

	hub_advance_btn.disabled = not StoryManager.can_advance_chapter()
	hub_advance_btn.text = "Continue to Chapter %d" % (chapter + 1)
	if chapter >= 10:
		hub_advance_btn.text = "Complete Act 1"

	hub_panel.visible = true


func _play_dialogue(dialogue_id: String) -> void:
	_playing_dialogue = true
	hub_panel.visible = false
	dialogue_controller.visible = true

	GameManager.change_state(GameManager.GameState.DIALOGUE)
	DialogueManager.start_dialogue(dialogue_id)

	# Wait for dialogue to end
	while _playing_dialogue:
		await get_tree().process_frame


func _on_dialogue_finished(_dialogue_id: String) -> void:
	_playing_dialogue = false
	dialogue_controller.visible = false
	GameManager.change_state(GameManager.GameState.EXPLORATION)


func _on_hub_dialogue_pressed(dialogue_id: String) -> void:
	await _play_dialogue(dialogue_id)
	_show_hub()


func _on_advance_chapter() -> void:
	var chapter := GameManager.current_chapter

	# Check for combat before advancing
	var combat_id := StoryManager.get_chapter_combat(chapter)
	if not combat_id.is_empty() and not GameManager.is_encounter_cleared(combat_id):
		_start_combat(combat_id)
		return

	StoryManager.complete_chapter(chapter)

	if chapter >= 10:
		_show_act_complete()
		return

	# Show chapter complete recap
	hub_panel.visible = false
	await _show_chapter_recap(chapter)

	# Fade to black and start next chapter
	var tween := create_tween()
	tween.tween_property(transition_overlay, "color:a", 1.0, 0.5)
	await tween.finished

	_begin_chapter(chapter + 1)


func _show_chapter_recap(chapter_num: int) -> void:
	var title := StoryManager.get_chapter_title(chapter_num)
	chapter_title_label.text = "Chapter Complete"
	chapter_subtitle.text = title
	chapter_title_label.visible = true
	chapter_subtitle.visible = true

	# Fade in recap
	chapter_title_label.modulate.a = 0.0
	chapter_subtitle.modulate.a = 0.0
	var fade_in := create_tween()
	fade_in.tween_property(chapter_title_label, "modulate:a", 1.0, 0.5)
	fade_in.parallel().tween_property(chapter_subtitle, "modulate:a", 1.0, 0.5)
	await fade_in.finished
	await get_tree().create_timer(1.5).timeout

	# Fade out recap
	var fade_out := create_tween()
	fade_out.tween_property(chapter_title_label, "modulate:a", 0.0, 0.5)
	fade_out.parallel().tween_property(chapter_subtitle, "modulate:a", 0.0, 0.5)
	await fade_out.finished

	chapter_title_label.visible = false
	chapter_subtitle.visible = false
	chapter_title_label.modulate.a = 1.0
	chapter_subtitle.modulate.a = 1.0


func _start_combat(encounter_id: String) -> void:
	hub_panel.visible = false

	# Load encounter JSON
	var encounter_path := "res://data/encounters/%s.json" % encounter_id
	var file := FileAccess.open(encounter_path, FileAccess.READ)
	if file == null:
		push_error("ChapterFlow: Could not load encounter %s" % encounter_id)
		_show_hub()
		return

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("ChapterFlow: Failed to parse encounter %s" % encounter_id)
		_show_hub()
		return

	var encounter: Dictionary = json.data

	# Resolve enemy types from waves into flat array
	var enemy_group: Array[Dictionary] = []
	for wave in encounter.get("waves", []):
		for entry in wave.get("enemies", []):
			var enemy_type: String = entry.get("type", "")
			var count: int = entry.get("count", 1)
			var enemy_data := _load_enemy_type(enemy_type)
			if enemy_data.is_empty():
				continue
			for i in count:
				var e := enemy_data.duplicate(true)
				e["id"] = "%s_%d" % [enemy_type, i]
				enemy_group.append(e)

	# Store encounter ID so battle scene can mark it cleared on victory
	GameManager.set_flag("_pending_encounter", encounter_id)

	# Set up combat and transition
	CombatManager.setup_encounter(enemy_group)
	GameManager.change_state(GameManager.GameState.COMBAT)
	GameManager.transition_to_scene("res://scenes/battle/battle_scene.tscn")


func _load_enemy_type(enemy_type: String) -> Dictionary:
	var path := "res://data/enemies/%s.json" % enemy_type
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("ChapterFlow: Could not load enemy type %s" % enemy_type)
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	return json.data


func _show_act_complete() -> void:
	hub_panel.visible = false
	chapter_title_label.text = "Act 1 Complete"
	chapter_subtitle.text = "To be continued..."
	chapter_title_label.visible = true
	chapter_subtitle.visible = true
	continue_prompt.text = "Return to Title"
	continue_prompt.visible = true
	_awaiting_continue = true


func _on_continue_pressed() -> void:
	if _awaiting_continue:
		GameManager.transition_to_scene("res://scenes/menus/title_screen.tscn")


func _on_save_pressed() -> void:
	GameManager.save_game(0)


func _get_dialogue_display_name(dialogue_id: String) -> String:
	var names := {
		"act1_prologue_boarding": "The Boarding",
		"act1_elia_rescue": "Mine Rescue",
		"act1_naming_scene": "A Name of Your Own",
		"act1_first_watch": "First Watch",
		"act1_ai_citizens_intro": "Meet the Citizens",
		"act1_bonding_vesper": "Talk to Vesper",
		"act1_bonding_nyx": "Talk to Nyx",
		"act1_bonding_jalen": "Talk to Jalen",
		"act1_bonding_rho": "Talk to Rho",
		"act1_bonding_elisira": "Talk to Elisira",
		"act1_crew_meal": "Crew Dinner",
		"act1_forbidden_citizens": "The Secret",
		"act1_souffle_becoming": "The Becoming",
		"act1_shard_whispers": "Shard Whispers",
		"act1_trust_breaking_point": "Breaking Point",
		"act1_bee_manifestation": "Bee Awakens",
		"act1_corporate_conspiracy": "The Conspiracy",
		"act1_mentor_contact": "Mentor's Call",
		"act1_deep_vesper": "Vesper's Past",
		"act1_deep_nyx": "Nyx's Memory",
		"act1_deep_rho": "Rho's Burden",
		"act1_party_split_briefing": "Battle Briefing",
		"act1_climax_setup": "The Plan",
	}
	return names.get(dialogue_id, dialogue_id.replace("act1_", "").replace("_", " ").capitalize())
