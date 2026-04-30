extends Control
## ExplorationController — Drives the location-based exploration screen.
##
## Loads location data from JSON, displays description text, populates action
## buttons (talk, examine, move, use), and shows party status in the sidebar.

@onready var location_title: Label = $HSplit/LeftPanel/LocationTitle
@onready var description_text: RichTextLabel = $HSplit/LeftPanel/DescriptionScroll/DescriptionText
@onready var action_buttons: VBoxContainer = $HSplit/LeftPanel/ActionButtons
@onready var party_list: VBoxContainer = $HSplit/RightPanel/PartyList
@onready var info_label: Label = $HSplit/RightPanel/InfoLabel
@onready var save_btn: Button = $HSplit/RightPanel/MenuBar/SaveBtn

var current_location: Dictionary = {}
var dialogue_overlay: DialogueOverlay = null


func _ready() -> void:
	save_btn.pressed.connect(_on_save)
	PartyManager.party_changed.connect(_refresh_party_display)
	_load_location(_get_starting_location())
	_refresh_party_display()
	_update_info_label()


func _load_location(location_id: String) -> void:
	var data := _read_location_data(location_id)
	if data.is_empty():
		# Fallback: show a default location
		data = _default_location()
	current_location = data
	# Update GameManager with current location for save system
	GameManager.current_location = location_id
	_display_location()


func _display_location() -> void:
	location_title.text = current_location.get("name", "UNKNOWN LOCATION").to_upper()
	description_text.text = current_location.get("description", "You stand in an empty void.")
	_populate_actions()


func _populate_actions() -> void:
	# Clear existing buttons
	for child in action_buttons.get_children():
		child.queue_free()

	var actions: Array = current_location.get("actions", [])
	for action in actions:
		# Check if action is available based on flags/reputation
		if not _check_action_available(action):
			continue
		var btn := Button.new()
		btn.text = action.get("label", "???")
		btn.tooltip_text = action.get("tooltip", "")
		var action_data := action  # capture for lambda
		btn.pressed.connect(func(): _execute_action(action_data))
		action_buttons.add_child(btn)


func _execute_action(action: Dictionary) -> void:
	var action_type: String = action.get("type", "")
	match action_type:
		"move":
			_load_location(action.get("target_location", ""))
		"talk":
			_start_dialogue_overlay(action.get("dialogue_id", ""))
		"examine":
			# Show examine text in description area
			description_text.text = action.get("examine_text", "Nothing notable.")
			# Add a "back" button
			_populate_actions()
		"combat":
			var enemies: Array[Dictionary] = []
			for e in action.get("enemies", []):
				enemies.append(e)
			GameManager.transition_to_combat(enemies)
		"recruit":
			PartyManager.recruit_character(action.get("character_id", ""))
			# Show recruitment text
			description_text.text += "\n\n[i]%s has joined your party.[/i]" % action.get("character_name", "Someone")
			# Set flag so this action won't appear again
			GameManager.set_flag(action.get("flag", "recruited_" + action.get("character_id", "")))
			_populate_actions()
		"flag":
			GameManager.set_flag(action.get("flag", ""), action.get("flag_value", true))
			if action.has("result_text"):
				description_text.text += "\n\n" + action["result_text"]
			_populate_actions()
		"quest_advance":
			GameManager.current_chapter = action.get("chapter", GameManager.current_chapter)
			if action.has("result_text"):
				description_text.text += "\n\n" + action["result_text"]
			_update_info_label()
			_populate_actions()
		_:
			push_warning("Unknown action type: %s" % action_type)


func _check_action_available(action: Dictionary) -> bool:
	if action.has("requires_flag"):
		if not GameManager.has_flag(action["requires_flag"]):
			return false
	if action.has("excludes_flag"):
		if GameManager.has_flag(action["excludes_flag"]):
			return false
	if action.has("requires_reputation"):
		for faction in action["requires_reputation"]:
			if GameManager.get_reputation(faction) < action["requires_reputation"][faction]:
				return false
	return true


func _refresh_party_display() -> void:
	if not is_inside_tree():
		return
	for child in party_list.get_children():
		child.queue_free()

	for c in PartyManager.get_active_characters():
		var panel := _create_party_member_panel(c)
		party_list.add_child(panel)


func _create_party_member_panel(character: Dictionary) -> VBoxContainer:
	var panel := VBoxContainer.new()

	var name_label := Label.new()
	name_label.text = "%s — %s" % [character.get("name", "???"), character.get("role", "")]
	panel.add_child(name_label)

	var hp_bar := ProgressBar.new()
	hp_bar.max_value = character.get("hp_max", 100)
	hp_bar.value = character.get("hp", 100)
	hp_bar.custom_minimum_size = Vector2(0, 16)
	hp_bar.tooltip_text = "HP: %d / %d" % [character.get("hp", 0), character.get("hp_max", 100)]
	panel.add_child(hp_bar)

	var heat_label := Label.new()
	heat_label.text = "Heat: %d/5" % character.get("heat", 0)
	panel.add_child(heat_label)

	var sep := HSeparator.new()
	panel.add_child(sep)

	return panel


func _update_info_label() -> void:
	info_label.text = "Act %d — Chapter %d" % [GameManager.current_act, GameManager.current_chapter]


func _on_save() -> void:
	var err := GameManager.save_game(0)
	if err == OK:
		description_text.text += "\n\n[i]Game saved.[/i]"
	else:
		description_text.text += "\n\n[color=red]Save failed: %s[/color]" % error_string(err)


func _get_starting_location() -> String:
	# Determine starting location based on story state
	if GameManager.current_act == 1 and GameManager.current_chapter == 1:
		return "act1_site_k9"
	return "act1_site_k9"


func _read_location_data(location_id: String) -> Dictionary:
	var path := "res://data/quests/%s.json" % location_id
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	return json.data


func _start_dialogue_overlay(dialogue_id: String) -> void:
	if dialogue_id.is_empty():
		return
	if dialogue_overlay == null:
		dialogue_overlay = DialogueOverlay.new()
		add_child(dialogue_overlay)
	if not dialogue_overlay.dialogue_finished.is_connected(_on_dialogue_finished):
		dialogue_overlay.dialogue_finished.connect(_on_dialogue_finished)
	dialogue_overlay.show_dialogue(dialogue_id)


func _on_dialogue_finished() -> void:
	GameManager.change_state(GameManager.GameState.EXPLORATION)
	# Refresh actions — dialogue may have set flags that change availability
	_populate_actions()


func _default_location() -> Dictionary:
	return {
		"id": "act1_site_k9",
		"name": "Site K-9 — The Kennel",
		"description": "The corridor smells of recycled air and old fear. Fluorescent panels buzz overhead, every third one dead or dying. The walls are institutional gray—the kind of gray that exists to remind you that color is a privilege.\n\nYou are Avyanna Lagrange, and you have been here for as long as you can remember. The extraction schedule says you are due in forty-seven minutes.\n\nSomething is different today. The guards changed shift early. The surveillance feeds hiccupped—just for a moment, but you felt it in the Lattice like a skipped heartbeat.\n\n[i](Something is wrong. Something is finally, beautifully wrong.)[/i]",
		"actions": [
			{
				"type": "examine",
				"label": "Examine the corridor",
				"examine_text": "The corridor stretches in both directions. To the east, the extraction wing—you know every crack in that ceiling. To the west, the processing hub where new arrivals get their numbers.\n\nThe surveillance node above the junction is dark. That never happens."
			},
			{
				"type": "examine",
				"label": "Check the Lattice",
				"examine_text": "You close your eyes and reach—not with hands, but with that other sense, the one they've been harvesting.\n\nThe Lattice here is thin and bruised, shot through with Synthetic overlays that taste like copper and obligation. But underneath—underneath there's something. A pulse. A rhythm that doesn't belong to the extraction machinery.\n\n[i]{BEE:: anomaly detected | extraction grid interrupted | opportunity window: narrowing}[/i]"
			},
			{
				"type": "flag",
				"label": "Wait for the extraction appointment",
				"flag": "waited_for_extraction",
				"result_text": "You sit against the wall and wait. The familiar dread settles in your stomach like sediment.\n\nBut the appointment never comes. Instead, an explosion rocks the eastern wing. Alarms scream. The lights go red.\n\nSomeone is attacking Site K-9."
			},
			{
				"type": "move",
				"label": "Move toward the disturbance (west corridor)",
				"target_location": "act1_west_corridor",
				"requires_flag": "waited_for_extraction"
			}
		]
	}
