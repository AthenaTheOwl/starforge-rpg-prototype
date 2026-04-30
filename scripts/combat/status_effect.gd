class_name StatusEffect
extends RefCounted
## StatusEffect — Data-driven status effect with tick, expiry, and stat modification.
##
## Categories:
##   Control : Silenced, Jammed, Bound, Blinded, Grounded
##   DoT     : Bleeding, Burning, Corroding, Shocked
##   Special : Marked, ResonanceDrain, GhostTouch

enum Category { CONTROL, DOT, SPECIAL }

## Unique effect identifier (e.g. "silenced", "bleeding").
var id: String = ""
## Human-readable label.
var display_name: String = ""
var category: Category = Category.CONTROL
## Remaining duration in rounds.  -1 = until cleansed.
var duration: int = 1
## Damage per tick (DoT effects).
var dot_damage: int = 0
## Damage type for DoT.
var dot_type: String = "physical"
## Stat modifier dictionary: { "accuracy": -0.5, "spell_cost_mult": 1.4, ... }
var stat_modifiers: Dictionary = {}
## Whether the target can still act (movement / attacks).
var prevents_action: bool = false
## Whether the target can move.
var prevents_movement: bool = false
## Whether the target can cast spells.
var prevents_casting: bool = false
## Tags used by the cleanse / counter system.
var tags: Array[String] = []
## Extra data bucket for effect-specific logic.
var extra: Dictionary = {}


# ---------------------------------------------------------------------------
# Factory helpers — create pre-configured effects matching the spec.
# ---------------------------------------------------------------------------

static func create(effect_id: String, override_duration: int = -99) -> StatusEffect:
	var e := StatusEffect.new()
	e.id = effect_id

	match effect_id:
		# --- Control ---
		"silenced":
			e.display_name = "Silenced"
			e.category = Category.CONTROL
			e.duration = 6
			e.prevents_casting = true
			e.tags = ["control", "magic"]
		"jammed":
			e.display_name = "Jammed"
			e.category = Category.CONTROL
			e.duration = 9
			e.tags = ["control", "tech"]
		"bound":
			e.display_name = "Bound"
			e.category = Category.CONTROL
			e.duration = 5
			e.prevents_movement = true
			e.tags = ["control", "movement"]
		"blinded":
			e.display_name = "Blinded"
			e.category = Category.CONTROL
			e.duration = 4
			e.stat_modifiers = { "accuracy": -0.5 }
			e.tags = ["control", "sight"]
		"grounded":
			e.display_name = "Grounded"
			e.category = Category.CONTROL
			e.duration = 11
			e.stat_modifiers = { "spell_efficacy": -0.4 }
			e.tags = ["control", "magic"]

		# --- DoT ---
		"bleeding":
			e.display_name = "Bleeding"
			e.category = Category.DOT
			e.duration = -1  # until stabilised
			e.dot_damage = 3
			e.dot_type = "physical"
			e.tags = ["dot", "physical"]
			e.extra = { "movement_worsens": true }
		"burning":
			e.display_name = "Burning"
			e.category = Category.DOT
			e.duration = 6
			e.dot_damage = 4
			e.dot_type = "thermal"
			e.tags = ["dot", "thermal"]
			e.extra = { "spreads": true }
		"corroding":
			e.display_name = "Corroding"
			e.category = Category.DOT
			e.duration = 8
			e.dot_damage = 0
			e.dot_type = "physical"
			e.tags = ["dot", "armor"]
			e.extra = { "armor_degrade_per_tick": 2 }
		"shocked":
			e.display_name = "Shocked"
			e.category = Category.DOT
			e.duration = 4
			e.dot_damage = 2
			e.dot_type = "shock"
			e.tags = ["dot", "shock"]
			e.extra = { "stun_chance": 0.35 }

		# --- Special ---
		"marked":
			e.display_name = "Marked"
			e.category = Category.SPECIAL
			e.duration = -1  # until debt reduced
			e.stat_modifiers = { "anomaly_chance": 0.2 }
			e.tags = ["special", "auditor"]
		"resonance_drain":
			e.display_name = "Resonance Drain"
			e.category = Category.SPECIAL
			e.duration = 7
			e.stat_modifiers = { "spell_cost_mult": 1.5, "regen_blocked": 1 }
			e.tags = ["special", "resonance"]
		"ghost_touch":
			e.display_name = "Ghost Touch"
			e.category = Category.SPECIAL
			e.duration = -1  # until source removed
			e.dot_damage = 5
			e.dot_type = "resonance"
			e.tags = ["special", "memory"]
			e.extra = { "identity_damage": true }

	# Allow callers to override duration.
	if override_duration != -99:
		e.duration = override_duration
	return e


# ---------------------------------------------------------------------------
# Runtime methods
# ---------------------------------------------------------------------------

## Advance one round.  Returns any DoT damage dealt this tick.
func tick(combatant: Dictionary) -> int:
	var dmg := 0

	# Bleeding worsens if target moved this round.
	if id == "bleeding" and extra.get("movement_worsens", false):
		if combatant.get("moved_this_round", false):
			dmg += dot_damage  # double tick

	# Corroding: degrade armor instead of HP damage.
	if id == "corroding":
		var armor: float = combatant.get("armor", 0.0)
		combatant["armor"] = maxf(armor - extra.get("armor_degrade_per_tick", 2), 0.0)
	else:
		dmg += dot_damage

	# Shocked: chance of stun this tick.
	if id == "shocked" and randf() < extra.get("stun_chance", 0.35):
		combatant["stunned_this_round"] = true

	# Reduce duration (infinite = -1, never decrements).
	if duration > 0:
		duration -= 1

	return dmg


## True when the effect has expired naturally.
func is_expired() -> bool:
	return duration == 0


## True if the afflicted combatant can take actions this tick.
func can_act() -> bool:
	if prevents_action:
		return false
	return true


## True if the afflicted combatant can move.
func can_move() -> bool:
	return not prevents_movement


## True if the afflicted combatant can cast.
func can_cast() -> bool:
	return not prevents_casting


## Return a dictionary of stat modifiers contributed by this effect.
func get_stat_modifier() -> Dictionary:
	return stat_modifiers


# ---------------------------------------------------------------------------
# Cleanse / counter system
# ---------------------------------------------------------------------------

## Returns true if this effect can be cleansed by the given method.
func can_cleanse(method: String) -> bool:
	match method:
		"cleanse":
			# Generic cleanse removes control and dot, not special.
			return category != Category.SPECIAL
		"sever":
			return "magic" in tags or "resonance" in tags or "movement" in tags
		"null_salts":
			return "tech" in tags or "resonance" in tags
		"med":
			return id == "bleeding" or id == "burning" or id == "corroding"
		"ground":
			return id == "shocked"
		"reduce_debt":
			return id == "marked"
		"destroy_source":
			return id == "ghost_touch"
		_:
			return false


## Force-expire the effect.
func cleanse() -> void:
	duration = 0
