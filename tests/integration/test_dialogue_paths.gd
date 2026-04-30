extends GutTest

## Integration test for dialogue path validation
## Validates all JSON dialogue files in res://data/dialogue/

const DIALOGUE_DIR = "res://data/dialogue/"
const KNOWN_CHARACTERS = [
	"Avyanna",
	"Elia",
	"Elisira",
	"Vesper",
	"Jalen",
	"Nyx",
	"Rho",
	"Waffle.bat",
	"Bubbles",
	"Cinnamon",
	"Souffle",
	"QC-7",
	"SYSTEM",
	"ALL",
	"Lead Pirate"
]
const FORBIDDEN_FLAGS = [
	"recruited_vesper",
	"recruited_nyx",
	"recruited_jalen",
	"recruited_rho",
	"recruited_elisira"
]

## Test that all dialogue files are valid JSON with required structure
func test_all_dialogue_files_valid():
	var dialogue_files = _get_all_json_files(DIALOGUE_DIR)
	assert_gt(dialogue_files.size(), 0, "Should have at least one dialogue file")

	for file_path in dialogue_files:
		var dialogue = _load_dialogue(file_path)
		assert_not_null(dialogue, "Failed to load dialogue: %s" % file_path)
		assert_true(dialogue.has("start_node"), "Missing start_node in %s" % file_path)
		assert_true(dialogue.has("nodes"), "Missing nodes in %s" % file_path)
		assert_true(dialogue["nodes"] is Dictionary, "nodes should be Dictionary in %s" % file_path)
		assert_gt(dialogue["nodes"].size(), 0, "Should have at least one node in %s" % file_path)

## Test that all next references point to valid nodes
func test_no_broken_references():
	var dialogue_files = _get_all_json_files(DIALOGUE_DIR)

	for file_path in dialogue_files:
		var dialogue = _load_dialogue(file_path)
		if dialogue == null:
			continue

		var all_refs = _get_all_next_refs(dialogue)
		var valid_nodes = dialogue["nodes"].keys()

		for ref in all_refs:
			if ref == "end":
				continue
			assert_true(valid_nodes.has(ref),
				"Broken reference '%s' in %s" % [ref, file_path])

## Test that all nodes are reachable from start_node
func test_no_orphaned_nodes():
	var dialogue_files = _get_all_json_files(DIALOGUE_DIR)

	for file_path in dialogue_files:
		var dialogue = _load_dialogue(file_path)
		if dialogue == null:
			continue

		var reachable = _get_reachable_nodes(dialogue)
		var all_nodes = dialogue["nodes"].keys()

		for node_id in all_nodes:
			assert_true(reachable.has(node_id),
				"Orphaned node '%s' in %s" % [node_id, file_path])

## Test that speaker names are from the known character set
func test_character_name_consistency():
	var dialogue_files = _get_all_json_files(DIALOGUE_DIR)

	for file_path in dialogue_files:
		var dialogue = _load_dialogue(file_path)
		if dialogue == null:
			continue

		for node_id in dialogue["nodes"]:
			var node = dialogue["nodes"][node_id]
			if node.has("speaker"):
				var speaker = node["speaker"]
				assert_true(KNOWN_CHARACTERS.has(speaker),
					"Unknown speaker '%s' in node '%s' of %s" % [speaker, node_id, file_path])

## Test that existing crew members don't have recruitment flags
func test_no_recruitment_flags_for_existing_crew():
	var dialogue_files = _get_all_json_files(DIALOGUE_DIR)

	for file_path in dialogue_files:
		var dialogue = _load_dialogue(file_path)
		if dialogue == null:
			continue

		var all_flags = _collect_all_flags(dialogue)

		for flag in all_flags:
			assert_false(FORBIDDEN_FLAGS.has(flag),
				"Forbidden recruitment flag '%s' found in %s" % [flag, file_path])

## Test that skill check thresholds are reasonable
func test_skill_check_thresholds_reasonable():
	var dialogue_files = _get_all_json_files(DIALOGUE_DIR)

	for file_path in dialogue_files:
		var dialogue = _load_dialogue(file_path)
		if dialogue == null:
			continue

		for node_id in dialogue["nodes"]:
			var node = dialogue["nodes"][node_id]

			if node.has("choices"):
				for choice in node["choices"]:
					if choice.has("skill_check"):
						var skill_check = choice["skill_check"]
						if skill_check.has("threshold"):
							var threshold = skill_check["threshold"]
							assert_true(threshold >= 1 and threshold <= 8,
								"Skill check threshold %d out of range (1-8) in node '%s' of %s" %
								[threshold, node_id, file_path])

## Helper: Get all JSON files in a directory
func _get_all_json_files(dir_path: String) -> Array:
	var files = []
	var dir = DirAccess.open(dir_path)

	if dir == null:
		push_warning("Could not open directory: %s" % dir_path)
		return files

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			files.append(dir_path.path_join(file_name))
		file_name = dir.get_next()

	dir.list_dir_end()
	return files

## Helper: Load and parse dialogue JSON
func _load_dialogue(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)

	if file == null:
		push_warning("Could not open file: %s" % path)
		return {}

	var content = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(content)

	if error != OK:
		push_warning("JSON parse error in %s: %s" % [path, json.get_error_message()])
		return {}

	var result = json.data
	if result is Dictionary:
		return result
	else:
		push_warning("JSON root is not a Dictionary in %s" % path)
		return {}

## Helper: Collect all next references in dialogue
func _get_all_next_refs(dialogue: Dictionary) -> Array:
	var refs = []

	if not dialogue.has("nodes"):
		return refs

	for node_id in dialogue["nodes"]:
		var node = dialogue["nodes"][node_id]

		# Direct next field
		if node.has("next"):
			if not refs.has(node["next"]):
				refs.append(node["next"])

		# Choices
		if node.has("choices"):
			for choice in node["choices"]:
				if choice.has("next"):
					if not refs.has(choice["next"]):
						refs.append(choice["next"])

				# Skill check outcomes
				if choice.has("skill_check"):
					var skill_check = choice["skill_check"]
					if skill_check.has("on_success"):
						if not refs.has(skill_check["on_success"]):
							refs.append(skill_check["on_success"])
					if skill_check.has("on_failure"):
						if not refs.has(skill_check["on_failure"]):
							refs.append(skill_check["on_failure"])

		# Variants (conditional branching)
		if node.has("variants"):
			for variant in node["variants"]:
				if variant.has("next"):
					if not refs.has(variant["next"]):
						refs.append(variant["next"])

		# Node-level check (alternate skill check format)
		if node.has("check"):
			var check = node["check"]
			if check.has("on_success"):
				if not refs.has(check["on_success"]):
					refs.append(check["on_success"])
			if check.has("on_failure"):
				if not refs.has(check["on_failure"]):
					refs.append(check["on_failure"])

	return refs

## Helper: Get all reachable nodes from start_node using BFS
func _get_reachable_nodes(dialogue: Dictionary) -> Array:
	var reachable = []

	if not dialogue.has("start_node") or not dialogue.has("nodes"):
		return reachable

	var start = dialogue["start_node"]
	var queue = [start]
	var visited = {}

	while queue.size() > 0:
		var current = queue.pop_front()

		if visited.has(current):
			continue

		if current == "end":
			continue

		if not dialogue["nodes"].has(current):
			continue

		visited[current] = true
		reachable.append(current)

		var node = dialogue["nodes"][current]

		# Direct next
		if node.has("next"):
			if not visited.has(node["next"]):
				queue.append(node["next"])

		# Choices
		if node.has("choices"):
			for choice in node["choices"]:
				if choice.has("next"):
					if not visited.has(choice["next"]):
						queue.append(choice["next"])

				# Skill check outcomes
				if choice.has("skill_check"):
					var skill_check = choice["skill_check"]
					if skill_check.has("on_success"):
						if not visited.has(skill_check["on_success"]):
							queue.append(skill_check["on_success"])
					if skill_check.has("on_failure"):
						if not visited.has(skill_check["on_failure"]):
							queue.append(skill_check["on_failure"])

		# Variants (conditional branching)
		if node.has("variants"):
			for variant in node["variants"]:
				if variant.has("next"):
					if not visited.has(variant["next"]):
						queue.append(variant["next"])

		# Node-level check (alternate skill check format)
		if node.has("check"):
			var check = node["check"]
			if check.has("on_success"):
				if not visited.has(check["on_success"]):
					queue.append(check["on_success"])
			if check.has("on_failure"):
				if not visited.has(check["on_failure"]):
					queue.append(check["on_failure"])

	return reachable

## Helper: Collect all set_flag values in dialogue
func _collect_all_flags(dialogue: Dictionary) -> Array:
	var flags = []

	if not dialogue.has("nodes"):
		return flags

	for node_id in dialogue["nodes"]:
		var node = dialogue["nodes"][node_id]

		# Node-level set_flag
		if node.has("set_flag"):
			if not flags.has(node["set_flag"]):
				flags.append(node["set_flag"])

		# Choice-level set_flag
		if node.has("choices"):
			for choice in node["choices"]:
				if choice.has("set_flag"):
					if not flags.has(choice["set_flag"]):
						flags.append(choice["set_flag"])

	return flags
