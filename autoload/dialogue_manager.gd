extends Node
## DialogueManager — Runs branching dialogue trees from JSON data.
##
## Dialogue format: JSON with nodes, each containing text, speaker, choices.
## Supports skill checks with roll-based resolution, conditional text variants,
## faction reputation gating, and dialogue history tracking.

enum CheckResult { CRITICAL_SUCCESS, SUCCESS, FAILURE, CRITICAL_FAILURE }

var current_dialogue_id: String = ""
var current_node_id: String = ""
var dialogue_data: Dictionary = {}
var is_active: bool = false
var dialogue_history: Array[Dictionary] = []

signal dialogue_started(dialogue_id: String)
signal node_displayed(node: Dictionary)
signal choices_presented(choices: Array)
signal dialogue_ended(dialogue_id: String)
signal skill_check_resolved(check: Dictionary, result: String)


func start_dialogue(dialogue_id: String) -> void:
	var data := _load_dialogue(dialogue_id)
	if data.is_empty():
		push_warning("Dialogue not found: %s" % dialogue_id)
		return
	dialogue_data = data
	current_dialogue_id = dialogue_id
	is_active = true
	dialogue_history.clear()
	current_node_id = data.get("start_node", "start")
	dialogue_started.emit(dialogue_id)
	_display_node(current_node_id)


func select_choice(choice_index: int) -> void:
	if not is_active:
		return
	var node: Dictionary = dialogue_data["nodes"].get(current_node_id, {})
	var choices: Array = _get_available_choices(node)
	if choice_index < 0 or choice_index >= choices.size():
		return
	var choice: Dictionary = choices[choice_index]

	# Apply effects
	if choice.has("set_flag"):
		GameManager.set_flag(choice["set_flag"], choice.get("flag_value", true))
	if choice.has("reputation"):
		for faction in choice["reputation"]:
			GameManager.modify_reputation(faction, choice["reputation"][faction])
		_process_reputation_affinity(choice["reputation"])

	# Handle skill check on choice
	if choice.has("skill_check"):
		var check: Dictionary = choice["skill_check"]
		var result := _resolve_skill_check(check)
		var result_name := _check_result_name(result)
		skill_check_resolved.emit(check, result_name)

		# Record in history
		dialogue_history.append({
			"type": "skill_check",
			"check": check,
			"result": result_name,
		})

		# Branch based on result
		if result == CheckResult.SUCCESS or result == CheckResult.CRITICAL_SUCCESS:
			var next_node: String = check.get("on_success", "")
			if next_node.is_empty() or next_node == "end":
				end_dialogue()
			else:
				current_node_id = next_node
				_display_node(current_node_id)
		else:
			var next_node: String = check.get("on_failure", "")
			if next_node.is_empty() or next_node == "end":
				end_dialogue()
			else:
				current_node_id = next_node
				_display_node(current_node_id)
		return

	# Navigate
	var next_node: String = choice.get("next", "")
	if next_node.is_empty() or next_node == "end":
		end_dialogue()
	else:
		current_node_id = next_node
		_display_node(current_node_id)


func end_dialogue() -> void:
	is_active = false
	dialogue_ended.emit(current_dialogue_id)
	current_dialogue_id = ""
	dialogue_data = {}


func get_history() -> Array[Dictionary]:
	return dialogue_history


func _display_node(node_id: String) -> void:
	var nodes: Dictionary = dialogue_data.get("nodes", {})
	if node_id not in nodes:
		end_dialogue()
		return
	var node: Dictionary = nodes[node_id]

	# Handle skill_check node type (not on a choice, but as a standalone node)
	if node.get("type", "") == "skill_check":
		var check: Dictionary = node.get("check", {})
		var result := _resolve_skill_check(check)
		var result_name := _check_result_name(result)
		skill_check_resolved.emit(check, result_name)
		dialogue_history.append({
			"type": "skill_check",
			"node_id": node_id,
			"check": check,
			"result": result_name,
		})
		if result == CheckResult.SUCCESS or result == CheckResult.CRITICAL_SUCCESS:
			var next: String = node.get("on_success", "end")
			if next == "end":
				end_dialogue()
			else:
				current_node_id = next
				_display_node(next)
		else:
			var next: String = node.get("on_failure", "end")
			if next == "end":
				end_dialogue()
			else:
				current_node_id = next
				_display_node(next)
		return

	# Resolve conditional text variants
	var resolved_node := node.duplicate(true)
	if node.has("variants"):
		var variants: Array = node["variants"]
		for variant in variants:
			if _check_variant_conditions(variant):
				# Merge variant fields into resolved node
				for key in variant:
					if key != "conditions":
						resolved_node[key] = variant[key]
				break

	# Resolve text_variants (flag-based conditional text)
	resolved_node["text"] = _get_node_text(resolved_node)

	# Process node-level effects
	if resolved_node.has("set_flag"):
		GameManager.set_flag(resolved_node["set_flag"], resolved_node.get("flag_value", true))
	if resolved_node.has("reputation"):
		for faction in resolved_node["reputation"]:
			GameManager.modify_reputation(faction, resolved_node["reputation"][faction])
		_process_reputation_affinity(resolved_node["reputation"])

	# Record in history
	dialogue_history.append({
		"type": "dialogue",
		"node_id": node_id,
		"speaker": resolved_node.get("speaker", ""),
		"text": resolved_node.get("text", ""),
	})

	node_displayed.emit(resolved_node)

	var choices := _get_available_choices(resolved_node)
	if choices.is_empty():
		# Auto-advance or end
		var next: String = resolved_node.get("next", "")
		if next.is_empty() or next == "end":
			end_dialogue()
		else:
			current_node_id = next
			# Small delay then auto-advance — handled by UI
	else:
		choices_presented.emit(choices)


func _resolve_skill_check(check: Dictionary) -> CheckResult:
	var character_id: String = check.get("character", "")
	var stat: String = check.get("stat", "")
	var threshold: int = check.get("threshold", 10)

	var c := PartyManager.get_character(character_id)
	var stat_value: int = c.get(stat, 0)
	var roll: int = randi() % 20 + 1
	var total: int = roll + stat_value

	if roll == 20:
		return CheckResult.CRITICAL_SUCCESS
	elif roll == 1:
		return CheckResult.CRITICAL_FAILURE
	elif total >= threshold:
		return CheckResult.SUCCESS
	else:
		return CheckResult.FAILURE


func _check_result_name(result: CheckResult) -> String:
	match result:
		CheckResult.CRITICAL_SUCCESS:
			return "CRITICAL_SUCCESS"
		CheckResult.SUCCESS:
			return "SUCCESS"
		CheckResult.FAILURE:
			return "FAILURE"
		CheckResult.CRITICAL_FAILURE:
			return "CRITICAL_FAILURE"
	return "FAILURE"


func _check_variant_conditions(variant: Dictionary) -> bool:
	if not variant.has("conditions"):
		return true
	var conditions: Dictionary = variant["conditions"]
	if conditions.has("flag"):
		if not GameManager.has_flag(conditions["flag"]):
			return false
	if conditions.has("flag_value"):
		var flag: String = conditions.get("flag", "")
		if GameManager.get_flag(flag) != conditions["flag_value"]:
			return false
	if conditions.has("reputation"):
		for faction in conditions["reputation"]:
			if GameManager.get_reputation(faction) < conditions["reputation"][faction]:
				return false
	if conditions.has("not_flag"):
		if GameManager.has_flag(conditions["not_flag"]):
			return false
	return true


func _get_available_choices(node: Dictionary) -> Array:
	var all_choices: Array = node.get("choices", [])
	var available: Array = []
	for choice in all_choices:
		if _check_requirements(choice):
			available.append(choice)
	return available


func _check_requirements(choice: Dictionary) -> bool:
	# Check story flag requirements
	if choice.has("requires_flag"):
		if not GameManager.has_flag(choice["requires_flag"]):
			return false
	# Check faction reputation requirements
	if choice.has("requires_reputation"):
		for faction in choice["requires_reputation"]:
			if GameManager.get_reputation(faction) < choice["requires_reputation"][faction]:
				return false
	return true


func _load_dialogue(dialogue_id: String) -> Dictionary:
	var path := "res://data/dialogue/%s.json" % dialogue_id
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	return json.data


## Resolve conditional text from text_variants and relationship_variants.
func _get_node_text(node: Dictionary) -> String:
	# Check relationship_variants first (higher priority)
	var rel_variants: Dictionary = node.get("relationship_variants", {})
	if not rel_variants.is_empty():
		for char_id in rel_variants:
			var tier_variants: Dictionary = rel_variants[char_id]
			var current_tier := RelationshipManager.get_tier_name(
				RelationshipManager.get_tier(char_id)
			).to_lower()
			if current_tier in tier_variants:
				return tier_variants[current_tier]

	# Then check flag-based text_variants
	var variants: Dictionary = node.get("text_variants", {})
	if not variants.is_empty():
		for flag_name in variants:
			if flag_name != "default" and GameManager.has_flag(flag_name):
				return variants[flag_name]
		return variants.get("default", node.get("text", ""))

	return node.get("text", "")


## Bridge reputation changes to RelationshipManager affinity.
## Maps dialogue reputation amounts (typically 1-5) to affinity points.
func _process_reputation_affinity(reputation: Dictionary) -> void:
	for character_id in reputation:
		var amount: int = reputation[character_id]
		# +1 rep → +3 affinity, +2 → +5, +3 → +7, etc.
		var affinity_gain := amount * 2 + 1
		RelationshipManager.change_affinity(character_id.to_lower(), affinity_gain)
