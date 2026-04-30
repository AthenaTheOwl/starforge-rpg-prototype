class_name LocationGraph
extends RefCounted
## LocationGraph — Loads and queries the location graph from JSON.
##
## Provides lookup by location ID, connection traversal, and tag-based filtering.

var _locations: Dictionary = {}


func _init(json_path: String = "res://data/act1_location_graph.json") -> void:
	_load(json_path)


func _load(json_path: String) -> void:
	if not FileAccess.file_exists(json_path):
		push_warning("LocationGraph: file not found: %s" % json_path)
		return
	var file := FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		push_warning("LocationGraph: cannot open %s" % json_path)
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("LocationGraph: parse error in %s" % json_path)
		return
	var data: Dictionary = json.data
	_locations = data.get("locations", {})


func get_location(id: String) -> Dictionary:
	return _locations.get(id, {})


func get_connections(id: String) -> Array[String]:
	var loc := get_location(id)
	var raw: Array = loc.get("connections", [])
	var result: Array[String] = []
	for c in raw:
		result.append(str(c))
	return result


func get_locations_with_tag(tag: String) -> Array[String]:
	var result: Array[String] = []
	for id in _locations:
		var loc: Dictionary = _locations[id]
		var tags: Array = loc.get("tags", [])
		if tag in tags:
			result.append(str(id))
	return result


func get_all_location_ids() -> Array[String]:
	var result: Array[String] = []
	for id in _locations:
		result.append(str(id))
	return result
