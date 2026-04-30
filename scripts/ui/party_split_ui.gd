class_name PartySplitUI
extends Control
## PartySplitUI — UI overlay for split party combat.
##
## Displays team B status, allows player to issue orders, and shows
## status updates during split combat encounters.

@onready var member_list: VBoxContainer = %MemberList
@onready var order_buttons: HBoxContainer = %OrderButtons
@onready var hold_btn: Button = %HoldBtn
@onready var advance_btn: Button = %AdvanceBtn
@onready var retreat_btn: Button = %RetreatBtn
@onready var status_log: RichTextLabel = %StatusLog
@onready var enemies_label: Label = %EnemiesLabel

## Reference to the PartySplit instance being displayed.
var party_split: PartySplit = null

## Maximum status log entries to keep.
const MAX_LOG_ENTRIES := 5

## Status log history.
var log_entries: Array[String] = []


func _ready() -> void:
	# Connect order buttons
	if hold_btn:
		hold_btn.pressed.connect(_on_hold_pressed)
	if advance_btn:
		advance_btn.pressed.connect(_on_advance_pressed)
	if retreat_btn:
		retreat_btn.pressed.connect(_on_retreat_pressed)

	# Connect to CombatManager signals
	if CombatManager.has_signal("team_b_update"):
		CombatManager.team_b_update.connect(_on_team_b_update)

	# Hide by default
	visible = false


## Initialize the UI with a PartySplit instance.
func setup(split: PartySplit) -> void:
	party_split = split
	visible = true
	refresh_display()
	clear_log()


## Refresh all UI elements.
func refresh_display() -> void:
	if not party_split:
		return

	var report: Dictionary = party_split.get_team_b_report()

	_refresh_member_list(report)
	_refresh_order_buttons(report)
	_refresh_enemies_label(report)


## Update member list with current HP bars and status.
func _refresh_member_list(report: Dictionary) -> void:
	if not member_list:
		return

	# Clear existing children
	for child in member_list.get_children():
		child.queue_free()

	var members: Array = report.get("members", [])

	for member_data in members:
		var member_panel := _create_member_panel(member_data)
		member_list.add_child(member_panel)


## Create a panel for a single team B member.
func _create_member_panel(member_data: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 50)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	# Name label
	var name_label := Label.new()
	var member_name: String = member_data.get("name", "Unknown")
	var hp: int = member_data.get("hp", 0)
	var hp_max: int = member_data.get("hp_max", 100)

	name_label.text = "%s" % member_name
	if not member_data.get("alive", false):
		name_label.text += " [FALLEN]"
		name_label.modulate = Color(0.5, 0.5, 0.5, 0.7)

	vbox.add_child(name_label)

	# HP bar
	var hp_bar := ProgressBar.new()
	hp_bar.max_value = hp_max
	hp_bar.value = hp
	hp_bar.custom_minimum_size = Vector2(150, 16)
	hp_bar.show_percentage = false

	# Color code based on HP percentage
	var hp_percent: float = member_data.get("hp_percent", 0.0)
	if hp_percent > 0.6:
		hp_bar.modulate = Color(0.2, 0.8, 0.2)  # Green
	elif hp_percent > 0.3:
		hp_bar.modulate = Color(0.8, 0.8, 0.2)  # Yellow
	else:
		hp_bar.modulate = Color(0.8, 0.2, 0.2)  # Red

	vbox.add_child(hp_bar)

	# HP text
	var hp_label := Label.new()
	hp_label.text = "%d / %d HP" % [hp, hp_max]
	hp_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(hp_label)

	return panel


## Update order button states based on current mode.
func _refresh_order_buttons(report: Dictionary) -> void:
	if not order_buttons:
		return

	var current_mode: int = report.get("mode", PartySplit.TeamBMode.HOLD)

	# Highlight current mode
	if hold_btn:
		hold_btn.disabled = (current_mode == PartySplit.TeamBMode.HOLD)
	if advance_btn:
		advance_btn.disabled = (current_mode == PartySplit.TeamBMode.ADVANCE)
	if retreat_btn:
		retreat_btn.disabled = (current_mode == PartySplit.TeamBMode.RETREAT)


## Update enemies remaining label.
func _refresh_enemies_label(report: Dictionary) -> void:
	if not enemies_label:
		return

	var enemy_count: int = report.get("enemies_remaining", 0)
	enemies_label.text = "Enemies: %d" % enemy_count


## Handle Hold button press.
func _on_hold_pressed() -> void:
	if party_split:
		party_split.set_team_b_orders(PartySplit.TeamBMode.HOLD)
		add_log_entry("[color=cyan]Orders issued: Hold Position[/color]")
		refresh_display()


## Handle Advance button press.
func _on_advance_pressed() -> void:
	if party_split:
		party_split.set_team_b_orders(PartySplit.TeamBMode.ADVANCE)
		add_log_entry("[color=yellow]Orders issued: Advance[/color]")
		refresh_display()


## Handle Retreat button press.
func _on_retreat_pressed() -> void:
	if party_split:
		party_split.set_team_b_orders(PartySplit.TeamBMode.RETREAT)
		add_log_entry("[color=green]Orders issued: Retreat[/color]")
		refresh_display()


## Handle team B update signal from CombatManager.
func _on_team_b_update(report: Dictionary) -> void:
	refresh_display()

	# Add status messages to log
	var messages: Array = report.get("messages", [])
	for msg in messages:
		add_log_entry(msg)

	# Show warning if team B is critical
	if report.get("status", "") == "critical":
		add_log_entry("[color=red]WARNING: Team B in critical condition![/color]")
	elif report.get("status", "") == "defeated":
		add_log_entry("[color=red]Team B has been defeated![/color]")


## Add an entry to the status log.
func add_log_entry(message: String) -> void:
	log_entries.append(message)

	# Keep only last MAX_LOG_ENTRIES
	while log_entries.size() > MAX_LOG_ENTRIES:
		log_entries.remove_at(0)

	_refresh_status_log()


## Refresh the status log display.
func _refresh_status_log() -> void:
	if not status_log:
		return

	status_log.clear()
	for entry in log_entries:
		status_log.append_text(entry + "\n")

	# Auto-scroll to bottom
	status_log.scroll_to_line(status_log.get_line_count())


## Clear the status log.
func clear_log() -> void:
	log_entries.clear()
	_refresh_status_log()


## Hide the UI when split combat ends.
func teardown() -> void:
	visible = false
	party_split = null
	clear_log()
