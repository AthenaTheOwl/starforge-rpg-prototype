class_name PortraitDisplay
extends TextureRect
## PortraitDisplay — Shows character portrait or colored silhouette placeholder.
##
## Generates placeholder silhouettes with character initials when no portrait
## art exists. Supports left/right positioning for NPC vs player portraits.

const CHARACTER_COLORS: Dictionary = {
	"elia": Color(0.27, 0.51, 0.71),       # Steel blue
	"elisira": Color(0.30, 0.0, 0.51),      # Deep purple
	"vesper": Color(0.85, 0.65, 0.13),      # Warm amber
	"rho": Color(0.55, 0.09, 0.09),         # Dark red
	"nyx": Color(0.75, 0.75, 0.80),         # Silver
	"jalen": Color(0.0, 0.50, 0.50),        # Teal
	"avyanna": Color(0.85, 0.65, 0.13),     # Gold
}

const PORTRAIT_SIZE := Vector2i(128, 160)

var _current_character: String = ""
var _current_expression: String = "neutral"
var _side: String = "left"  # "left" or "right"


func _ready() -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	custom_minimum_size = Vector2(PORTRAIT_SIZE)


func set_character(id: String, expression: String = "neutral") -> void:
	_current_character = id.to_lower()
	_current_expression = expression
	visible = not id.is_empty()
	if id.is_empty():
		texture = null
		return
	# Try to load real portrait
	var path := "res://assets/portraits/%s_%s.png" % [_current_character, expression]
	if ResourceLoader.exists(path):
		texture = load(path)
		return
	# Fallback: try default expression
	var default_path := "res://assets/portraits/%s_neutral.png" % _current_character
	if ResourceLoader.exists(default_path):
		texture = load(default_path)
		return
	# Generate placeholder silhouette
	texture = _generate_placeholder(_current_character)


func set_side(side: String) -> void:
	_side = side
	if side == "right":
		flip_h = true
	else:
		flip_h = false


func _generate_placeholder(character_id: String) -> ImageTexture:
	var color: Color = CHARACTER_COLORS.get(character_id, Color(0.4, 0.4, 0.4))
	var img := Image.create(PORTRAIT_SIZE.x, PORTRAIT_SIZE.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# Draw silhouette body (rounded rectangle area)
	var body_color := color
	var dark_color := color.darkened(0.4)
	for y in range(PORTRAIT_SIZE.y):
		for x in range(PORTRAIT_SIZE.x):
			var nx := float(x) / PORTRAIT_SIZE.x
			var ny := float(y) / PORTRAIT_SIZE.y
			# Head area (oval in top third)
			var head_cx := 0.5
			var head_cy := 0.25
			var head_rx := 0.22
			var head_ry := 0.18
			var head_dist := pow((nx - head_cx) / head_rx, 2) + pow((ny - head_cy) / head_ry, 2)
			# Shoulders/body area (trapezoid in lower portion)
			var in_body: bool = ny > 0.5 and abs(nx - 0.5) < (0.15 + (ny - 0.5) * 0.6)
			if head_dist <= 1.0:
				img.set_pixel(x, y, body_color)
			elif in_body:
				img.set_pixel(x, y, dark_color)

	# Draw initial letter using simple pixel patterns
	var initial := character_id.left(1).to_upper()
	_draw_initial(img, initial, Color.WHITE)

	return ImageTexture.create_from_image(img)


func _draw_initial(img: Image, letter: String, color: Color) -> void:
	# Draw a simple large letter in the head area as identification
	# Using a basic 5x7 pixel font scaled up, centered on the silhouette chest
	var cx: int = PORTRAIT_SIZE.x / 2
	var cy: int = int(PORTRAIT_SIZE.y * 0.7)
	var scale: int = 3

	# Simple bitmap representations for common initials
	var patterns: Dictionary = {
		"E": [0x1F, 0x10, 0x1E, 0x10, 0x1F],
		"V": [0x11, 0x11, 0x0A, 0x0A, 0x04],
		"R": [0x1E, 0x11, 0x1E, 0x14, 0x11],
		"N": [0x11, 0x19, 0x15, 0x13, 0x11],
		"J": [0x0F, 0x02, 0x02, 0x12, 0x0C],
		"A": [0x0E, 0x11, 0x1F, 0x11, 0x11],
	}

	var pattern: Array = patterns.get(letter, [0x1F, 0x11, 0x11, 0x11, 0x1F])
	var pw := 5
	var ph := pattern.size()
	var ox: int = cx - (pw * scale) / 2
	var oy: int = cy - (ph * scale) / 2

	for row in ph:
		var bits: int = pattern[row]
		for col in pw:
			if bits & (1 << (pw - 1 - col)):
				for sy in scale:
					for sx in scale:
						var px: int = ox + col * scale + sx
						var py: int = oy + row * scale + sy
						if px >= 0 and px < PORTRAIT_SIZE.x and py >= 0 and py < PORTRAIT_SIZE.y:
							img.set_pixel(px, py, color)
