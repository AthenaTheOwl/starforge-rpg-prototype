extends GutTest

## Integration test for dialogue content validation
## Validates lore consistency, AI citizen presence, and formatting across all dialogue files

const DIALOGUE_DIR = "res://data/dialogue/"
const AI_CITIZENS = ["Waffle.bat", "Bubbles", "Cinnamon", "Souffle"]
const VALID_REPUTATION_CHARACTERS = [
	"avyanna", "elia", "elisira", "vesper", "jalen", "nyx", "rho",
	"waffle", "waffle.bat", "bubbles", "cinnamon", "souffle", "qc-7",
	"bee", "crew_trust", "guild",
	"Avyanna", "Elia", "Elisira", "Vesper", "Jalen", "Nyx", "Rho",
	"Waffle.bat", "Bubbles", "Cinnamon", "Souffle", "QC-7", "Bee",
]
const FORBIDDEN_RECRUITMENT_PHRASES = [
	"join our crew",
	"offering you a position",
	"will you work with us",
	"offer you a position",
	"welcome to the crew"
]

var all_dialogue_files: Array = []


func before_each():
	all_dialogue_files = _get_all_json_files(DIALOGUE_DIR)


func test_ai_citizen_minimum_presence():
	var ai_citizen_count = _count_ai_citizen_nodes()
	assert_gte(
		ai_citizen_count,
		30,
		"AI citizens (Waffle.bat, Bubbles, Cinnamon, Souffle) should appear in at least 30 nodes across all dialogue files"
	)


func test_ai_citizen_variety():
	var appearances = _count_ai_appearances_by_character()

	assert_true(
		appearances.has("Waffle.bat") and appearances["Waffle.bat"] > 0,
		"Waffle.bat should appear as speaker in at least one dialogue node"
	)
	assert_true(
		appearances.has("Bubbles") and appearances["Bubbles"] > 0,
		"Bubbles should appear as speaker in at least one dialogue node"
	)
	assert_true(
		appearances.has("Cinnamon") and appearances["Cinnamon"] > 0,
		"Cinnamon should appear as speaker in at least one dialogue node"
	)


func test_forbidden_crew_recruitment_language():
	var bonding_files = _get_bonding_files()
	var violations: Array = []

	for file_path in bonding_files:
		var dialogue = _load_dialogue(file_path)
		if dialogue == null:
			continue

		if not dialogue.has("nodes"):
			continue

		for node_id in dialogue["nodes"]:
			var node = dialogue["nodes"][node_id]
			if not node.has("text"):
				continue

			var text = node["text"]
			for phrase in FORBIDDEN_RECRUITMENT_PHRASES:
				if _contains_phrase(text, phrase):
					violations.append({
						"file": file_path,
						"node": node_id,
						"phrase": phrase,
						"text": text
					})

	assert_eq(
		violations.size(),
		0,
		"Bonding files should not contain recruitment language. Found violations: " + str(violations)
	)


func test_no_recruitment_flags_in_bonding_files():
	var bonding_files = _get_bonding_files()
	var violations: Array = []

	for file_path in bonding_files:
		var dialogue = _load_dialogue(file_path)
		if dialogue == null:
			continue

		if not dialogue.has("nodes"):
			continue

		for node_id in dialogue["nodes"]:
			var node = dialogue["nodes"][node_id]

			# Node-level set_flag
			if node.has("set_flag"):
				var set_flag = node["set_flag"]
				if typeof(set_flag) == TYPE_STRING and set_flag.begins_with("recruited_"):
					violations.append({
						"file": file_path,
						"node": node_id,
						"flag": set_flag
					})

			# Choice-level set_flag
			if node.has("choices"):
				for choice in node["choices"]:
					if choice.has("set_flag"):
						var cflag = choice["set_flag"]
						if typeof(cflag) == TYPE_STRING and cflag.begins_with("recruited_"):
							violations.append({
								"file": file_path,
								"node": node_id,
								"flag": cflag
							})

	assert_eq(
		violations.size(),
		0,
		"Bonding files should not set 'recruited_' flags. Found violations: " + str(violations)
	)


func test_bbcode_formatting_consistency():
	var mismatches: Array = []

	for file_path in all_dialogue_files:
		var dialogue = _load_dialogue(file_path)
		if dialogue == null:
			continue

		if not dialogue.has("nodes"):
			continue

		for node_id in dialogue["nodes"]:
			var node = dialogue["nodes"][node_id]
			if not node.has("text"):
				continue

			var text = node["text"]
			var open_count = text.count("[i]")
			var close_count = text.count("[/i]")

			if open_count != close_count:
				mismatches.append({
					"file": file_path,
					"node": node_id,
					"open_tags": open_count,
					"close_tags": close_count,
					"text": text
				})

	assert_eq(
		mismatches.size(),
		0,
		"All [i] tags must have matching [/i] tags. Found mismatches: " + str(mismatches)
	)


func test_reputation_uses_valid_characters():
	var invalid_uses: Array = []

	for file_path in all_dialogue_files:
		var dialogue = _load_dialogue(file_path)
		if dialogue == null:
			continue

		if not dialogue.has("nodes"):
			continue

		for node_id in dialogue["nodes"]:
			var node = dialogue["nodes"][node_id]
			if not node.has("reputation"):
				continue

			var reputation = node["reputation"]
			if typeof(reputation) != TYPE_DICTIONARY:
				continue

			for character_key in reputation.keys():
				if not character_key in VALID_REPUTATION_CHARACTERS:
					invalid_uses.append({
						"file": file_path,
						"node": node_id,
						"invalid_character": character_key,
						"value": reputation[character_key]
					})

	assert_eq(
		invalid_uses.size(),
		0,
		"All reputation keys must be valid character names. Found invalid: " + str(invalid_uses)
	)


func test_every_flag_is_echoed():
	## Every set_flag in a dialogue should be referenced by at least one other dialogue.
	var all_flags_set: Array = []
	var all_flags_referenced: Array = []
	# Internal/system flags that don't need dialogue echoes
	var system_flag_prefixes = [
		"chapter_", "act_", "recruited_", "bonded_", "_pending",
		"met_", "first_watch_visited_", "dinner_watched_",
		"deep_", "witnessed_", "tutorial_",
	]

	for file_path in all_dialogue_files:
		var data = _load_dialogue(file_path)
		if not data.has("nodes"):
			continue
		for node_id in data["nodes"]:
			var node = data["nodes"][node_id]
			# Flags set
			if node.has("set_flag"):
				all_flags_set.append(node["set_flag"])
			if node.has("choices"):
				for choice in node["choices"]:
					if choice.has("set_flag"):
						all_flags_set.append(choice["set_flag"])

			# Flags referenced in text_variants
			var text_variants: Dictionary = node.get("text_variants", {})
			for key in text_variants:
				if key != "default":
					all_flags_referenced.append(key)

			# Flags referenced in conditions
			if node.has("conditions"):
				var conditions = node["conditions"]
				if conditions.has("flags"):
					for flag in conditions["flags"]:
						all_flags_referenced.append(flag)

	for flag in all_flags_set:
		var is_system := false
		for prefix in system_flag_prefixes:
			if flag.begins_with(prefix):
				is_system = true
				break
		if is_system:
			continue
		assert_true(
			flag in all_flags_referenced,
			"Flag '%s' is set but never referenced in any dialogue text_variants" % flag
		)


func test_minimum_choices_per_large_dialogue():
	## Dialogues with 50+ nodes should have at least 3 choice points.
	for file_path in all_dialogue_files:
		var data = _load_dialogue(file_path)
		if not data.has("nodes"):
			continue
		var node_count = data["nodes"].size()
		if node_count >= 50:
			var choice_count = 0
			for node_id in data["nodes"]:
				var node = data["nodes"][node_id]
				if node.has("choices") and node["choices"].size() > 0:
					choice_count += 1
			assert_gte(
				choice_count, 3,
				"File %s has %d nodes but only %d choices (minimum 3)" %
				[file_path.get_file(), node_count, choice_count]
			)


func test_relationship_affinity_coverage():
	## All crew characters should gain affinity in at least 2 dialogues.
	var affinity_sources: Dictionary = {}
	for file_path in all_dialogue_files:
		var data = _load_dialogue(file_path)
		if not data.has("nodes"):
			continue
		for node_id in data["nodes"]:
			var node = data["nodes"][node_id]
			var rep: Dictionary = node.get("reputation", {})
			for char_id in rep:
				var lower_id = char_id.to_lower()
				if lower_id not in affinity_sources:
					affinity_sources[lower_id] = []
				if file_path not in affinity_sources[lower_id]:
					affinity_sources[lower_id].append(file_path)
			# Also check choices
			if node.has("choices"):
				for choice in node["choices"]:
					var crep: Dictionary = choice.get("reputation", {})
					for char_id in crep:
						var lower_id = char_id.to_lower()
						if lower_id not in affinity_sources:
							affinity_sources[lower_id] = []
						if file_path not in affinity_sources[lower_id]:
							affinity_sources[lower_id].append(file_path)

	for char_id in ["vesper", "nyx", "jalen", "rho", "elisira", "elia"]:
		assert_true(
			char_id in affinity_sources,
			"Character '%s' has no reputation gains in any dialogue" % char_id
		)
		if char_id in affinity_sources:
			assert_gte(
				affinity_sources[char_id].size(), 2,
				"Character '%s' only gains rep in %d dialogues (minimum 2)" %
				[char_id, affinity_sources[char_id].size()]
			)


## Helper: Get all JSON files in a directory
func _get_all_json_files(dir_path: String) -> Array:
	var files: Array = []
	var dir = DirAccess.open(dir_path)

	if dir == null:
		push_warning("Failed to open dialogue directory: " + dir_path)
		return files

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			files.append(dir_path.path_join(file_name))
		file_name = dir.get_next()

	dir.list_dir_end()
	return files


## Helper: Load and parse a dialogue JSON file
func _load_dialogue(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Failed to open dialogue file: " + path)
		return {}

	var content = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(content)

	if parse_result != OK:
		push_warning("Failed to parse JSON in file: " + path + " Error: " + json.get_error_message())
		return {}

	var data = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("JSON root is not a dictionary in file: " + path)
		return {}

	return data


## Helper: Count total nodes where speaker is an AI citizen
func _count_ai_citizen_nodes() -> int:
	var count = 0

	for file_path in all_dialogue_files:
		var dialogue = _load_dialogue(file_path)
		if dialogue == null or not dialogue.has("nodes"):
			continue

		for node_id in dialogue["nodes"]:
			var node = dialogue["nodes"][node_id]
			if node.has("speaker") and node["speaker"] in AI_CITIZENS:
				count += 1

	return count


## Helper: Count appearances by individual AI citizen character
func _count_ai_appearances_by_character() -> Dictionary:
	var appearances: Dictionary = {}

	for ai_name in AI_CITIZENS:
		appearances[ai_name] = 0

	for file_path in all_dialogue_files:
		var dialogue = _load_dialogue(file_path)
		if dialogue == null or not dialogue.has("nodes"):
			continue

		for node_id in dialogue["nodes"]:
			var node = dialogue["nodes"][node_id]
			if node.has("speaker") and node["speaker"] in AI_CITIZENS:
				appearances[node["speaker"]] += 1

	return appearances


## Helper: Get all dialogue files with "bonding" in the filename
func _get_bonding_files() -> Array:
	var bonding_files: Array = []

	for file_path in all_dialogue_files:
		var file_name = file_path.get_file().to_lower()
		if "bonding" in file_name:
			bonding_files.append(file_path)

	return bonding_files


## Helper: Case-insensitive substring check
func _contains_phrase(text: String, phrase: String) -> bool:
	return text.to_lower().contains(phrase.to_lower())
