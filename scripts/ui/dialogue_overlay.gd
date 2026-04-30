class_name DialogueOverlay
extends CanvasLayer
## DialogueOverlay — Manages dialogue scene as overlay on top of exploration.
##
## Instantiates the dialogue scene UI, dims the background, and connects
## to DialogueManager to auto-hide when dialogue ends.

signal dialogue_finished()

const DIALOGUE_SCENE_PATH := "res://scenes/dialogue/dialogue_scene.tscn"

var _dialogue_instance: Control = null
var _dim_rect: ColorRect = null


func _ready() -> void:
	layer = 10
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)


func show_dialogue(dialogue_id: String) -> void:
	if _dialogue_instance != null:
		return

	# Create dim background
	_dim_rect = ColorRect.new()
	_dim_rect.color = Color(0, 0, 0, 0.6)
	_dim_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim_rect)

	# Instantiate dialogue scene
	var scene := load(DIALOGUE_SCENE_PATH) as PackedScene
	if scene == null:
		push_warning("DialogueOverlay: Failed to load dialogue scene: %s" % DIALOGUE_SCENE_PATH)
		_cleanup()
		return

	_dialogue_instance = scene.instantiate()
	add_child(_dialogue_instance)

	# Change state and start dialogue
	GameManager.change_state(GameManager.GameState.DIALOGUE)
	DialogueManager.start_dialogue(dialogue_id)


func hide_dialogue() -> void:
	_cleanup()
	dialogue_finished.emit()


func _on_dialogue_ended(_dialogue_id: String) -> void:
	# Small defer to let dialogue_controller finish its own _on_dialogue_ended first
	hide_dialogue.call_deferred()


func _cleanup() -> void:
	if _dialogue_instance != null:
		# Disconnect to prevent dialogue_controller's queue_free from conflicting
		_dialogue_instance.queue_free()
		_dialogue_instance = null
	if _dim_rect != null:
		_dim_rect.queue_free()
		_dim_rect = null
