extends Node2D
## Temporary test harness for hex grid. Remove after verification.

@onready var hex_grid: HexGrid = $HexGrid


func _ready() -> void:
	hex_grid.hex_tile_clicked.connect(_on_hex_clicked)


func _on_hex_clicked(coords: Vector2i) -> void:
	print("Hex clicked: %s" % coords)
	hex_grid.clear_highlights()
	var neighbors := HexUtils.hex_neighbors(coords)
	var typed_neighbors: Array[Vector2i] = []
	for n in neighbors:
		typed_neighbors.append(n)
	hex_grid.highlight_hexes(typed_neighbors, Color(1, 1, 0, 0.3))
