class_name DialogueParser
extends RefCounted
## DialogueParser — Validates dialogue JSON data for structural correctness.
##
## Checks node references, skill check requirements, and data integrity.


## Validate a dialogue data dictionary. Returns an array of error strings.
## An empty array means the data is valid.
static func validate_dialogue(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []

	if not data.has("nodes"):
		errors.append("Missing 'nodes' dictionary.")
		return errors

	var nodes: Dictionary = data["nodes"]
	if nodes.is_empty():
		errors.append("Dialogue has no nodes.")
		return errors

	# Check start node exists
	var start_node: String = data.get("start_node", "start")
	if start_node not in nodes:
		errors.append("Start node '%s' not found in nodes." % start_node)

	# Validate each node
	for node_id in nodes:
		var node: Dictionary = nodes[node_id]
		var prefix := "Node '%s': " % node_id

		# Validate skill_check node type
		if node.get("type", "") == "skill_check":
			_validate_skill_check_node(node, prefix, nodes, errors)
			continue

		# Validate 'next' pointer
		if node.has("next"):
			var next: String = node["next"]
			if next != "end" and next not in nodes:
				errors.append(prefix + "next pointer '%s' references missing node." % next)

		# Validate choices
		if node.has("choices"):
			var choices: Array = node["choices"]
			for i in choices.size():
				var choice: Dictionary = choices[i]
				var choice_prefix := prefix + "choice %d: " % i

				# Validate choice next pointer
				if choice.has("next"):
					var cnext: String = choice["next"]
					if cnext != "end" and cnext not in nodes:
						errors.append(choice_prefix + "next pointer '%s' references missing node." % cnext)

				# Validate skill check on choice
				if choice.has("skill_check"):
					var check: Dictionary = choice["skill_check"]
					_validate_skill_check_dict(check, choice_prefix, nodes, errors)

		# Validate variants
		if node.has("variants"):
			var variants: Array = node["variants"]
			for i in variants.size():
				var variant: Dictionary = variants[i]
				if variant.has("next"):
					var vnext: String = variant["next"]
					if vnext != "end" and vnext not in nodes:
						errors.append(prefix + "variant %d: next pointer '%s' references missing node." % [i, vnext])

	return errors


static func _validate_skill_check_node(
	node: Dictionary, prefix: String, nodes: Dictionary, errors: Array[String]
) -> void:
	if not node.has("check"):
		errors.append(prefix + "skill_check node missing 'check' dictionary.")

	if not node.has("on_success"):
		errors.append(prefix + "skill_check node missing 'on_success'.")
	elif node["on_success"] != "end" and node["on_success"] not in nodes:
		errors.append(prefix + "on_success '%s' references missing node." % node["on_success"])

	if not node.has("on_failure"):
		errors.append(prefix + "skill_check node missing 'on_failure'.")
	elif node["on_failure"] != "end" and node["on_failure"] not in nodes:
		errors.append(prefix + "on_failure '%s' references missing node." % node["on_failure"])

	if node.has("check"):
		var check: Dictionary = node["check"]
		if not check.has("stat"):
			errors.append(prefix + "check missing 'stat' field.")
		if not check.has("threshold"):
			errors.append(prefix + "check missing 'threshold' field.")


static func _validate_skill_check_dict(
	check: Dictionary, prefix: String, nodes: Dictionary, errors: Array[String]
) -> void:
	if not check.has("stat"):
		errors.append(prefix + "skill_check missing 'stat' field.")
	if not check.has("threshold"):
		errors.append(prefix + "skill_check missing 'threshold' field.")
	if not check.has("on_success"):
		errors.append(prefix + "skill_check missing 'on_success'.")
	elif check["on_success"] != "end" and check["on_success"] not in nodes:
		errors.append(prefix + "skill_check on_success '%s' references missing node." % check["on_success"])
	if not check.has("on_failure"):
		errors.append(prefix + "skill_check missing 'on_failure'.")
	elif check["on_failure"] != "end" and check["on_failure"] not in nodes:
		errors.append(prefix + "skill_check on_failure '%s' references missing node." % check["on_failure"])
