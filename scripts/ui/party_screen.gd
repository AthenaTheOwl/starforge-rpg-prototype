extends Control
## Party screen — roster management, character detail, equipment, inventory.
##
## Left panel: character roster with name, role, HP bar.
## Center panel: selected character detail (stats, loadout).
## Right panel: equipment and inventory.
## Bottom bar: back button, active party indicators.

# --- Node References (built in _ready) ---
var _roster_list: VBoxContainer
var _detail_panel: VBoxContainer
var _equipment_panel: EquipmentPanel
var _inventory_panel: InventoryPanel
var _active_party_bar: HBoxContainer
var _back_btn: Button

# --- State ---
var _selected_character_id: String = ""
var _item_db: ItemDatabase

# --- Detail sub-nodes ---
var _portrait_rect: ColorRect
var _name_label: Label
var _role_label: Label
var _stats_grid: GridContainer
var _loadout_container: VBoxContainer


func _ready() -> void:
	_item_db = ItemDatabase.new()
	add_child(_item_db)
	_build_ui()
	_populate_roster()
	# Select first character if available
	if not PartyManager.roster.is_empty():
		var first_id: String = PartyManager.roster.keys()[0]
		_select_character(first_id)


func _build_ui() -> void:
	# --- Background ---
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.1, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# --- Main layout: MarginContainer -> VBox(content + bottom bar) ---
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(outer_vbox)

	# Title
	var title := Label.new()
	title.text = "PARTY MANAGEMENT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer_vbox.add_child(title)

	var title_sep := HSeparator.new()
	outer_vbox.add_child(title_sep)

	# --- Content: HSplitContainer with 3 panels ---
	var hsplit := HBoxContainer.new()
	hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hsplit.add_theme_constant_override("separation", 15)
	outer_vbox.add_child(hsplit)

	# LEFT: Roster
	_build_roster_panel(hsplit)

	# Separator
	var vsep1 := VSeparator.new()
	hsplit.add_child(vsep1)

	# CENTER: Detail
	_build_detail_panel(hsplit)

	# Separator
	var vsep2 := VSeparator.new()
	hsplit.add_child(vsep2)

	# RIGHT: Equipment + Inventory
	_build_right_panel(hsplit)

	# --- Bottom bar ---
	var bottom_sep := HSeparator.new()
	outer_vbox.add_child(bottom_sep)
	_build_bottom_bar(outer_vbox)


func _build_roster_panel(parent: Control) -> void:
	var panel := VBoxContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 0.25
	panel.add_theme_constant_override("separation", 5)

	var lbl := Label.new()
	lbl.text = "ROSTER"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(lbl)

	var sep := HSeparator.new()
	panel.add_child(sep)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)

	_roster_list = VBoxContainer.new()
	_roster_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roster_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_roster_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_roster_list)

	parent.add_child(panel)


func _build_detail_panel(parent: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio = 0.4

	_detail_panel = VBoxContainer.new()
	_detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_panel.add_theme_constant_override("separation", 8)
	scroll.add_child(_detail_panel)

	# Portrait placeholder
	_portrait_rect = ColorRect.new()
	_portrait_rect.color = Color(0.15, 0.15, 0.2, 1.0)
	_portrait_rect.custom_minimum_size = Vector2(200, 200)
	_detail_panel.add_child(_portrait_rect)

	# Name
	_name_label = Label.new()
	_name_label.text = "Select a character"
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_panel.add_child(_name_label)

	# Role
	_role_label = Label.new()
	_role_label.text = ""
	_role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_panel.add_child(_role_label)

	# Stats
	var stats_sep := HSeparator.new()
	_detail_panel.add_child(stats_sep)

	var stats_title := Label.new()
	stats_title.text = "STATS"
	stats_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_panel.add_child(stats_title)

	_stats_grid = GridContainer.new()
	_stats_grid.columns = 2
	_stats_grid.add_theme_constant_override("h_separation", 20)
	_stats_grid.add_theme_constant_override("v_separation", 4)
	_detail_panel.add_child(_stats_grid)

	# Loadout
	var loadout_sep := HSeparator.new()
	_detail_panel.add_child(loadout_sep)

	var loadout_title := Label.new()
	loadout_title.text = "ABILITY LOADOUT"
	loadout_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_panel.add_child(loadout_title)

	_loadout_container = VBoxContainer.new()
	_loadout_container.add_theme_constant_override("separation", 4)
	_detail_panel.add_child(_loadout_container)

	parent.add_child(scroll)


func _build_right_panel(parent: Control) -> void:
	var panel := VBoxContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 0.35
	panel.add_theme_constant_override("separation", 10)

	# Equipment panel
	_equipment_panel = EquipmentPanel.new()
	_equipment_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_equipment_panel.slot_clicked.connect(_on_equipment_slot_clicked)
	panel.add_child(_equipment_panel)

	var sep := HSeparator.new()
	panel.add_child(sep)

	# Inventory panel
	_inventory_panel = InventoryPanel.new()
	_inventory_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inventory_panel.set_item_database(_item_db)
	_inventory_panel.item_selected.connect(_on_inventory_item_selected)
	panel.add_child(_inventory_panel)

	parent.add_child(panel)


func _build_bottom_bar(parent: Control) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 15)

	_back_btn = Button.new()
	_back_btn.text = "Back"
	_back_btn.custom_minimum_size = Vector2(100, 40)
	_back_btn.pressed.connect(_on_back_pressed)
	hbox.add_child(_back_btn)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	# Active party indicators
	var party_label := Label.new()
	party_label.text = "Active Party:"
	party_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(party_label)

	_active_party_bar = HBoxContainer.new()
	_active_party_bar.add_theme_constant_override("separation", 8)
	hbox.add_child(_active_party_bar)

	parent.add_child(hbox)
	_refresh_active_party_bar()


# --- Roster ---

func _populate_roster() -> void:
	for child in _roster_list.get_children():
		child.queue_free()

	for char_id in PartyManager.roster:
		var data: Dictionary = PartyManager.roster[char_id]
		var entry := _create_roster_entry(char_id, data)
		_roster_list.add_child(entry)


func _create_roster_entry(char_id: String, data: Dictionary) -> VBoxContainer:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 2)

	# Name + role row (clickable)
	var btn := Button.new()
	btn.text = "%s  —  %s" % [data.get("name", char_id), data.get("role", "")]
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(_select_character.bind(char_id))
	container.add_child(btn)

	# HP bar
	var hp_bar := ProgressBar.new()
	hp_bar.max_value = data.get("hp_max", 100)
	hp_bar.value = data.get("hp", data.get("hp_max", 100))
	hp_bar.custom_minimum_size = Vector2(0, 16)
	hp_bar.show_percentage = false
	container.add_child(hp_bar)

	# Active toggle
	var toggle := Button.new()
	var is_active: bool = char_id in PartyManager.active_party
	toggle.text = "Active" if is_active else "Reserve"
	toggle.toggle_mode = true
	toggle.button_pressed = is_active
	toggle.pressed.connect(_on_active_toggle.bind(char_id, toggle))
	container.add_child(toggle)

	var sep := HSeparator.new()
	container.add_child(sep)

	return container


# --- Character Selection ---

func _select_character(char_id: String) -> void:
	_selected_character_id = char_id
	var data: Dictionary = PartyManager.get_character(char_id)
	if data.is_empty():
		return
	_update_detail(data)
	_update_equipment(data)


func _update_detail(data: Dictionary) -> void:
	_name_label.text = data.get("name", "Unknown")
	_role_label.text = data.get("role", "")

	# Stats
	for child in _stats_grid.get_children():
		child.queue_free()

	var stats := [
		["HP", "%d / %d" % [data.get("hp", 0), data.get("hp_max", 100)]],
		["Speed", str(data.get("speed", 0))],
		["Armor", str(data.get("armor", 0))],
		["Shields", str(data.get("shields", 0))],
		["Wards", str(data.get("wards", 0))],
		["Heat", str(data.get("heat", 0))],
		["Lattice Affinity", str(data.get("lattice_affinity", 0))],
		["Trust", str(data.get("trust", 50))],
	]

	for stat_pair in stats:
		var name_lbl := Label.new()
		name_lbl.text = stat_pair[0] + ":"
		_stats_grid.add_child(name_lbl)
		var val_lbl := Label.new()
		val_lbl.text = stat_pair[1]
		_stats_grid.add_child(val_lbl)

	# Loadout (6 ability slots)
	for child in _loadout_container.get_children():
		child.queue_free()

	var slot_labels := {
		"core_1": "Core 1",
		"core_2": "Core 2",
		"utility_1": "Utility 1",
		"utility_2": "Utility 2",
		"reaction": "Reaction",
		"keystone": "Keystone",
	}

	var abilities: Array = data.get("ability_slots", data.get("abilities", []))
	var abilities_by_slot: Dictionary = {}
	for ability in abilities:
		var slot: String = ability.get("slot", "")
		abilities_by_slot[slot] = ability

	for slot_key in slot_labels:
		var hbox := HBoxContainer.new()
		var slot_lbl := Label.new()
		slot_lbl.text = slot_labels[slot_key] + ":"
		slot_lbl.custom_minimum_size = Vector2(80, 0)
		hbox.add_child(slot_lbl)

		var ability_lbl := Label.new()
		if slot_key in abilities_by_slot:
			var ab: Dictionary = abilities_by_slot[slot_key]
			ability_lbl.text = ab.get("name", "—")
		else:
			ability_lbl.text = "— Empty —"
		hbox.add_child(ability_lbl)
		_loadout_container.add_child(hbox)


func _update_equipment(data: Dictionary) -> void:
	# Try to load starting equipment if character has no equipment dict yet
	if not data.has("equipment"):
		var starting := _item_db.get_starting_equipment(data.get("id", ""))
		if not starting.is_empty():
			var equip_dict: Dictionary = {}
			for slot_name in starting:
				equip_dict[slot_name] = starting[slot_name].to_dict()
			data["equipment"] = equip_dict
	_equipment_panel.load_character_equipment(data)


# --- Active Party Toggle ---

func _on_active_toggle(char_id: String, btn: Button) -> void:
	if char_id in PartyManager.active_party:
		PartyManager.remove_from_active(char_id)
		btn.text = "Reserve"
		btn.button_pressed = false
	else:
		if PartyManager.active_party.size() < PartyManager.MAX_ACTIVE:
			PartyManager.add_to_active(char_id)
			btn.text = "Active"
			btn.button_pressed = true
		else:
			btn.button_pressed = false
	_refresh_active_party_bar()


func _refresh_active_party_bar() -> void:
	for child in _active_party_bar.get_children():
		child.queue_free()

	for i in PartyManager.MAX_ACTIVE:
		var indicator := ColorRect.new()
		indicator.custom_minimum_size = Vector2(40, 30)
		if i < PartyManager.active_party.size():
			indicator.color = Color(0.2, 0.6, 0.3, 1.0)
			var char_data: Dictionary = PartyManager.get_character(PartyManager.active_party[i])
			indicator.tooltip_text = char_data.get("name", "")
		else:
			indicator.color = Color(0.2, 0.2, 0.25, 1.0)
		_active_party_bar.add_child(indicator)


# --- Equipment / Inventory Interaction ---

## Tracks which equipment slot we're filling from inventory.
var _pending_equip_slot: String = ""


func _on_equipment_slot_clicked(slot_name: String) -> void:
	_pending_equip_slot = slot_name
	# Map slot name to Equipment.SlotType
	var slot_map: Dictionary = {
		"primary_weapon": Equipment.SlotType.PRIMARY_WEAPON,
		"secondary_weapon": Equipment.SlotType.SECONDARY_WEAPON,
		"armor": Equipment.SlotType.ARMOR,
		"shield_gen": Equipment.SlotType.SHIELD_GEN,
		"ward_focus": Equipment.SlotType.WARD_FOCUS,
		"accessory_1": Equipment.SlotType.ACCESSORY,
		"accessory_2": Equipment.SlotType.ACCESSORY,
	}
	if slot_name in slot_map:
		_inventory_panel.open_for_slot(slot_map[slot_name])


func _on_inventory_item_selected(item: Equipment) -> void:
	if _pending_equip_slot.is_empty():
		return
	# Show comparison
	_equipment_panel.show_comparison(_pending_equip_slot, item)
	# Equip on selection
	_equipment_panel.equip_item(_pending_equip_slot, item)
	# Save to character data
	if _selected_character_id != "":
		var data: Dictionary = PartyManager.get_character(_selected_character_id)
		if not data.is_empty():
			data["equipment"] = _equipment_panel.get_all_equipped()
	_pending_equip_slot = ""


# --- Navigation ---

func _on_back_pressed() -> void:
	GameManager.transition_to_exploration()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
