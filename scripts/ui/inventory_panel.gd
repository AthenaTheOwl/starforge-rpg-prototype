class_name InventoryPanel
extends VBoxContainer
## Inventory panel — category tabs, item list, tooltips, equip/use/discard.

signal item_selected(item: Equipment)

enum Category { WEAPONS, ARMOR, CONSUMABLES, KEY_ITEMS, MATERIALS }

const CATEGORY_NAMES: Array[String] = [
	"Weapons", "Armor", "Consumables", "Key Items", "Materials",
]

## Slot type filter when opened from equipment panel. -1 = no filter.
var _filter_slot: int = -1

## Current category tab.
var _current_category: Category = Category.WEAPONS

## All available items (simplified: Array of Equipment for now).
var _items: Array[Equipment] = []

## Item database reference.
var _item_db: ItemDatabase

## UI elements.
var _tab_bar: HBoxContainer
var _item_list: VBoxContainer
var _item_scroll: ScrollContainer
var _tooltip_label: RichTextLabel
var _action_bar: HBoxContainer


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	# Title
	var title := Label.new()
	title.text = "INVENTORY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var sep := HSeparator.new()
	add_child(sep)

	# Category tabs
	_tab_bar = HBoxContainer.new()
	_tab_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in CATEGORY_NAMES.size():
		var btn := Button.new()
		btn.text = CATEGORY_NAMES[i]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.toggle_mode = true
		btn.button_pressed = (i == 0)
		btn.pressed.connect(_on_tab_pressed.bind(i))
		_tab_bar.add_child(btn)
	add_child(_tab_bar)

	# Item list scroll
	_item_scroll = ScrollContainer.new()
	_item_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_item_scroll.custom_minimum_size = Vector2(0, 200)
	add_child(_item_scroll)

	_item_list = VBoxContainer.new()
	_item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_item_scroll.add_child(_item_list)

	# Tooltip
	var tooltip_sep := HSeparator.new()
	add_child(tooltip_sep)
	_tooltip_label = RichTextLabel.new()
	_tooltip_label.bbcode_enabled = true
	_tooltip_label.fit_content = true
	_tooltip_label.custom_minimum_size = Vector2(0, 80)
	_tooltip_label.text = "Hover over an item for details."
	add_child(_tooltip_label)

	# Action bar
	_action_bar = HBoxContainer.new()
	_action_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var equip_btn := Button.new()
	equip_btn.text = "Equip"
	equip_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equip_btn.pressed.connect(_on_equip_pressed)
	_action_bar.add_child(equip_btn)

	var discard_btn := Button.new()
	discard_btn.text = "Discard"
	discard_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	discard_btn.pressed.connect(_on_discard_pressed)
	_action_bar.add_child(discard_btn)
	add_child(_action_bar)


## Set the item database reference.
func set_item_database(db: ItemDatabase) -> void:
	_item_db = db
	refresh()


## Open with a slot filter (from equipment panel click).
func open_for_slot(slot_type: Equipment.SlotType) -> void:
	_filter_slot = slot_type
	# Switch to appropriate category
	match slot_type:
		Equipment.SlotType.PRIMARY_WEAPON, Equipment.SlotType.SECONDARY_WEAPON:
			_current_category = Category.WEAPONS
		Equipment.SlotType.ARMOR:
			_current_category = Category.ARMOR
		_:
			_current_category = Category.WEAPONS
	_update_tabs()
	refresh()


## Clear slot filter.
func clear_filter() -> void:
	_filter_slot = -1
	refresh()


## Refresh the item list based on current category and filter.
func refresh() -> void:
	# Clear existing
	for child in _item_list.get_children():
		child.queue_free()

	if _item_db == null:
		return

	var items: Array[Equipment]
	if _filter_slot >= 0:
		items = _item_db.get_items_by_slot(_filter_slot as Equipment.SlotType)
	else:
		items = _get_items_for_category(_current_category)

	_items = items

	for item in items:
		var btn := Button.new()
		btn.text = item.name
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_item_clicked.bind(item))
		btn.mouse_entered.connect(_on_item_hover.bind(item))
		btn.mouse_exited.connect(_on_item_hover_end)
		_item_list.add_child(btn)


func _get_items_for_category(cat: Category) -> Array[Equipment]:
	if _item_db == null:
		return []
	var all := _item_db.get_all_items()
	var result: Array[Equipment] = []
	for item in all:
		match cat:
			Category.WEAPONS:
				if item.slot_type == Equipment.SlotType.PRIMARY_WEAPON or \
					item.slot_type == Equipment.SlotType.SECONDARY_WEAPON:
					result.append(item)
			Category.ARMOR:
				if item.slot_type == Equipment.SlotType.ARMOR or \
					item.slot_type == Equipment.SlotType.SHIELD_GEN or \
					item.slot_type == Equipment.SlotType.WARD_FOCUS:
					result.append(item)
			_:
				pass  # Consumables, Key Items, Materials — future implementation
	return result


var _selected_item: Equipment = null


func _on_item_clicked(item: Equipment) -> void:
	_selected_item = item
	item_selected.emit(item)


func _on_item_hover(item: Equipment) -> void:
	var text := "[b]%s[/b]\n%s" % [item.name, item.description]
	if not item.lore_text.is_empty():
		text += "\n[i]%s[/i]" % item.lore_text
	for stat in item.stat_modifiers:
		var val: int = item.stat_modifiers[stat]
		if val > 0:
			text += "\n[color=green]+%d %s[/color]" % [val, stat]
		elif val < 0:
			text += "\n[color=red]%d %s[/color]" % [val, stat]
	if item.is_runed:
		text += "\n[color=cyan]RUNED[/color]"
	if item.is_relic:
		text += "\n[color=gold]RELIC[/color]"
		if not item.relic_lore.is_empty():
			text += "\n[i]%s[/i]" % item.relic_lore
	_tooltip_label.text = text


func _on_item_hover_end() -> void:
	_tooltip_label.text = "Hover over an item for details."


func _on_equip_pressed() -> void:
	if _selected_item != null:
		item_selected.emit(_selected_item)


func _on_discard_pressed() -> void:
	# TODO: Implement discard with confirmation
	pass


func _on_tab_pressed(index: int) -> void:
	_current_category = index as Category
	_filter_slot = -1
	_update_tabs()
	refresh()


func _update_tabs() -> void:
	for i in _tab_bar.get_child_count():
		var btn: Button = _tab_bar.get_child(i)
		btn.button_pressed = (i == _current_category)
