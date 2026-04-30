extends CanvasLayer
## PauseMenu — Global pause overlay. Listens for Escape during EXPLORATION/DIALOGUE.

@onready var bg: ColorRect = $Background
@onready var panel: PanelContainer = $Background/CenterContainer/Panel
@onready var resume_btn: Button = $Background/CenterContainer/Panel/VBox/ResumeBtn
@onready var party_btn: Button = $Background/CenterContainer/Panel/VBox/PartyBtn
@onready var save_btn: Button = $Background/CenterContainer/Panel/VBox/SaveBtn
@onready var settings_btn: Button = $Background/CenterContainer/Panel/VBox/SettingsBtn
@onready var quit_btn: Button = $Background/CenterContainer/Panel/VBox/QuitBtn


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	layer = 100
	visible = false

	resume_btn.pressed.connect(_on_resume)
	party_btn.pressed.connect(_on_party)
	save_btn.pressed.connect(_on_save)
	settings_btn.pressed.connect(_on_settings)
	quit_btn.pressed.connect(_on_quit_to_title)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if visible:
			_close()
		else:
			_open()
		get_viewport().set_input_as_handled()


func _can_pause() -> bool:
	var state := GameManager.current_state
	return state == GameManager.GameState.EXPLORATION or state == GameManager.GameState.DIALOGUE


func _open() -> void:
	if not _can_pause():
		return
	visible = true
	get_tree().paused = true
	resume_btn.grab_focus()


func _close() -> void:
	visible = false
	get_tree().paused = false


func _on_resume() -> void:
	_close()


func _on_party() -> void:
	# TODO: Party screen not yet implemented
	pass


func _on_save() -> void:
	var save_load_scene: PackedScene = load("res://scenes/menus/save_load_screen.tscn")
	var save_load_screen: Control = save_load_scene.instantiate()
	save_load_screen.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	add_child(save_load_screen)
	save_load_screen.setup(0)  # 0 = SAVE mode
	save_load_screen.action_complete.connect(_on_sub_screen_closed.bind(save_load_screen))


func _on_settings() -> void:
	# TODO: Settings screen not yet implemented
	pass


func _on_quit_to_title() -> void:
	_close()
	GameManager.change_state(GameManager.GameState.TITLE)
	GameManager.transition_to_scene("res://scenes/menus/title_screen.tscn")


func _on_sub_screen_closed(screen: Node) -> void:
	screen.queue_free()
