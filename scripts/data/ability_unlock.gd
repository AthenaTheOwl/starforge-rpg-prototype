class_name AbilityUnlock
extends RefCounted
## Stub for Task 4.2: Ability Unlocks at Level-Up
##
## This class will provide 2 ability choices per level for each character.
## For now, returns placeholder data to enable the leveling system UI.


## Get available ability unlock options for a character at a given level.
## Returns an array of 2 dictionaries, each representing an ability choice.
func get_unlock_options(character_id: String, level: int) -> Array[Dictionary]:
	# Placeholder implementation for Task 4.2
	# Will be replaced with actual ability unlock logic
	var options: Array[Dictionary] = []

	# Generate 2 placeholder options
	options.append({
		"id": "placeholder_ability_1",
		"name": "Placeholder Ability A",
		"description": "This is a placeholder ability unlock for level %d." % level,
		"slot_type": "core",
		"level_required": level,
	})

	options.append({
		"id": "placeholder_ability_2",
		"name": "Placeholder Ability B",
		"description": "This is another placeholder ability unlock for level %d." % level,
		"slot_type": "utility",
		"level_required": level,
	})

	return options
