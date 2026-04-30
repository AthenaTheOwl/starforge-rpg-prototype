class_name StatusIcon
extends PanelContainer
## StatusIcon — Small colored rectangle with status abbreviation.
##
## Shows category-based color, abbreviation, tooltip with full details,
## and a pulse animation when first applied.

const CATEGORY_COLORS := {
	"control": Color(1.0, 0.9, 0.2),
	"dot": Color(1.0, 0.3, 0.2),
	"special": Color(0.7, 0.3, 1.0),
	"buff": Color(0.3, 1.0, 0.4),
}

## Map StatusEffect.Category enum to string keys.
const CATEGORY_MAP := {
	StatusEffect.Category.CONTROL: "control",
	StatusEffect.Category.DOT: "dot",
	StatusEffect.Category.SPECIAL: "special",
}

var _label: Label
var _status_id: String = ""
var _duration: int = 0


func _ready() -> void:
	custom_minimum_size = Vector2(32, 24)


## Configure from a StatusEffect instance or a Dictionary with matching keys.
func setup(status: Variant) -> void:
	var display_name: String = ""
	var category_str: String = "special"
	var description: String = ""

	if status is StatusEffect:
		var se: StatusEffect = status
		_status_id = se.id
		display_name = se.display_name
		_duration = se.duration
		category_str = CATEGORY_MAP.get(se.category, "special")
		description = _build_description_from_effect(se)
	elif status is Dictionary:
		_status_id = status.get("id", status.get("name", ""))
		display_name = status.get("display_name", status.get("name", _status_id))
		_duration = status.get("duration", 0)
		category_str = status.get("category", "special")
		description = status.get("description", "")

	# Build style
	var style := StyleBoxFlat.new()
	var color: Color = CATEGORY_COLORS.get(category_str, Color(0.5, 0.5, 0.5))
	style.bg_color = Color(color, 0.3)
	style.border_color = color
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.set_corner_radius_all(3)
	style.content_margin_left = 2.0
	style.content_margin_right = 2.0
	style.content_margin_top = 1.0
	style.content_margin_bottom = 1.0
	add_theme_stylebox_override("panel", style)

	# Abbreviation label
	_label = Label.new()
	_label.text = _abbreviate(display_name)
	_label.modulate = color
	_label.add_theme_font_size_override("font_size", 11)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)

	# Tooltip
	var dur_text: String = "inf" if _duration < 0 else "%d rnd" % _duration
	tooltip_text = "%s (%s)\n%s" % [display_name, dur_text, description]

	# Pulse animation on apply
	_pulse()


func _abbreviate(name: String) -> String:
	if name.length() <= 3:
		return name.to_upper()
	# Take first 3 consonant-vowel chars
	return name.substr(0, 3).to_upper()


func _pulse() -> void:
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.15)
	tween.tween_property(self, "modulate:a", 0.6, 0.15)
	tween.tween_property(self, "modulate:a", 1.0, 0.15)


func _build_description_from_effect(se: StatusEffect) -> String:
	var parts: PackedStringArray = []
	if se.prevents_action:
		parts.append("Prevents actions")
	if se.prevents_movement:
		parts.append("Prevents movement")
	if se.prevents_casting:
		parts.append("Prevents casting")
	if se.dot_damage > 0:
		parts.append("%d %s damage/round" % [se.dot_damage, se.dot_type])
	for key in se.stat_modifiers:
		parts.append("%s: %s" % [key, str(se.stat_modifiers[key])])
	if parts.is_empty():
		return "Active effect."
	return ", ".join(parts)
