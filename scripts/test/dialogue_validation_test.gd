extends Node2D
## DialogueValidationTest — Validates all dialogue trees and tests dialogue flow.
##
## Set this scene as main_scene temporarily to test dialogue.
## Validates all 5 Act 1 dialogue files, prints errors, then starts a test dialogue.

const DIALOGUE_FILES: Array[String] = [
	"act1_prologue_boarding",
	"act1_naming_scene",
	"act1_first_watch",
	"act1_shard_whispers",
	"act1_crew_meal",
]


func _ready() -> void:
	print("=== DIALOGUE VALIDATION TEST ===")
	_validate_all_dialogues()
	print("=== STARTING TEST DIALOGUE: act1_naming_scene ===")
	_connect_debug_signals()
	# Wait a frame for the dialogue scene to be ready
	await get_tree().process_frame
	DialogueManager.start_dialogue("act1_naming_scene")


func _validate_all_dialogues() -> void:
	var total_errors := 0
	for dialogue_id in DIALOGUE_FILES:
		var path := "res://data/dialogue/%s.json" % dialogue_id
		if not FileAccess.file_exists(path):
			print("  MISSING: %s" % path)
			total_errors += 1
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		var json := JSON.new()
		if json.parse(file.get_as_text()) != OK:
			print("  PARSE ERROR: %s — %s" % [path, json.get_error_message()])
			total_errors += 1
			continue
		var data: Dictionary = json.data
		var errors := DialogueParser.validate_dialogue(data)
		if errors.is_empty():
			print("  OK: %s" % dialogue_id)
		else:
			for err in errors:
				print("  ERROR [%s]: %s" % [dialogue_id, err])
				total_errors += 1

	if total_errors == 0:
		print("All %d dialogue files validated successfully." % DIALOGUE_FILES.size())
	else:
		print("Validation complete with %d error(s)." % total_errors)


func _connect_debug_signals() -> void:
	DialogueManager.dialogue_started.connect(func(id: String):
		print("[DIALOGUE] Started: %s" % id)
	)
	DialogueManager.node_displayed.connect(func(node: Dictionary):
		var speaker: String = node.get("speaker", "")
		var text: String = node.get("text", "")
		print("[DIALOGUE] %s: %s" % [speaker, text.left(80)])
	)
	DialogueManager.choices_presented.connect(func(choices: Array):
		print("[DIALOGUE] Choices presented: %d options" % choices.size())
		for i in choices.size():
			print("  [%d] %s" % [i, choices[i].get("text", "???")])
		# Auto-select first choice for testing
		print("  -> Auto-selecting choice 0")
		DialogueManager.select_choice(0)
	)
	DialogueManager.skill_check_resolved.connect(func(check: Dictionary, result: String):
		print("[SKILL CHECK] %s DC %d -> %s" % [
			check.get("stat", "???"),
			check.get("threshold", 0),
			result
		])
	)
	DialogueManager.dialogue_ended.connect(func(id: String):
		print("[DIALOGUE] Ended: %s" % id)
		print("=== Flags set during dialogue ===")
		for flag in GameManager.story_flags:
			print("  %s = %s" % [flag, str(GameManager.story_flags[flag])])
		print("=== TEST COMPLETE ===")
	)
