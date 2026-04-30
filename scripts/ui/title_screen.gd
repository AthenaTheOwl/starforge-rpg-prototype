extends Control
## Title screen controller. Handles menu button presses.

@onready var new_game_btn: Button = %NewGameBtn if has_node("%NewGameBtn") else $VBox/NewGameBtn
@onready var load_game_btn: Button = %LoadGameBtn if has_node("%LoadGameBtn") else $VBox/LoadGameBtn
@onready var settings_btn: Button = %SettingsBtn if has_node("%SettingsBtn") else $VBox/SettingsBtn
@onready var quit_btn: Button = %QuitBtn if has_node("%QuitBtn") else $VBox/QuitBtn


func _ready() -> void:
	new_game_btn.pressed.connect(_on_new_game)
	load_game_btn.pressed.connect(_on_load_game)
	settings_btn.pressed.connect(_on_settings)
	quit_btn.pressed.connect(_on_quit)

	# Disable load if no saves exist
	_update_load_button()


func _on_new_game() -> void:
	# Reset state for a fresh game
	PartyManager.recruit_character("avyanna")
	GameManager.current_act = 1
	GameManager.current_chapter = 0
	GameManager.story_flags.clear()
	GameManager.cleared_encounters.clear()
	StoryManager.played_dialogues.clear()
	StoryManager.active_objectives.clear()
	StoryManager.completed_objectives.clear()
	RelationshipManager._initialize_affinity()
	GameManager.change_state(GameManager.GameState.EXPLORATION)
	get_tree().change_scene_to_file("res://scenes/story/chapter_flow.tscn")


func _on_load_game() -> void:
	var save_load_scene: PackedScene = load("res://scenes/menus/save_load_screen.tscn")
	var save_load_screen: Control = save_load_scene.instantiate()
	add_child(save_load_screen)
	save_load_screen.setup(1)  # 1 = LOAD mode
	save_load_screen.action_complete.connect(_on_save_load_complete.bind(save_load_screen))


func _on_save_load_complete(screen: Node) -> void:
	screen.queue_free()
	_update_load_button()


func _update_load_button() -> void:
	# Check if any saves exist
	var has_any_save := false
	for i in range(SaveManager.MAX_MANUAL_SLOTS):
		if SaveManager.has_save(i):
			has_any_save = true
			break
	if not has_any_save and SaveManager.has_save(-1):
		has_any_save = true
	load_game_btn.disabled = not has_any_save


func _on_settings() -> void:
	var settings_scene: PackedScene = load("res://scenes/menus/settings_screen.tscn")
	var settings_screen: Control = settings_scene.instantiate()
	add_child(settings_screen)
	settings_screen.closed.connect(_on_settings_closed.bind(settings_screen))


func _on_settings_closed(screen: Node) -> void:
	if is_instance_valid(screen) and screen.is_inside_tree():
		screen.queue_free()


func _on_quit() -> void:
	get_tree().quit()
