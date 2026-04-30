class_name HexTile
extends Area2D
## A single hex tile on the grid. Flat-top orientation.

enum Terrain { PLAINS, FOREST, MOUNTAIN, WATER }

const TERRAIN_COLORS := {
	Terrain.PLAINS: Color(0.35, 0.65, 0.25),
	Terrain.FOREST: Color(0.15, 0.4, 0.12),
	Terrain.MOUNTAIN: Color(0.55, 0.55, 0.55),
	Terrain.WATER: Color(0.2, 0.35, 0.7),
}

signal clicked(coords: Vector2i)

var coords := Vector2i.ZERO
var terrain: Terrain = Terrain.PLAINS

var _polygon: Polygon2D
var _highlight: Polygon2D
var _collision: CollisionPolygon2D


func setup(hex_coords: Vector2i, hex_size: float, hex_terrain: Terrain = Terrain.PLAINS) -> void:
	coords = hex_coords
	terrain = hex_terrain
	position = HexUtils.hex_to_pixel(coords, hex_size)

	var points := HexUtils.flat_top_hex_points(hex_size)

	_polygon = Polygon2D.new()
	_polygon.polygon = points
	_polygon.color = TERRAIN_COLORS[terrain]
	add_child(_polygon)

	_highlight = Polygon2D.new()
	_highlight.polygon = points
	_highlight.color = Color(1, 1, 1, 0)
	add_child(_highlight)

	_collision = CollisionPolygon2D.new()
	_collision.polygon = points
	add_child(_collision)

	input_event.connect(_on_input_event)


func set_highlight(color: Color) -> void:
	if _highlight:
		_highlight.color = color


func clear_highlight() -> void:
	set_highlight(Color(1, 1, 1, 0))


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(coords)
