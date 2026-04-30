class_name DamageNumber
extends Label
## DamageNumber — Floating damage text that rises and fades out.
##
## Use the static spawn() factory to create and add to the scene tree.

const TYPE_COLORS := {
	"physical": Color(1.0, 1.0, 1.0),
	"thermal": Color(1.0, 0.6, 0.1),
	"shock": Color(0.3, 0.9, 1.0),
	"resonance": Color(0.7, 0.3, 1.0),
	"heal": Color(0.3, 1.0, 0.4),
}

const RISE_DISTANCE := 40.0
const DURATION := 0.8
const CRIT_SCALE := 1.5


## Create a DamageNumber, configure it, and return it. Caller must add_child().
static func spawn(amount: int, damage_type: String, pos: Vector2, is_crit: bool) -> DamageNumber:
	var dn := DamageNumber.new()
	dn.text = str(amount) if damage_type != "heal" else "+%d" % amount
	if is_crit:
		dn.text += "!"

	dn.position = pos
	dn.z_index = 100
	dn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var color: Color = TYPE_COLORS.get(damage_type, Color.WHITE)
	dn.modulate = color

	if is_crit:
		dn.scale = Vector2(CRIT_SCALE, CRIT_SCALE)

	# Add font size override for visibility.
	dn.add_theme_font_size_override("font_size", 18 if not is_crit else 24)

	dn._start_tween()
	return dn


func _start_tween() -> void:
	## Must be called after node enters tree — deferred.
	ready.connect(_do_tween, CONNECT_ONE_SHOT)


func _do_tween() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - RISE_DISTANCE, DURATION)
	tween.tween_property(self, "modulate:a", 0.0, DURATION)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
