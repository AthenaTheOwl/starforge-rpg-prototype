class_name SceneTransition
extends CanvasLayer
## SceneTransition — Fade in/out transitions between scenes.
##
## Provides smooth fade transitions when changing scenes.
## Use the static transition_to() method for easy scene switching.
## Duration: 0.4s fade out, 0.4s fade in.

signal transition_midpoint

const FADE_DURATION := 0.4

var _fade_rect: ColorRect
var _is_transitioning := false


func _ready() -> void:
	layer = 100  # Render on top of everything
	_create_fade_rect()


func _create_fade_rect() -> void:
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color.BLACK
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.modulate.a = 0.0  # Start transparent
	add_child(_fade_rect)


## Fade out to black, emit midpoint signal, then fade in.
func fade_out_in() -> void:
	if _is_transitioning:
		return

	_is_transitioning = true
	await fade_out()
	transition_midpoint.emit()
	await fade_in()
	_is_transitioning = false


## Fade to black (alpha 0 -> 1).
func fade_out() -> void:
	var tween := create_tween()
	tween.tween_property(_fade_rect, "modulate:a", 1.0, FADE_DURATION)
	await tween.finished


## Fade from black (alpha 1 -> 0).
func fade_in() -> void:
	var tween := create_tween()
	tween.tween_property(_fade_rect, "modulate:a", 0.0, FADE_DURATION)
	await tween.finished


## Static helper to transition to a new scene.
## Creates a temporary SceneTransition, fades out, changes scene, then fades in.
static func transition_to(scene_path: String) -> void:
	# Get the scene tree from the current scene
	var tree := Engine.get_main_loop() as SceneTree
	if not tree:
		push_error("SceneTransition: Could not get SceneTree")
		return

	# Create temporary transition layer
	var transition := SceneTransition.new()
	tree.root.add_child(transition)

	# Wait for ready
	await transition.ready

	# Fade out
	await transition.fade_out()

	# Change scene
	var error := tree.change_scene_to_file(scene_path)
	if error != OK:
		push_error("SceneTransition: Failed to load scene: %s" % scene_path)
		transition.queue_free()
		return

	# Wait a frame for new scene to load
	await tree.process_frame

	# Fade in
	await transition.fade_in()

	# Clean up
	transition.queue_free()


## Static helper to transition to a packed scene.
static func transition_to_packed(scene: PackedScene) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if not tree:
		push_error("SceneTransition: Could not get SceneTree")
		return

	var transition := SceneTransition.new()
	tree.root.add_child(transition)

	await transition.ready
	await transition.fade_out()

	var error := tree.change_scene_to_packed(scene)
	if error != OK:
		push_error("SceneTransition: Failed to load packed scene")
		transition.queue_free()
		return

	await tree.process_frame
	await transition.fade_in()
	transition.queue_free()
