extends Node
## StoryManager — Chapter sequencing, dialogue availability, and objective tracking.
##
## Works alongside GameManager (which handles flags, save/load, state).
## StoryManager adds the layer of "what content is available when."

signal chapter_started(chapter_num: int)
signal chapter_completed(chapter_num: int)
signal dialogue_unlocked(dialogue_id: String)
signal objective_updated(objective_id: String, status: String)

## Chapter definitions: title, required story dialogues, optional dialogues
const CHAPTER_SEQUENCE: Dictionary = {
	0: {
		"title": "Floors, Not Thrones",
		"story_dialogues": ["act1_prologue_boarding"],
		"optional_dialogues": [],
		"combat": "",
	},
	1: {
		"title": "Cinder Hours",
		"story_dialogues": ["act1_elia_rescue"],
		"optional_dialogues": [],
		"combat": "act1_tutorial",
	},
	2: {
		"title": "The Girl With the Shard",
		"story_dialogues": ["act1_naming_scene"],
		"optional_dialogues": [],
		"combat": "",
	},
	3: {
		"title": "First Watch",
		"story_dialogues": ["act1_first_watch"],
		"optional_dialogues": ["act1_ai_citizens_intro"],
		"combat": "",
	},
	4: {
		"title": "Finding Your Place",
		"story_dialogues": [],
		"optional_dialogues": [
			"act1_bonding_vesper", "act1_bonding_nyx", "act1_bonding_jalen",
			"act1_bonding_rho", "act1_bonding_elisira",
		],
		"combat": "",
	},
	5: {
		"title": "Bonds Forged",
		"story_dialogues": [],
		"optional_dialogues": [
			"act1_bonding_vesper", "act1_bonding_nyx", "act1_bonding_jalen",
			"act1_bonding_rho", "act1_bonding_elisira",
		],
		"combat": "",
	},
	6: {
		"title": "Secrets Below Deck",
		"story_dialogues": ["act1_crew_meal", "act1_forbidden_citizens"],
		"optional_dialogues": [],
		"combat": "",
	},
	7: {
		"title": "Becoming",
		"story_dialogues": ["act1_souffle_becoming", "act1_bee_manifestation"],
		"optional_dialogues": ["act1_shard_whispers"],
		"combat": "",
	},
	8: {
		"title": "The Reckoning",
		"story_dialogues": ["act1_corporate_conspiracy", "act1_trust_breaking_point"],
		"optional_dialogues": ["act1_mentor_contact"],
		"combat": "",
	},
	9: {
		"title": "Gathering Storm",
		"story_dialogues": [],
		"optional_dialogues": [
			"act1_deep_vesper", "act1_deep_nyx", "act1_deep_rho",
		],
		"combat": "act1_raider_ambush",
	},
	10: {
		"title": "The Heist",
		"story_dialogues": ["act1_party_split_briefing", "act1_climax_setup"],
		"optional_dialogues": [],
		"combat": "act1_boss_warlord",
	},
}

## Dialogue trigger requirements (flags that must be set before dialogue is available)
const DIALOGUE_REQUIREMENTS: Dictionary = {
	# Flag-only requirements (Array format)
	"act1_first_watch": ["has_lagrange_name"],
	"act1_ai_citizens_intro": ["completed_first_watch"],
	"act1_forbidden_citizens": ["ai_citizens_introduced"],
	"act1_bee_manifestation": ["has_lagrange_name"],
	"act1_corporate_conspiracy": {"flags": ["bee_revealed"]},
	"act1_mentor_contact": [],
	# Relationship-gated bonding dialogues (Dictionary format)
	"act1_bonding_vesper": {"relationship": {"vesper": "acquaintance"}},
	"act1_bonding_nyx": {"relationship": {"nyx": "acquaintance"}},
	"act1_bonding_jalen": {"relationship": {"jalen": "acquaintance"}},
	"act1_bonding_rho": {"relationship": {"rho": "acquaintance"}},
	"act1_bonding_elisira": {"relationship": {"elisira": "acquaintance"}},
	# Deep bonding requires TRUSTED tier
	"act1_deep_vesper": {"relationship": {"vesper": "trusted"}},
	"act1_deep_nyx": {"relationship": {"nyx": "trusted"}},
	"act1_deep_rho": {"relationship": {"rho": "trusted"}},
}

## Tracks which dialogues have been played this playthrough
var played_dialogues: Array[String] = []

## Active objectives
var active_objectives: Dictionary = {}
var completed_objectives: Array[String] = []


func _ready() -> void:
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)


func get_chapter_data(chapter_num: int) -> Dictionary:
	return CHAPTER_SEQUENCE.get(chapter_num, {})


func get_chapter_title(chapter_num: int) -> String:
	var data := get_chapter_data(chapter_num)
	return data.get("title", "Chapter %d" % chapter_num)


func start_chapter(chapter_num: int) -> void:
	GameManager.current_chapter = chapter_num
	chapter_started.emit(chapter_num)
	_unlock_chapter_dialogues(chapter_num)


func complete_chapter(chapter_num: int) -> void:
	GameManager.set_flag("chapter_%d_complete" % chapter_num)
	chapter_completed.emit(chapter_num)


func mark_dialogue_played(dialogue_id: String) -> void:
	if dialogue_id not in played_dialogues:
		played_dialogues.append(dialogue_id)


func has_played_dialogue(dialogue_id: String) -> bool:
	return dialogue_id in played_dialogues


func is_dialogue_available(dialogue_id: String) -> bool:
	var reqs = DIALOGUE_REQUIREMENTS.get(dialogue_id, {})

	# Handle old format: Array of flag names
	if reqs is Array:
		for flag in reqs:
			if not GameManager.has_flag(flag):
				return false
		return true

	# Handle new format: Dictionary with flags and/or relationships
	if reqs is Dictionary:
		for flag in reqs.get("flags", []):
			if not GameManager.has_flag(flag):
				return false
		for char_id in reqs.get("relationship", {}):
			var required_tier_name: String = reqs["relationship"][char_id]
			var required_tier: RelationshipManager.Tier
			match required_tier_name:
				"acquaintance": required_tier = RelationshipManager.Tier.ACQUAINTANCE
				"trusted": required_tier = RelationshipManager.Tier.TRUSTED
				"close": required_tier = RelationshipManager.Tier.CLOSE
				"bonded": required_tier = RelationshipManager.Tier.BONDED
				_: required_tier = RelationshipManager.Tier.STRANGER
			if not RelationshipManager.is_at_least(char_id, required_tier):
				return false
		return true

	return true


func get_available_story_dialogues(chapter_num: int) -> Array:
	var data := get_chapter_data(chapter_num)
	var available: Array = []
	for d_id in data.get("story_dialogues", []):
		if not has_played_dialogue(d_id) and is_dialogue_available(d_id):
			available.append(d_id)
	return available


func get_available_optional_dialogues(chapter_num: int) -> Array:
	var data := get_chapter_data(chapter_num)
	var available: Array = []
	for d_id in data.get("optional_dialogues", []):
		if not has_played_dialogue(d_id) and is_dialogue_available(d_id):
			available.append(d_id)
	return available


func get_chapter_combat(chapter_num: int) -> String:
	var data := get_chapter_data(chapter_num)
	return data.get("combat", "")


func is_chapter_story_complete(chapter_num: int) -> bool:
	var data := get_chapter_data(chapter_num)
	for d_id in data.get("story_dialogues", []):
		if not has_played_dialogue(d_id):
			return false
	return true


func can_advance_chapter() -> bool:
	return is_chapter_story_complete(GameManager.current_chapter)


## Returns the required relationship tier for a dialogue, or 0 if none.
func get_dialogue_required_tier(dialogue_id: String) -> int:
	# Deep bonding dialogues require TRUSTED (tier 2)
	if dialogue_id.begins_with("act1_deep_"):
		return 2
	return 0


## Returns the character ID associated with a dialogue, or empty string.
func get_dialogue_character(dialogue_id: String) -> String:
	if "vesper" in dialogue_id:
		return "vesper"
	if "nyx" in dialogue_id:
		return "nyx"
	if "rho" in dialogue_id:
		return "rho"
	if "jalen" in dialogue_id:
		return "jalen"
	if "elisira" in dialogue_id:
		return "elisira"
	if "elia" in dialogue_id:
		return "elia"
	return ""


## Objectives
func set_objective(objective_id: String, description: String) -> void:
	active_objectives[objective_id] = description
	objective_updated.emit(objective_id, "active")


func complete_objective(objective_id: String) -> void:
	active_objectives.erase(objective_id)
	if objective_id not in completed_objectives:
		completed_objectives.append(objective_id)
	objective_updated.emit(objective_id, "completed")


## Save/Load support
func serialize() -> Dictionary:
	return {
		"played_dialogues": played_dialogues,
		"active_objectives": active_objectives,
		"completed_objectives": completed_objectives,
	}


func deserialize(data: Dictionary) -> void:
	played_dialogues.assign(data.get("played_dialogues", []))
	active_objectives = data.get("active_objectives", {})
	completed_objectives.assign(data.get("completed_objectives", []))


## Internal
func _unlock_chapter_dialogues(chapter_num: int) -> void:
	var data := get_chapter_data(chapter_num)
	for d_id in data.get("story_dialogues", []):
		if is_dialogue_available(d_id):
			dialogue_unlocked.emit(d_id)
	for d_id in data.get("optional_dialogues", []):
		if is_dialogue_available(d_id):
			dialogue_unlocked.emit(d_id)


func _on_dialogue_ended(dialogue_id: String) -> void:
	mark_dialogue_played(dialogue_id)

	# Apply node-level set_flag from the dialogue (already handled by DialogueManager)
	# Just check if chapter story is now complete
	if can_advance_chapter():
		var combat_id := get_chapter_combat(GameManager.current_chapter)
		if combat_id.is_empty() or GameManager.is_encounter_cleared(combat_id):
			# Auto-complete chapter if no combat needed or combat already done
			pass  # ChapterFlow handles advancement
