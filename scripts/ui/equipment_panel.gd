class_name EquipmentPanel
extends VBoxContainer
## Equipment panel — displays and manages a character's equipment slots.
##
## Slots: primary_weapon, secondary_weapon, armor, shield_gen, ward_focus,
##        accessory_1, accessory_2

signal slot_clicked(slot_name: String)
signal item_unequipped(slot_name: String, item: Equipment)

const SLOT_NAMES: Array[String] = [
	"primary_weapon",
	"secondary_weapon",
	"armor",
	"shield_gen",
	"ward_focus",
	"accessory_1",
	"accessory_2",
]

const SLOT_LABELS: Dictionary = {
	"primary_weapon": "Primary Weapon",
	"secondary_weapon": "Secondary Weapon",
	"armor": "Armor",
	"shield_gen": "Shield Generator",
	"ward_focus": "Ward Focus",
	"accessory_1": "Accessory 1",
	"accessory_2": "Accessory 2",
}

## Character's equipped items: slot_name -> Equipment (or null).
var _equipped: Dictionary = {}

## Slot buttons keyed by slot_name.
var _slot_buttons: Dictionary = {}

## Tooltip label for stat comparison.
var _tooltip_label: RichTextLabel


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	# Title
	var title := Label.new()
	title.text = "EQUIPMENT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var sep := HSeparator.new()
	add_child(sep)

	for slot_name in SLOT_NAMES:
		var hbox := HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var lbl := Label.new()
		lbl.text = SLOT_LABELS.get(slot_name, slot_name)
		lbl.custom_minimum_size = Vector2(140, 0)
		hbox.add_child(lbl)

		var btn := Button.new()
		btn.text = "[ Empty ]"
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_slot_pressed.bind(slot_name))
		btn.mouse_entered.connect(_on_slot_hover.bind(slot_name))
		btn.mouse_exited.connect(_on_slot_hover_end)
		hbox.add_child(btn)

		var unequip_btn := Button.new()
		unequip_btn.text = "X"
		unequip_btn.custom_minimum_size = Vector2(30, 0)
		unequip_btn.pressed.connect(_on_unequip_pressed.bind(slot_name))
		hbox.add_child(unequip_btn)

		add_child(hbox)
		_slot_buttons[slot_name] = btn

	# Tooltip area
	var tooltip_sep := HSeparator.new()
	add_child(tooltip_sep)
	_tooltip_label = RichTextLabel.new()
	_tooltip_label.bbcode_enabled = true
	_tooltip_label.fit_content = true
	_tooltip_label.custom_minimum_size = Vector2(0, 60)
	_tooltip_label.text = ""
	add_child(_tooltip_label)


## Load equipment from a character data dictionary.
func load_character_equipment(character_data: Dictionary) -> void:
	_equipped.clear()
	var equip_data: Dictionary = character_data.get("equipment", {})
	for slot_name in SLOT_NAMES:
		if slot_name in equip_data and equip_data[slot_name] is Dictionary:
			_equipped[slot_name] = Equipment.from_dict(equip_data[slot_name])
		else:
			_equipped[slot_name] = null
	_refresh_buttons()


## Equip an item to a slot.
func equip_item(slot_name: String, item: Equipment) -> void:
	_equipped[slot_name] = item
	_refresh_buttons()


## Unequip an item from a slot. Returns the removed item or null.
func unequip_item(slot_name: String) -> Equipment:
	var item: Equipment = _equipped.get(slot_name, null)
	_equipped[slot_name] = null
	_refresh_buttons()
	return item


## Get the currently equipped item in a slot.
func get_equipped(slot_name: String) -> Equipment:
	return _equipped.get(slot_name, null)


## Get all equipped items as a dictionary for serialization.
func get_all_equipped() -> Dictionary:
	var result: Dictionary = {}
	for slot_name in SLOT_NAMES:
		if _equipped.get(slot_name) != null:
			result[slot_name] = _equipped[slot_name].to_dict()
	return result


## Show stat comparison between current equipment and a candidate item.
func show_comparison(slot_name: String, candidate: Equipment) -> void:
	var current: Equipment = _equipped.get(slot_name, null)
	var text := "[b]%s[/b]\n" % candidate.name
	for stat in candidate.stat_modifiers:
		var new_val: int = candidate.stat_modifiers[stat]
		var old_val: int = 0
		if current and stat in current.stat_modifiers:
			old_val = current.stat_modifiers[stat]
		var diff: int = new_val - old_val
		if diff > 0:
			text += "[color=green]+%d %s[/color]\n" % [diff, stat]
		elif diff < 0:
			text += "[color=red]%d %s[/color]\n" % [diff, stat]
		else:
			text += "%d %s\n" % [new_val, stat]
	_tooltip_label.text = text


func _refresh_buttons() -> void:
	for slot_name in SLOT_NAMES:
		var btn: Button = _slot_buttons.get(slot_name)
		if btn == null:
			continue
		var item: Equipment = _equipped.get(slot_name, null)
		if item != null:
			btn.text = item.name
		else:
			btn.text = "[ Empty ]"


func _on_slot_pressed(slot_name: String) -> void:
	slot_clicked.emit(slot_name)


func _on_unequip_pressed(slot_name: String) -> void:
	var item := unequip_item(slot_name)
	if item != null:
		item_unequipped.emit(slot_name, item)


func _on_slot_hover(slot_name: String) -> void:
	var item: Equipment = _equipped.get(slot_name, null)
	if item != null:
		var text := "[b]%s[/b]\n%s" % [item.name, item.description]
		if not item.lore_text.is_empty():
			text += "\n[i]%s[/i]" % item.lore_text
		for stat in item.stat_modifiers:
			var val: int = item.stat_modifiers[stat]
			if val > 0:
				text += "\n[color=green]+%d %s[/color]" % [val, stat]
			elif val < 0:
				text += "\n[color=red]%d %s[/color]" % [val, stat]
		_tooltip_label.text = text
	else:
		_tooltip_label.text = SLOT_LABELS.get(slot_name, slot_name) + " — Empty"


func _on_slot_hover_end() -> void:
	_tooltip_label.text = ""
