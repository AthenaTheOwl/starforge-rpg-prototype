extends Control
## DialogueController — Drives the dialogue UI overlay.
##
## Listens to DialogueManager signals and displays speaker, text, choices.
## Features typewriter text reveal, portrait display, skill check indicators,
## BBCode formatting, and dialogue history log.

@onready var speaker_label: Label = $DialoguePanel/VBox/SpeakerLabel
@onready var dialogue_text: RichTextLabel = $DialoguePanel/VBox/DialogueText
@onready var choices_container: VBoxContainer = $DialoguePanel/VBox/ChoicesContainer
@onready var continue_btn: Button = $DialoguePanel/VBox/ContinueBtn
@onready var portrait_left: TextureRect = $PortraitLeft
@onready var portrait_right: TextureRect = $PortraitRight
@onready var dialogue_log_panel: PanelContainer = $DialogueLogPanel
@onready var dialogue_log_text: RichTextLabel = $DialogueLogPanel/LogVBox/LogScrollContainer/LogText
@onready var log_toggle_btn: Button = $DialoguePanel/VBox/LogToggleBtn

## Characters that appear on the right portrait side (player/protagonist).
const RIGHT_SIDE_CHARACTERS: Array[String] = ["avyanna"]

## Typewriter speed: characters revealed per second.
const TYPEWRITER_SPEED: float = 40.0

## Color for BEE:: protocol messages.
const BEE_COLOR := Color(0.0, 0.9, 0.9)  # Cyan

var _pending_next: String = ""
var _typewriter_active: bool = false
var _full_bbcode: String = ""
var _revealed_chars: int = 0
var _total_visible_chars: int = 0
var _typewriter_elapsed: float = 0.0


func _ready() -> void:
	DialogueManager.node_displayed.connect(_on_node_displayed)
	DialogueManager.choices_presented.connect(_on_choices_presented)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	DialogueManager.skill_check_resolved.connect(_on_skill_check_resolved)
	continue_btn.pressed.connect(_on_continue)
	continue_btn.visible = false
	log_toggle_btn.pressed.connect(_toggle_log)
	dialogue_log_panel.visible = false
	portrait_left.visible = false
	portrait_right.visible = false


func _process(delta: float) -> void:
	if not _typewriter_active:
		return
	_typewriter_elapsed += delta
	var target_chars := int(_typewriter_elapsed * TYPEWRITER_SPEED)
	if target_chars >= _total_visible_chars:
		target_chars = _total_visible_chars
		_typewriter_active = false
	if target_chars != _revealed_chars:
		_revealed_chars = target_chars
		dialogue_text.visible_characters = _revealed_chars


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_handle_click()
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			_handle_click()


func _handle_click() -> void:
	if _typewriter_active:
		# Skip typewriter, reveal all text
		_typewriter_active = false
		_revealed_chars = _total_visible_chars
		dialogue_text.visible_characters = -1
		return
	# If typewriter done and continue button is showing, auto-advance
	if continue_btn.visible:
		_on_continue()


func _on_node_displayed(node: Dictionary) -> void:
	var speaker: String = node.get("speaker", "")
	var speaker_upper := speaker.to_upper()
	speaker_label.text = speaker_upper

	# Update portraits
	var speaker_id: String = node.get("speaker_id", speaker.to_lower())
	_update_portraits(speaker_id, node.get("expression", "neutral"))

	# Format text with BBCode support
	var raw_text: String = node.get("text", "...")
	var formatted := _format_text(raw_text, speaker_id)
	_full_bbcode = formatted

	# Set BBCode and start typewriter
	dialogue_text.text = formatted
	_total_visible_chars = dialogue_text.get_total_character_count()
	_revealed_chars = 0
	_typewriter_elapsed = 0.0
	_typewriter_active = true
	dialogue_text.visible_characters = 0

	_pending_next = node.get("next", "")
	_clear_choices()

	# If no choices and has auto-next, show continue button
	if node.get("choices", []).is_empty() and not _pending_next.is_empty():
		continue_btn.visible = true
	else:
		continue_btn.visible = false


func _on_choices_presented(choices: Array) -> void:
	_clear_choices()
	continue_btn.visible = false

	for i in choices.size():
		var choice: Dictionary = choices[i]
		var btn := Button.new()
		var choice_text: String = choice.get("text", "...")

		# Add skill check indicator
		if choice.has("skill_check"):
			var check: Dictionary = choice["skill_check"]
			var stat_name: String = check.get("stat", "???")
			var threshold: int = check.get("threshold", 0)
			# Capitalize stat name for display
			var display_stat := stat_name.capitalize()
			choice_text = "[%s %d] %s" % [display_stat, threshold, choice_text]

		btn.text = choice_text
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var idx := i
		btn.pressed.connect(func():
			AudioManager.play_sfx("choice_select")
			DialogueManager.select_choice(idx)
		)
		choices_container.add_child(btn)


func _on_continue() -> void:
	AudioManager.play_sfx("text_advance")
	continue_btn.visible = false
	if _pending_next == "end" or _pending_next.is_empty():
		DialogueManager.end_dialogue()
	else:
		# Manually advance
		DialogueManager.current_node_id = _pending_next
		DialogueManager._display_node(_pending_next)


func _on_dialogue_ended(_dialogue_id: String) -> void:
	# Reset UI state
	_clear_choices()
	continue_btn.visible = false
	portrait_left.visible = false
	portrait_right.visible = false
	_typewriter_active = false

	# If a parent scene manages dialogue lifecycle (ChapterFlow, DialogueOverlay),
	# let it handle state changes and visibility. Only self-destruct when standalone.
	var parent := get_parent()
	if parent.has_method("_on_dialogue_finished") or parent is DialogueOverlay:
		return
	GameManager.change_state(GameManager.GameState.EXPLORATION)
	queue_free()


func _on_skill_check_resolved(check: Dictionary, result: String) -> void:
	var stat_name: String = check.get("stat", "???").capitalize()
	var threshold: int = check.get("threshold", 0)
	var is_success := result == "SUCCESS" or result == "CRITICAL_SUCCESS"
	var flash_color := Color.GREEN if is_success else Color.RED

	# Flash the dialogue panel background briefly
	var panel: PanelContainer = $DialoguePanel
	var tween := create_tween()
	tween.tween_property(panel, "modulate", flash_color, 0.15)
	tween.tween_property(panel, "modulate", Color.WHITE, 0.3)

	# Show result text in the dialogue area
	var result_display := result.replace("_", " ")
	var color_hex := flash_color.to_html(false)
	var feedback := "[color=#%s][b]%s Check (DC %d): %s[/b][/color]" % [color_hex, stat_name, threshold, result_display]
	dialogue_text.text = feedback
	dialogue_text.visible_characters = -1
	_typewriter_active = false


func _update_portraits(speaker_id: String, expression: String) -> void:
	# Hide both first
	portrait_left.visible = false
	portrait_right.visible = false

	if speaker_id.is_empty():
		return

	var is_right := speaker_id.to_lower() in RIGHT_SIDE_CHARACTERS
	var portrait: TextureRect
	if is_right:
		portrait = portrait_right
		if portrait.has_method("set_side"):
			portrait.set_side("right")
	else:
		portrait = portrait_left
		if portrait.has_method("set_side"):
			portrait.set_side("left")

	if portrait.has_method("set_character"):
		portrait.set_character(speaker_id, expression)
	portrait.visible = true


func _format_text(raw_text: String, speaker_id: String) -> String:
	var text := raw_text

	# Wrap internal thoughts (text in parentheses) in italics
	# Pattern: (thought text) -> [i](thought text)[/i]
	var regex := RegEx.new()
	regex.compile("\\(([^)]+)\\)")
	var result := regex.search(text)
	while result:
		var full_match := result.get_string()
		text = text.replace(full_match, "[i]%s[/i]" % full_match)
		result = regex.search(text, result.get_end() + 7)  # offset past added tags

	# Color BEE:: protocol messages in cyan
	if text.begins_with("BEE::") or text.begins_with("<BEE") or speaker_id == "bee":
		text = "[color=#%s]%s[/color]" % [BEE_COLOR.to_html(false), text]

	# Color AI citizen messages (WAFFLE.BAT, CINNAMON.EXE, BUBBLES) in cyan
	var ai_prefixes := ["WAFFLE", "CINNAMON", "BUBBLES"]
	for prefix in ai_prefixes:
		if speaker_id.to_upper().begins_with(prefix):
			text = "[color=#%s]%s[/color]" % [BEE_COLOR.to_html(false), text]
			break

	return text


func _toggle_log() -> void:
	dialogue_log_panel.visible = not dialogue_log_panel.visible
	if dialogue_log_panel.visible:
		_refresh_log()


func _refresh_log() -> void:
	var log_text := ""
	var history := DialogueManager.get_history()
	for entry in history:
		match entry.get("type", ""):
			"dialogue":
				var speaker: String = entry.get("speaker", "")
				var text: String = entry.get("text", "")
				if not speaker.is_empty():
					log_text += "[b]%s[/b]: %s\n\n" % [speaker.to_upper(), text]
				else:
					log_text += "%s\n\n" % text
			"skill_check":
				var check: Dictionary = entry.get("check", {})
				var result: String = entry.get("result", "")
				var stat: String = check.get("stat", "???")
				log_text += "[i]--- %s Check: %s ---[/i]\n\n" % [stat.capitalize(), result]
	dialogue_log_text.text = log_text


func _clear_choices() -> void:
	for child in choices_container.get_children():
		child.queue_free()
