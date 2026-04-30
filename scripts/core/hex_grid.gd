class_name HexGrid
extends Node2D
## Generates and manages a hex tile grid.

signal hex_tile_clicked(coords: Vector2i)

@export var grid_width := 20
@export var grid_height := 15
@export var hex_size := 40.0

var _tiles: Dictionary = {}  # Vector2i -> HexTile


func _ready() -> void:
	generate_grid()


func generate_grid() -> void:
	# Clear existing tiles
	for child in get_children():
		child.queue_free()
	_tiles.clear()

	for q in grid_width:
		for r in grid_height:
			var coords := Vector2i(q, r)
			var tile := HexTile.new()
			var terrain := _pick_terrain(coords)
			tile.setup(coords, hex_size, terrain)
			tile.clicked.connect(_on_tile_clicked)
			add_child(tile)
			_tiles[coords] = tile


func get_tile(coords: Vector2i) -> HexTile:
	return _tiles.get(coords)


func highlight_hexes(hex_list: Array[Vector2i], color := Color(1, 1, 1, 0.3)) -> void:
	for coords in hex_list:
		var tile := get_tile(coords)
		if tile:
			tile.set_highlight(color)


func clear_highlights() -> void:
	for tile: HexTile in _tiles.values():
		tile.clear_highlight()


func _on_tile_clicked(coords: Vector2i) -> void:
	hex_tile_clicked.emit(coords)


func _pick_terrain(coords: Vector2i) -> HexTile.Terrain:
	# Simple deterministic terrain assignment for now
	var hash_val := (coords.x * 374761 + coords.y * 668265) % 100
	if hash_val < 0:
		hash_val += 100
	if hash_val < 50:
		return HexTile.Terrain.PLAINS
	elif hash_val < 75:
		return HexTile.Terrain.FOREST
	elif hash_val < 90:
		return HexTile.Terrain.MOUNTAIN
	else:
		return HexTile.Terrain.WATER
