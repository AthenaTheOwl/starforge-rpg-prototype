extends Control
## ThemeTest — Test scene for verifying theme and polish features.
##
## Demonstrates all themed controls, HPBar, and SceneTransition.

@onready var hp_bar_container := $ScrollContainer/VBox/HPBarSection/VBox/HPBarContainer/HPBarTest
@onready var transition_btn := $ScrollContainer/VBox/ControlRow/TransitionBtn
@onready var back_btn := $ScrollContainer/VBox/ControlRow/BackBtn


func _ready() -> void:
	_setup_hp_bars()
	_connect_signals()


func _setup_hp_bars() -> void:
	# Create three HPBar instances demonstrating different health levels
	var hp_high := HPBar.new()
	hp_high.custom_minimum_size = Vector2(200, 30)
	hp_high.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_high.show_label = true
	hp_high.label_format = "HP: %d/%d"
	hp_high.set_hp_max(100, 85, false)
	hp_bar_container.add_child(hp_high)

	var hp_med := HPBar.new()
	hp_med.custom_minimum_size = Vector2(200, 30)
	hp_med.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_med.show_label = true
	hp_med.label_format = "HP: %d/%d"
	hp_med.set_hp_max(100, 50, false)
	hp_bar_container.add_child(hp_med)

	var hp_low := HPBar.new()
	hp_low.custom_minimum_size = Vector2(200, 30)
	hp_low.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_low.show_label = true
	hp_low.label_format = "HP: %d/%d"
	hp_low.set_hp_max(100, 15, false)
	hp_bar_container.add_child(hp_low)

	# Animate the HP bars on a timer to demonstrate the tween effect
	var timer := Timer.new()
	timer.wait_time = 2.0
	timer.timeout.connect(_animate_hp_bars)
	add_child(timer)
	timer.start()


func _animate_hp_bars() -> void:
	# Randomly change HP bar values to show animation
	for child in hp_bar_container.get_children():
		if child is HPBar:
			var new_hp := randf_range(10, 100)
			child.set_hp(new_hp, true)


func _connect_signals() -> void:
	transition_btn.pressed.connect(_on_transition_pressed)
	back_btn.pressed.connect(_on_back_pressed)


func _on_transition_pressed() -> void:
	# Test the scene transition with a self-transition
	var transition := SceneTransition.new()
	add_child(transition)

	# Wait for ready
	await transition.ready

	# Do a fade out/in without changing scenes
	await transition.fade_out()
	await get_tree().create_timer(0.2).timeout  # Brief pause
	await transition.fade_in()

	transition.queue_free()


func _on_back_pressed() -> void:
	# Use SceneTransition to go back to title screen
	SceneTransition.transition_to("res://scenes/menus/title_screen.tscn")
