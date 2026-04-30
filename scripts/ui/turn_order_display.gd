class_name TurnOrderDisplay
extends HBoxContainer
## TurnOrderDisplay — Shows combatant names in speed-sorted order at the top of the battle screen.
##
## Highlights the current combatant and grays out dead ones.
## Listens to CombatManager.turn_started to auto-refresh.

const COLOR_ACTIVE := Color(1.0, 0.9, 0.3, 1.0)
const COLOR_ALIVE := Color(0.85, 0.85, 0.85, 1.0)
const COLOR_DEAD := Color(0.4, 0.4, 0.4, 0.5)
const COLOR_ACTIVE_BG := Color(1.0, 0.9, 0.3, 0.15)

var _panels: Array[PanelContainer] = []


func _ready() -> void:
	CombatManager.turn_started.connect(_on_turn_started)


func _on_turn_started(_combatant: Dictionary) -> void:
	refresh(CombatManager.turn_order, CombatManager.current_turn_index)


## Rebuild the display with the given turn order, highlighting current_index.
func refresh(turn_order: Array[Dictionary], current_index: int) -> void:
	for child in get_children():
		child.queue_free()
	_panels.clear()

	for i in turn_order.size():
		var entry: Dictionary = turn_order[i]
		var ref: Dictionary = entry.get("ref", {})
		var is_dead: bool = ref.get("hp", 0) <= 0
		var is_current: bool = i == current_index

		var panel := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(4)
		style.content_margin_left = 8.0
		style.content_margin_right = 8.0
		style.content_margin_top = 4.0
		style.content_margin_bottom = 4.0

		if is_current:
			style.bg_color = COLOR_ACTIVE_BG
			style.border_color = COLOR_ACTIVE
			style.border_width_left = 2
			style.border_width_right = 2
			style.border_width_top = 2
			style.border_width_bottom = 2
		elif is_dead:
			style.bg_color = Color(0.15, 0.15, 0.15, 0.5)
		else:
			style.bg_color = Color(0.12, 0.12, 0.12, 0.8)

		panel.add_theme_stylebox_override("panel", style)

		var label := Label.new()
		var display_name: String = ref.get("name", entry.get("id", "???"))
		label.text = display_name

		if is_dead:
			label.modulate = COLOR_DEAD
		elif is_current:
			label.modulate = COLOR_ACTIVE
		else:
			label.modulate = COLOR_ALIVE

		panel.add_child(label)
		add_child(panel)
		_panels.append(panel)
