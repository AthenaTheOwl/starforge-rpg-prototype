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
## Decisions and events whose only callback was an echo on a node every path
## reached with the flag already set, so the line could never vary with play.
## Those lines now test a choice that does vary, or were removed. The flags
## stay recorded for saves and later scenes.
const RECORDED_WITHOUT_CALLBACK = [
	"act1_team_briefing_complete", "ai_illegality_revealed", "asked_name_cost",
	"bee_communion", "briefing_elisira_corrected", "briefing_tactics_passed",
	"briefing_ward_insight", "completed_night_watch", "dinner_elisira_elia_insight",
	"dinner_nyx_opened_up", "elia_rescued", "knows_ai_illegal", "left_site_k9",
	"mentor_contacted", "mentor_rejected", "mentor_traced", "mentor_trusted",
	"mentor_warning_heard", "nyx_shared_writbound", "rho_combat_coordination",
	"rho_solidified", "souffle_citizen", "trust_crisis_resolved",
	"vesper_coping_seen", "vesper_guilt_understood",
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


func test_bond_commitments_autosave():
	## Committing to a bond is a major story beat; GameManager autosaves on it.
	var bond_flags: Array = []
	for file_path in _get_bonding_files():
		var dialogue = _load_dialogue(file_path)
		for node in dialogue.get("nodes", {}).values():
			for holder in [node] + node.get("choices", []):
				var flag = holder.get("set_flag", "")
				if typeof(flag) == TYPE_STRING and flag.ends_with("_bonded") and not (flag in bond_flags):
					bond_flags.append(flag)
	assert_eq(bond_flags.size(), 5, "Each of the five bonding scenes sets its bond flag: " + str(bond_flags))
	for flag in bond_flags:
		assert_true(GameManager._is_major_story_flag(flag), "%s should trigger an autosave" % flag)
	assert_true(GameManager._is_major_story_flag("bonded_with_nyx"), "Older bond flag names still count as major")


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
		"chapter_", "act_", "recruited_", "_pending",
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

			all_flags_referenced.append_array(_node_flag_readers(node))

	# Story gates and quest predicates are real consumers, even when they do not
	# produce literal dialogue text. Count only fields the runtime evaluates.
	for requirements in StoryManager.DIALOGUE_REQUIREMENTS.values():
		if requirements is Array:
			all_flags_referenced.append_array(requirements)
		elif requirements is Dictionary:
			all_flags_referenced.append_array(requirements.get("flags", []))
	for quest_path in _get_all_json_files("res://data/quests/"):
		for action in _load_dialogue(quest_path).get("actions", []):
			for key in ["requires_flag", "excludes_flag"]:
				if action.has(key):
					all_flags_referenced.append(action[key])

	for flag in RECORDED_WITHOUT_CALLBACK:
		assert_true(flag in all_flags_set, "Listed flag '%s' is no longer set; drop it from RECORDED_WITHOUT_CALLBACK" % flag)
		assert_false(flag in all_flags_referenced, "Listed flag '%s' now has a consumer; drop it from RECORDED_WITHOUT_CALLBACK" % flag)

	for flag in all_flags_set:
		var is_system := false
		for prefix in system_flag_prefixes:
			if flag.begins_with(prefix):
				is_system = true
				break
		if is_system or flag in RECORDED_WITHOUT_CALLBACK:
			continue
		assert_true(
			flag in all_flags_referenced,
			"Flag '%s' is set but has no executable text, story-gate or quest consumer" % flag
		)


func _condition_flags(variant: Dictionary) -> Array:
	var condition: Dictionary = variant.get("conditions", variant.get("condition", {}))
	var flags: Array = condition.get("flags", []).duplicate()
	for key in ["flag", "not_flag"]:
		if condition.has(key):
			flags.append(condition[key])
	return flags


func _node_flag_readers(node: Dictionary) -> Array:
	var flags: Array = []
	var text_variants: Variant = node.get("text_variants", {})
	if text_variants is Dictionary:
		for key in text_variants:
			if key != "default": flags.append(key)
	elif text_variants is Array:
		for variant in text_variants: flags.append_array(_condition_flags(variant))
	for variant in node.get("variants", []): flags.append_array(_condition_flags(variant))
	for choice in node.get("choices", []):
		if choice.has("requires_flag"): flags.append(choice["requires_flag"])
	for echo in node.get("echoes", []): flags.append(echo["flag"])
	return flags


func test_authored_echoes_render_in_reachable_states():
	## Walk each scene the way DialogueManager runs it and render every echo node
	## in each flag state the walk actually reaches there, instead of states play
	## cannot produce (a false flag, or rival choices set at once). Flags written
	## by other scenes enter either unset or set; tools/validate_project.py checks
	## across the whole act that each echo can be reached both ways.
	var original_flags := GameManager.story_flags.duplicate(true)
	var observed := {}
	var mismatches: Array = []
	for file_path in all_dialogue_files:
		var data := _load_dialogue(file_path)
		var nodes: Dictionary = data.get("nodes", {})
		var written := _flags_written(nodes)
		var entries: Array = [{}]
		for node in nodes.values():
			for echo in node.get("echoes", []):
				if not written.has(echo["flag"]):
					entries.append({echo["flag"]: true})
		for entry in entries:
			for reached in _reachable_echo_states(data, entry):
				var node_id: String = reached[0]
				var node: Dictionary = reached[2]
				GameManager.story_flags = reached[1]
				var text := DialogueManager._get_node_text(node)
				if DialogueManager._get_node_text(node) != text:
					mismatches.append("%s:%s changes on a repeated render" % [file_path.get_file(), node_id])
				for echo in node["echoes"]:
					var chosen := bool(GameManager.get_flag(echo["flag"], false))
					var key := "%s:%s:%s" % [file_path.get_file(), node_id, echo["flag"]]
					if not observed.has(key):
						observed[key] = {}
					observed[key][chosen] = true
					if text.count(echo["text"]) != (1 if chosen else 0):
						mismatches.append("%s renders %d times with the flag %s" % [key, text.count(echo["text"]), "set" if chosen else "unset"])
	GameManager.story_flags = original_flags
	assert_gt(observed.size(), 0, "Reachable-state checks must execute authored echo entries")
	assert_eq(mismatches, [], "Each echo renders once exactly when its flag is set in a reached state")
	var constant: Array = []
	for key in observed:
		if observed[key].size() != 2:
			constant.append(key)
	assert_eq(constant, [], "Each echo must be reached with its flag both set and unset")


func _flags_written(nodes: Dictionary) -> Dictionary:
	var written := {}
	for node in nodes.values():
		for holder in [node] + node.get("choices", []) + node.get("variants", []):
			if holder.has("set_flag"):
				written[holder["set_flag"]] = true
	return written


## Mirror DialogueManager's dispatch (checks roll either way, first matching
## variant, text before node effects, available choices or next) and return
## [node_id, flags, resolved node] for every echo node display reached from
## `entry`. Only flags the scene reads are tracked, so states stay distinct.
func _reachable_echo_states(data: Dictionary, entry: Dictionary) -> Array:
	var nodes: Dictionary = data.get("nodes", {})
	var tracked := entry.duplicate()
	for node in nodes.values():
		for echo in node.get("echoes", []):
			tracked[echo["flag"]] = true
		for variant in node.get("variants", []):
			for flag in _condition_flags(variant):
				tracked[flag] = true
		for choice in node.get("choices", []):
			if choice.has("requires_flag"):
				tracked[choice["requires_flag"]] = true
	var reached: Array = []
	var seen := {}
	var pending: Array = [[data.get("start_node", "start"), entry.duplicate()]]
	while not pending.is_empty():
		var item: Array = pending.pop_back()
		var node_id: String = item[0]
		var flags: Dictionary = item[1]
		var names := flags.keys()
		names.sort()
		var key := node_id + "|" + ",".join(names)
		if seen.has(key) or not nodes.has(node_id):
			continue
		seen[key] = true
		var node: Dictionary = nodes[node_id]
		if node.get("type", "") == "skill_check" or node.has("skill_check"):
			var check := DialogueManager._normalize_skill_check(node.get("check", node.get("skill_check", {})))
			for outcome in ["on_success", "on_failure"]:
				pending.append([node.get(outcome, check.get(outcome, "end")), flags])
			continue
		GameManager.story_flags = flags.duplicate()
		var resolved := node.duplicate(true)
		for variant in node.get("variants", []):
			if DialogueManager._check_variant_conditions(variant):
				for field in variant:
					if field != "conditions":
						resolved[field] = variant[field]
				break
		if resolved.has("echoes"):
			reached.append([node_id, flags.duplicate(), resolved])
		var after := _with_flag(flags, resolved, tracked)
		GameManager.story_flags = after.duplicate()
		var choices := DialogueManager._get_available_choices(resolved)
		if choices.is_empty():
			pending.append([resolved.get("next", "end"), after])
		for choice in choices:
			var chosen := _with_flag(after, choice, tracked)
			if choice.has("skill_check") and DialogueManager._skill_check_has_outcomes(choice["skill_check"]):
				var check := DialogueManager._normalize_skill_check(choice["skill_check"])
				for outcome in ["on_success", "on_failure"]:
					pending.append([check.get(outcome, "end"), chosen])
			else:
				pending.append([choice.get("next", "end"), chosen])
	return reached


func _with_flag(flags: Dictionary, holder: Dictionary, tracked: Dictionary) -> Dictionary:
	var flag = holder.get("set_flag")
	if typeof(flag) != TYPE_STRING or not tracked.has(flag) or not holder.get("flag_value", true):
		return flags
	var result := flags.duplicate()
	result[flag] = true
	return result


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
			# Deliberate design choice, not a gap: Bee's first manifestation is a
			# curated first-contact scene kept linear between two decision points.
			# Every other large scene needs 3.
			var minimum := 2 if file_path.get_file() == "act1_bee_manifestation.json" else 3
			assert_gte(choice_count, minimum,
				"File %s has %d nodes but only %d choice points (minimum %d)" %
				[file_path.get_file(), node_count, choice_count, minimum])


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
