extends Node
## SaveManager — Persistent save/load system with 3 manual slots + 1 autosave.
##
## Provides centralized save/load functionality that serializes game state,
## party data, dialogue history, and world state to JSON files.
## Supports manual saves (slots 0-2) and automatic autosave slot.

const SAVE_DIR := "user://saves/"
const MAX_MANUAL_SLOTS := 3
const AUTOSAVE_SLOT := "autosave"
const SAVE_VERSION := "1.0"

signal game_saved(slot: int)
signal game_loaded(slot: int)
signal autosave_triggered()


func _ready() -> void:
	_ensure_save_dir()


## Save game to specified slot (0-2 for manual, -1 for autosave).
func save_game(slot: int) -> Error:
	if slot < -1 or slot >= MAX_MANUAL_SLOTS:
		push_error("Invalid save slot: %d" % slot)
		return ERR_INVALID_PARAMETER

	_ensure_save_dir()

	var save_data := _collect_save_data(slot)
	var file_path := _get_save_path(slot)

	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open save file: %s" % error_string(FileAccess.get_open_error()))
		return FileAccess.get_open_error()

	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()

	game_saved.emit(slot)
	return OK


## Load game from specified slot (0-2 for manual, -1 for autosave).
func load_game(slot: int) -> Error:
	if slot < -1 or slot >= MAX_MANUAL_SLOTS:
		push_error("Invalid save slot: %d" % slot)
		return ERR_INVALID_PARAMETER

	var file_path := _get_save_path(slot)
	if not FileAccess.file_exists(file_path):
		return ERR_FILE_NOT_FOUND

	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()

	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()

	if err != OK:
		push_error("Failed to parse save file: %s" % error_string(err))
		return err

	var data: Dictionary = json.data
	_restore_save_data(data)

	game_loaded.emit(slot)
	return OK


## Save to autosave slot.
func autosave() -> Error:
	autosave_triggered.emit()
	return save_game(-1)


## Get save metadata without full load.
func get_save_info(slot: int) -> Dictionary:
	if slot < -1 or slot >= MAX_MANUAL_SLOTS:
		return {}

	var file_path := _get_save_path(slot)
	if not FileAccess.file_exists(file_path):
		return {}

	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {}

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return {}

	file.close()
	var data: Dictionary = json.data

	# Return metadata only
	return {
		"save_name": data.get("save_name", ""),
		"timestamp": data.get("timestamp", ""),
		"playtime_seconds": data.get("playtime_seconds", 0),
		"current_act": data.get("game_state", {}).get("current_act", 1),
		"current_chapter": data.get("game_state", {}).get("current_chapter", 1),
		"current_location": data.get("game_state", {}).get("current_location", ""),
		"version": data.get("version", ""),
	}


## Check if save exists in slot.
func has_save(slot: int) -> bool:
	if slot < -1 or slot >= MAX_MANUAL_SLOTS:
		return false
	return FileAccess.file_exists(_get_save_path(slot))


## Delete save in slot.
func delete_save(slot: int) -> Error:
	if slot < -1 or slot >= MAX_MANUAL_SLOTS:
		return ERR_INVALID_PARAMETER

	var file_path := _get_save_path(slot)
	if not FileAccess.file_exists(file_path):
		return ERR_FILE_NOT_FOUND

	var dir := DirAccess.open("user://saves/")
	if dir == null:
		return DirAccess.get_open_error()

	var err := dir.remove(file_path.get_file())
	return err


## Get info for all save slots including autosave.
func get_all_save_info() -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	# Manual slots 0-2
	for i in range(MAX_MANUAL_SLOTS):
		result.append(get_save_info(i))

	# Autosave slot
	result.append(get_save_info(-1))

	return result


# --- Private Methods ---

func _ensure_save_dir() -> void:
	var dir := DirAccess.open("user://")
	if dir != null and not dir.dir_exists("saves"):
		dir.make_dir("saves")


func _get_save_path(slot: int) -> String:
	if slot == -1:
		return SAVE_DIR + AUTOSAVE_SLOT + ".json"
	else:
		return SAVE_DIR + "save_%d.json" % slot


func _get_save_name(slot: int) -> String:
	if slot == -1:
		return "Autosave"
	else:
		return "Manual Save %d" % (slot + 1)


func _collect_save_data(slot: int) -> Dictionary:
	var timestamp := Time.get_datetime_string_from_system()
	var playtime := int(GameManager.play_time)

	# Collect party data
	var party_data := PartyManager.serialize()

	# Collect game state
	var game_state := {
		"flags": GameManager.story_flags.duplicate(true),
		"reputation": GameManager.faction_reputation.duplicate(true),
		"current_act": GameManager.current_act,
		"current_chapter": GameManager.current_chapter,
		"current_location": GameManager.current_location,
		"cleared_encounters": GameManager.cleared_encounters.duplicate(),
		"unlocked_locations": GameManager.unlocked_locations.duplicate(),
	}

	# Collect dialogue history
	var dialogue_history := DialogueManager.dialogue_history.duplicate(true)

	return {
		"version": SAVE_VERSION,
		"timestamp": timestamp,
		"playtime_seconds": playtime,
		"save_name": _get_save_name(slot),
		"party": party_data,
		"game_state": game_state,
		"dialogue_history": dialogue_history,
		"story_progress": StoryManager.serialize(),
		"relationships": RelationshipManager.serialize(),
	}


func _restore_save_data(data: Dictionary) -> void:
	# Restore game state
	var game_state: Dictionary = data.get("game_state", {})
	GameManager.story_flags = game_state.get("flags", {})
	GameManager.faction_reputation = game_state.get("reputation", GameManager.faction_reputation)
	GameManager.current_act = game_state.get("current_act", 1)
	GameManager.current_chapter = game_state.get("current_chapter", 1)
	GameManager.current_location = game_state.get("current_location", "")

	# Convert untyped arrays from JSON to typed arrays
	GameManager.cleared_encounters.clear()
	for enc in game_state.get("cleared_encounters", []):
		GameManager.cleared_encounters.append(str(enc))

	GameManager.unlocked_locations.clear()
	for loc in game_state.get("unlocked_locations", []):
		GameManager.unlocked_locations.append(str(loc))
	GameManager.play_time = data.get("playtime_seconds", 0.0)

	# Restore party data
	if data.has("party"):
		PartyManager.deserialize(data["party"])

	# Restore dialogue history (convert to typed array)
	DialogueManager.dialogue_history.clear()
	for entry in data.get("dialogue_history", []):
		if entry is Dictionary:
			DialogueManager.dialogue_history.append(entry)

	# Restore story progress
	if data.has("story_progress"):
		StoryManager.deserialize(data["story_progress"])

	# Restore relationships
	if data.has("relationships"):
		RelationshipManager.deserialize(data["relationships"])

	# Navigate to chapter flow to resume story
	GameManager.change_state(GameManager.GameState.EXPLORATION)
	GameManager.transition_to_scene("res://scenes/story/chapter_flow.tscn")
