class_name LevelUpScreen
extends Control
## UI screen for handling level-up stat point allocation.
##
## Displays character info, automatic stat increases, and manual stat choices.
## Player must assign 1 stat point before confirming.

signal level_up_complete(character_id: String)

var _character_id: String = ""
var _old_level: int = 1
var _new_level: int = 2
var _point_assigned: bool = false

@onready var character_name_label: Label = %CharacterNameLabel
@onready var level_label: Label = %LevelLabel
@onready var auto_stats_label: Label = %AutoStatsLabel
@onready var attack_button: Button = %AttackButton
@onready var defense_button: Button = %DefenseButton
@onready var lattice_button: Button = %LatticeButton
@onready var confirm_button: Button = %ConfirmButton


func _ready() -> void:
	if confirm_button:
		confirm_button.disabled = true
		confirm_button.pressed.connect(_on_confirm_pressed)

	if attack_button:
		attack_button.pressed.connect(_on_stat_button_pressed.bind("Attack"))
	if defense_button:
		defense_button.pressed.connect(_on_stat_button_pressed.bind("Defense"))
	if lattice_button:
		lattice_button.pressed.connect(_on_stat_button_pressed.bind("Lattice"))


## Initialize the screen with character data.
func setup(character_id: String, old_level: int, new_level: int) -> void:
	_character_id = character_id
	_old_level = old_level
	_new_level = new_level
	_point_assigned = false

	var character := PartyManager.get_character(character_id)
	var char_name: String = character.get("name", character_id)

	if character_name_label:
		character_name_label.text = char_name
	if level_label:
		level_label.text = "Level %d → %d" % [old_level, new_level]
	if auto_stats_label:
		auto_stats_label.text = "Automatic Bonuses:\n+5 Max HP\n+2 Heat Capacity"

	_update_buttons()


func _update_buttons() -> void:
	if confirm_button:
		confirm_button.disabled = not _point_assigned


func _on_stat_button_pressed(stat: String) -> void:
	if _point_assigned:
		return

	if PartyManager.assign_stat_point(_character_id, stat):
		_point_assigned = true
		_update_buttons()

		# Disable all stat buttons after selection
		if attack_button:
			attack_button.disabled = true
		if defense_button:
			defense_button.disabled = true
		if lattice_button:
			lattice_button.disabled = true


func _on_confirm_pressed() -> void:
	level_up_complete.emit(_character_id)
	queue_free()
