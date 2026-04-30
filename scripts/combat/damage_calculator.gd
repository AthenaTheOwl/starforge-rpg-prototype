class_name DamageCalculator
extends RefCounted
## DamageCalculator — Resolves the full damage pipeline per the combat spec.
##
## Pipeline: base_damage -> heat_penalty -> defense_reduction -> min 1
##
## Defense interaction matrix:
##   Physical  -> Armor absorbed, Shield partial, Ward minimal
##   Thermal   -> Armor minimal,  Shield absorbed, Ward minimal
##   Shock     -> Armor minimal,  Shield absorbed, Ward minimal
##   Resonance -> Armor bypass,   Shield bypass,   Ward absorbed
##   Runed     -> Armor absorbed, Shield severed,  Ward severed

## Absorption multipliers: [armor, shield, ward]
const DEFENSE_MATRIX := {
	"physical":  { "armor": 1.0,  "shield": 0.3, "ward": 0.1 },
	"thermal":   { "armor": 0.1,  "shield": 1.0, "ward": 0.1 },
	"shock":     { "armor": 0.1,  "shield": 1.0, "ward": 0.1 },
	"resonance": { "armor": 0.0,  "shield": 0.0, "ward": 1.0 },
	"runed":     { "armor": 1.0,  "shield": 0.0, "ward": 0.0 },
}

## Armor degrades by this fraction of absorbed damage each hit.
const ARMOR_DEGRADE_RATE := 0.05

## Shield regen parameters: { delay_sec, regen_per_tick }
const SHIELD_PERSONAL := { "delay": 3.0, "regen": 4.0, "label": "personal" }
const SHIELD_TACTICAL := { "delay": 6.0, "regen": 2.0, "label": "tactical" }


## Full damage pipeline. Returns final damage (>= 1 if base > 0).
## Also mutates target defenses (armor degrade, shield/ward sever).
static func calculate_damage(
	source: Dictionary,
	target: Dictionary,
	base_damage: int,
	damage_type: String,
	heat: int = 0,
) -> int:
	if base_damage <= 0:
		return 0

	# --- Heat penalty ---
	var heat_penalty := _get_heat_penalty(heat)
	var after_heat := int(float(base_damage) * heat_penalty)

	# --- Runed blade: sever shields and wards before damage ---
	if damage_type == "runed":
		_sever_shields(target)
		_sever_wards(target)

	# --- Defense reduction ---
	var reduced := _reduce_by_defenses(target, after_heat, damage_type)

	return maxi(reduced, 1)


## Return heat-based damage multiplier.
static func _get_heat_penalty(heat: int) -> float:
	if heat >= 5:
		return 0.5
	elif heat >= 4:
		return 0.75
	return 1.0


## Reduce damage through armor / shield / ward according to the matrix.
static func _reduce_by_defenses(target: Dictionary, damage: int, damage_type: String) -> int:
	var row: Dictionary = DEFENSE_MATRIX.get(damage_type, DEFENSE_MATRIX["physical"])
	var remaining := float(damage)

	# Armor absorption
	var armor: float = target.get("armor", 0.0)
	if armor > 0.0 and row["armor"] > 0.0:
		var absorbed := minf(remaining, armor * row["armor"])
		remaining -= absorbed
		# Degrade armor under sustained damage
		_degrade_armor(target, absorbed)

	# Shield absorption
	var shield: float = target.get("shields", 0.0)
	if shield > 0.0 and row["shield"] > 0.0:
		var absorbed := minf(remaining, shield * row["shield"])
		remaining -= absorbed
		target["shields"] = maxf(shield - absorbed, 0.0)
		# Record last hit time for regen delay
		target["shield_last_hit_time"] = Time.get_ticks_msec() / 1000.0

	# Ward absorption
	var ward: float = target.get("wards", 0.0)
	if ward > 0.0 and row["ward"] > 0.0:
		var absorbed := minf(remaining, ward * row["ward"])
		remaining -= absorbed
		target["wards"] = maxf(ward - absorbed, 0.0)

	return int(remaining)


## Degrade armor proportional to absorbed damage.
static func _degrade_armor(target: Dictionary, absorbed: float) -> void:
	var armor: float = target.get("armor", 0.0)
	var degradation := absorbed * ARMOR_DEGRADE_RATE
	target["armor"] = maxf(armor - degradation, 0.0)


## Sever (destroy) shields — used by runed blade attacks.
static func _sever_shields(target: Dictionary) -> void:
	target["shields"] = 0.0


## Sever (destroy) wards — used by runed blade attacks.
static func _sever_wards(target: Dictionary) -> void:
	target["wards"] = 0.0


## Tick shield regeneration for a combatant. Call once per round end.
## shield_type should be SHIELD_PERSONAL or SHIELD_TACTICAL.
static func tick_shield_regen(target: Dictionary, delta_sec: float = 1.0) -> void:
	var shield_max: float = target.get("shields_max", 0.0)
	if shield_max <= 0.0:
		return

	var params: Dictionary
	match target.get("shield_type", "personal"):
		"tactical":
			params = SHIELD_TACTICAL
		_:
			params = SHIELD_PERSONAL

	var now: float = Time.get_ticks_msec() / 1000.0
	var last_hit: float = target.get("shield_last_hit_time", 0.0)

	if (now - last_hit) < params["delay"]:
		return  # Still in regen delay window

	var current: float = target.get("shields", 0.0)
	target["shields"] = minf(current + params["regen"] * delta_sec, shield_max)
