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
	"Lead Pirate",
	# Canonical narration, first-contact aliases and deliberately unnamed mentor.
	"BEE", "Narration", "Soufflé", "Security Sergeant", "???"
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
							assert_true(threshold >= 1 and threshold <= 20,
								"Skill check threshold %d out of range (1-20; d20 + stat) in node '%s' of %s" %
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

## Follow both canonical formats, independently of runtime normalization.
func _node_refs(value: Variant) -> Array:
	var refs: Array = []
	if value is Dictionary:
		for key in ["next", "on_success", "on_failure", "success", "failure"]:
			if value.get(key) is String:
				refs.append(value[key])
		for key in ["choices", "variants", "check", "skill_check"]:
			if value.has(key):
				refs.append_array(_node_refs(value[key]))
	elif value is Array:
		for child in value:
			refs.append_array(_node_refs(child))
	return refs


func _get_all_next_refs(dialogue: Dictionary) -> Array:
	var refs: Array = []
	for node in dialogue.get("nodes", {}).values():
		refs.append_array(_node_refs(node))
	return refs


func _get_reachable_nodes(dialogue: Dictionary) -> Array:
	var reachable: Array = []
	var nodes: Dictionary = dialogue.get("nodes", {})
	var queue: Array = [dialogue.get("start_node", "")]
	while not queue.is_empty():
		var current: String = queue.pop_front()
		if current in reachable or current not in nodes:
			continue
		reachable.append(current)
		queue.append_array(_runtime_node_refs(nodes[current]))
	return reachable


func _check_outcomes(check: Dictionary) -> Array:
	return [check.get("on_success", check.get("success", "end")), check.get("on_failure", check.get("failure", "end"))]


func _runtime_node_refs(node: Dictionary) -> Array:
	# Standalone checks dispatch before any text/variant processing and ignore next.
	if node.get("type", "") == "skill_check" or node.has("skill_check"):
		var outcomes := _check_outcomes(node.get("check", node.get("skill_check", {})))
		return [node.get("on_success", outcomes[0]), node.get("on_failure", outcomes[1])]
	var refs := _runtime_display_refs(node)
	for variant in node.get("variants", []):
		var resolved := node.duplicate(true)
		resolved.merge(variant, true)
		refs.append_array(_runtime_display_refs(resolved))
	return refs


func _runtime_display_refs(node: Dictionary) -> Array:
	var choices: Array = node.get("choices", [])
	var refs: Array = []
	var always_available := false
	for choice in choices:
		var check: Dictionary = choice.get("skill_check", {})
		if check.has("on_success") or check.has("success") or check.has("on_failure") or check.has("failure"):
			refs.append_array(_check_outcomes(check))
		else:
			refs.append(choice.get("next", "end"))
		if not choice.has("requires_flag") and not choice.has("requires_reputation"):
			always_available = true
	if choices.is_empty() or not always_available:
		refs.append(node.get("next", "end"))
	return refs


func test_control_graph_ignores_unused_next_but_follows_display_hints():
	var fixture := {"start_node": "start", "nodes": {
		"start": {"choices": [{"next": "ghost", "skill_check": {"on_success": "passed", "on_failure": "failed"}}]},
		"passed": {"choices": [{"next": "hinted", "skill_check": {"skill": "empathy", "dc": 10}}]},
		"hinted": {"next": "end"}, "failed": {"next": "end"}, "ghost": {"next": "end"},
	}}
	var reached := _get_reachable_nodes(fixture)
	assert_false(reached.has("ghost"), "Inline check outcomes supersede a stale choice.next")
	assert_has(reached, "hinted", "Display-only metadata delegates to choice.next")
	assert_eq(reached.size(), 4)


func test_graph_walker_covers_check_formats_without_hiding_orphans():
	var fixture := {"start_node": "start", "nodes": {
		"start": {"type": "skill_check", "on_success": "passed", "on_failure": "failed"},
		"passed": {"choices": [{"skill_check": {"success": "legacy", "failure": "end"}}]},
		"failed": {"next": "end"}, "legacy": {"next": "end"}, "orphan": {"next": "end"},
	}}
	var reached := _get_reachable_nodes(fixture)
	assert_eq(reached.size(), 4)
	assert_has(reached, "legacy", "Legacy check outcomes are reachable")
	assert_false(reached.has("orphan"), "An unlinked authored node must still fail the gate")
	fixture["nodes"]["start"]["on_failure"] = "missing"
	assert_has(_get_all_next_refs(fixture), "missing", "Broken references remain visible to validation")


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
