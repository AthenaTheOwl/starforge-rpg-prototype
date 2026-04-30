class_name HPBar
extends ProgressBar
## HPBar — Custom HP bar that changes color based on percentage.
##
## Automatically adjusts color based on health percentage:
## - Green (>70%), Yellow (30-70%), Red (<30%)
## Smoothly tweens value changes with 0.3s duration.
## Optional label overlay showing "HP: current/max".

signal value_changed_complete

@export var show_label := true
@export var label_format := "HP: %d/%d"

var _label: Label = null
var _tween: Tween = null


func _ready() -> void:
	if show_label:
		_create_label()
	_update_color()


func _create_label() -> void:
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.anchors_preset = Control.PRESET_FULL_RECT
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_update_label_text()


func _update_label_text() -> void:
	if _label:
		_label.text = label_format % [int(value), int(max_value)]


func _update_color() -> void:
	var percentage := value / max_value if max_value > 0 else 0.0
	var color: Color

	if percentage > 0.7:
		color = ThemeManager.COLOR_SUCCESS  # Green
	elif percentage > 0.3:
		color = ThemeManager.COLOR_WARNING  # Yellow
	else:
		color = ThemeManager.COLOR_DANGER  # Red

	# Create new stylebox with updated color
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = color
	fill_style.corner_radius_top_left = ThemeManager.CORNER_RADIUS
	fill_style.corner_radius_top_right = ThemeManager.CORNER_RADIUS
	fill_style.corner_radius_bottom_left = ThemeManager.CORNER_RADIUS
	fill_style.corner_radius_bottom_right = ThemeManager.CORNER_RADIUS
	add_theme_stylebox_override("fill", fill_style)


## Set HP value with smooth tween animation.
func set_hp(new_value: float, animate := true) -> void:
	if not animate:
		value = new_value
		_update_color()
		_update_label_text()
		return

	# Cancel existing tween
	if _tween:
		_tween.kill()

	_tween = create_tween()
	_tween.tween_property(self, "value", new_value, 0.3)
	_tween.tween_callback(_on_tween_complete)


## Set max HP and current value.
func set_hp_max(new_max: float, new_current: float = -1.0, animate := true) -> void:
	max_value = new_max
	if new_current >= 0:
		set_hp(new_current, animate)
	else:
		_update_color()
		_update_label_text()


func _on_tween_complete() -> void:
	_update_color()
	_update_label_text()
	value_changed_complete.emit()


## Override value setter to update color and label.
func _set(property: StringName, new_value: Variant) -> bool:
	if property == "value":
		# Let parent handle the actual value change
		var result := super._set(property, new_value)
		_update_color()
		_update_label_text()
		return result
	return false
