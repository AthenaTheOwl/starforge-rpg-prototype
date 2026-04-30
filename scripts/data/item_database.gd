class_name ItemDatabase
extends Node
## Item database — loads items from JSON and provides lookup methods.
##
## Can be used as an autoload or instantiated directly.

## All items keyed by id.
var _items: Dictionary = {}

const ITEMS_PATH := "res://data/items/items.json"


func _ready() -> void:
	load_items()


## Load all items from the JSON data file.
func load_items() -> void:
	_items.clear()
	if not FileAccess.file_exists(ITEMS_PATH):
		push_warning("ItemDatabase: items file not found at %s" % ITEMS_PATH)
		return
	var file := FileAccess.open(ITEMS_PATH, FileAccess.READ)
	if file == null:
		push_warning("ItemDatabase: could not open %s" % ITEMS_PATH)
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("ItemDatabase: JSON parse error in %s" % ITEMS_PATH)
		return
	var data: Dictionary = json.data
	var items_array: Array = data.get("items", [])
	for item_data in items_array:
		var eq: Equipment
		if item_data.get("is_relic", false):
			eq = RelicWeapon.from_dict(item_data)
		else:
			eq = Equipment.from_dict(item_data)
		_items[eq.id] = eq


## Get an item by id. Returns null if not found.
func get_item(id: String) -> Equipment:
	return _items.get(id, null)


## Get all items matching a slot type.
func get_items_by_slot(slot_type: Equipment.SlotType) -> Array[Equipment]:
	var result: Array[Equipment] = []
	for item in _items.values():
		if item.slot_type == slot_type:
			result.append(item)
	return result


## Get all items.
func get_all_items() -> Array[Equipment]:
	var result: Array[Equipment] = []
	for item in _items.values():
		result.append(item)
	return result


## Get starting equipment for a character by id.
func get_starting_equipment(character_id: String) -> Dictionary:
	var starting: Dictionary = {}
	var data_file := FileAccess.open(ITEMS_PATH, FileAccess.READ)
	if data_file == null:
		return starting
	var json := JSON.new()
	if json.parse(data_file.get_as_text()) != OK:
		return starting
	var data: Dictionary = json.data
	var assignments: Dictionary = data.get("starting_equipment", {})
	if character_id in assignments:
		var char_equip: Dictionary = assignments[character_id]
		for slot_name in char_equip:
			var item_id: String = char_equip[slot_name]
			if item_id in _items:
				starting[slot_name] = _items[item_id]
	return starting
