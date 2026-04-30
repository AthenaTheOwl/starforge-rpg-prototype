extends Node
## GameManager — Global state machine, save/load, scene transitions.
##
## States: TITLE, EXPLORATION, COMBAT, DIALOGUE, PAUSE
## Persists game state to JSON for save/load.

enum GameState { TITLE, EXPLORATION, COMBAT, DIALOGUE, PAUSE }

var current_state: GameState = GameState.TITLE
var _previous_state: GameState = GameState.TITLE

# Story progression flags (act, chapter, quest states)
var story_flags: Dictionary = {}
# Faction reputation scores (-100 to 100)
var faction_reputation: Dictionary = {
	"compact": 0,
	"sovereign_marches": 0,
	"guild_drift": 0,
	"rim_accord": 0,
	"sutured_houses": 0,
	"sealant_covenant": 0,
	"writbound": -50,
	"charter_network": 30,
}
# Current act/chapter for story tracking
var current_act: int = 1
var current_chapter: int = 1
# Play time in seconds
var play_time: float = 0.0
# World state tracking
var cleared_encounters: Array[String] = []
var unlocked_locations: Array[String] = []
var current_location: String = ""

signal state_changed(new_state: GameState, old_state: GameState)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if current_state != GameState.TITLE and current_state != GameState.PAUSE:
		play_time += delta


func change_state(new_state: GameState) -> void:
	_previous_state = current_state
	current_state = new_state
	state_changed.emit(new_state, _previous_state)


func set_flag(flag_name: String, value: Variant = true) -> void:
	story_flags[flag_name] = value
	# Autosave on major story flags
	if _is_major_story_flag(flag_name):
		_trigger_autosave()


func get_flag(flag_name: String, default: Variant = null) -> Variant:
	return story_flags.get(flag_name, default)


func has_flag(flag_name: String) -> bool:
	return flag_name in story_flags


func modify_reputation(faction: String, amount: int) -> void:
	if faction in faction_reputation:
		faction_reputation[faction] = clampi(faction_reputation[faction] + amount, -100, 100)


func get_reputation(faction: String) -> int:
	return faction_reputation.get(faction, 0)


func mark_encounter_cleared(encounter_id: String) -> void:
	if encounter_id not in cleared_encounters:
		cleared_encounters.append(encounter_id)


func is_encounter_cleared(encounter_id: String) -> bool:
	return encounter_id in cleared_encounters


func unlock_location(location_id: String) -> void:
	if location_id not in unlocked_locations:
		unlocked_locations.append(location_id)


func is_location_unlocked(location_id: String) -> bool:
	return location_id in unlocked_locations


# --- Save / Load ---

const SAVE_DIR := "user://saves/"
const SAVE_EXT := ".json"


func save_game(slot: int = 0) -> Error:
	var dir := DirAccess.open("user://")
	if not dir.dir_exists(SAVE_DIR.trim_prefix("user://")):
		dir.make_dir(SAVE_DIR.trim_prefix("user://"))

	var save_data := {
		"version": 1,
		"current_state": current_state,
		"story_flags": story_flags,
		"faction_reputation": faction_reputation,
		"current_act": current_act,
		"current_chapter": current_chapter,
		"play_time": play_time,
		"party": PartyManager.serialize(),
		"story_progress": StoryManager.serialize(),
		"timestamp": Time.get_datetime_string_from_system(),
	}

	var path := SAVE_DIR + "save_%d%s" % [slot, SAVE_EXT]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()

	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()
	return OK


func load_game(slot: int = 0) -> Error:
	var path := SAVE_DIR + "save_%d%s" % [slot, SAVE_EXT]
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()

	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		return err

	var data: Dictionary = json.data
	story_flags = data.get("story_flags", {})
	faction_reputation = data.get("faction_reputation", faction_reputation)
	current_act = data.get("current_act", 1)
	current_chapter = data.get("current_chapter", 1)
	play_time = data.get("play_time", 0.0)

	if data.has("party"):
		PartyManager.deserialize(data["party"])
	if data.has("story_progress"):
		StoryManager.deserialize(data["story_progress"])

	change_state(GameState.EXPLORATION)
	return OK


func get_save_info(slot: int = 0) -> Dictionary:
	var path := SAVE_DIR + "save_%d%s" % [slot, SAVE_EXT]
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	var data: Dictionary = json.data
	return {
		"act": data.get("current_act", 1),
		"chapter": data.get("current_chapter", 1),
		"play_time": data.get("play_time", 0.0),
		"timestamp": data.get("timestamp", ""),
	}


# --- Scene Transitions ---

func transition_to_scene(scene_path: String) -> void:
	SceneTransition.transition_to(scene_path)


func transition_to_combat(enemy_group: Array[Dictionary]) -> void:
	CombatManager.setup_encounter(enemy_group)
	change_state(GameState.COMBAT)
	transition_to_scene("res://scenes/battle/battle_scene.tscn")


func transition_to_exploration(location_id: String = "") -> void:
	change_state(GameState.EXPLORATION)
	transition_to_scene("res://scenes/exploration/exploration_scene.tscn")


func transition_to_dialogue(dialogue_id: String) -> void:
	change_state(GameState.DIALOGUE)
	DialogueManager.start_dialogue(dialogue_id)


# --- Autosave Support ---

func _is_major_story_flag(flag_name: String) -> bool:
	return (
		flag_name.begins_with("bonded_") or
		flag_name.begins_with("act_") or
		flag_name.begins_with("chapter_") or
		flag_name.begins_with("milestone_") or
		flag_name.begins_with("bee_") or
		flag_name.begins_with("conspiracy_") or
		flag_name == "has_lagrange_name" or
		flag_name == "completed_first_watch"
	)


func _trigger_autosave() -> void:
	# Defer autosave to next frame to avoid issues during state changes
	call_deferred("_perform_autosave")


func _perform_autosave() -> void:
	if SaveManager:
		SaveManager.autosave()
