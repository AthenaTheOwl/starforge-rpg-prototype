class_name CharacterStats
extends Resource
## Stat block for a character — core, lattice, social, and derived stats.
##
## Core stats govern combat performance. Lattice stats track magical capacity
## and resilience. Social stats (trust, loyalty) apply to companion characters.

# --- Core Stats ---
@export var hp_max: int = 100
@export var speed: int = 5
@export var armor: int = 0
@export var shields: int = 0
@export var wards: int = 0
@export var attack: int = 10

# --- Lattice Stats ---
## Affinity with the Lattice (Primordial/Synthetic); higher = stronger caster.
@export var lattice_affinity: int = 0
## Personal heat capacity before instability. Default 5 per deep-magic spec.
@export var heat_capacity: int = 5
## Resistance to hostile resonance effects and extraction.
@export var resonance_resistance: int = 0

# --- Social Stats (companion only) ---
## Trust ranges 0-100; represents the companion's confidence in the player.
@export_range(0, 100) var trust: int = 50

enum LoyaltyTier {
	HOSTILE,
	WARY,
	NEUTRAL,
	WARM,
	DEVOTED,
}

@export var loyalty_tier: LoyaltyTier = LoyaltyTier.NEUTRAL

# --- Runtime / Degradation Tracking ---
## Accumulated armor degradation from sustained damage.
var armor_degradation: int = 0
## Bonus shield regen from gear or abilities.
var shield_regen_bonus: int = 0
## Bonus ward strength from gear or abilities.
var ward_strength_bonus: int = 0

# --- Base Snapshot (for reset) ---
var _base_snapshot: Dictionary = {}


func _init() -> void:
	_snapshot_base()


# --- Derived Stats ---

## Effective armor accounting for degradation over time.
func get_effective_armor() -> int:
	return maxi(armor - armor_degradation, 0)


## Shield points regenerated per round.
func get_shield_regen_rate() -> int:
	return maxi(shields / 4 + shield_regen_bonus, 0)


## Total ward absorption strength.
func get_ward_strength() -> int:
	return wards + ward_strength_bonus


# --- Stat Access ---

## Retrieve any stat by name string. Returns 0 if unknown.
func get_stat(stat_name: String) -> int:
	match stat_name:
		"hp_max": return hp_max
		"speed": return speed
		"armor": return armor
		"shields": return shields
		"wards": return wards
		"attack": return attack
		"lattice_affinity": return lattice_affinity
		"heat_capacity": return heat_capacity
		"resonance_resistance": return resonance_resistance
		"trust": return trust
		"effective_armor": return get_effective_armor()
		"shield_regen_rate": return get_shield_regen_rate()
		"ward_strength": return get_ward_strength()
	push_warning("CharacterStats: unknown stat '%s'" % stat_name)
	return 0


## Modify a stat by a signed delta. Clamps trust to 0-100.
func modify_stat(stat_name: String, delta: int) -> void:
	match stat_name:
		"hp_max": hp_max += delta
		"speed": speed += delta
		"armor": armor += delta
		"shields": shields += delta
		"wards": wards += delta
		"attack": attack += delta
		"lattice_affinity": lattice_affinity += delta
		"heat_capacity": heat_capacity += delta
		"resonance_resistance": resonance_resistance += delta
		"trust": trust = clampi(trust + delta, 0, 100)
		_:
			push_warning("CharacterStats: cannot modify '%s'" % stat_name)


## Reset all stats to their values at resource creation / last snapshot.
func reset_to_base() -> void:
	if _base_snapshot.is_empty():
		return
	hp_max = _base_snapshot.get("hp_max", hp_max)
	speed = _base_snapshot.get("speed", speed)
	armor = _base_snapshot.get("armor", armor)
	shields = _base_snapshot.get("shields", shields)
	wards = _base_snapshot.get("wards", wards)
	attack = _base_snapshot.get("attack", attack)
	lattice_affinity = _base_snapshot.get("lattice_affinity", lattice_affinity)
	heat_capacity = _base_snapshot.get("heat_capacity", heat_capacity)
	resonance_resistance = _base_snapshot.get("resonance_resistance", resonance_resistance)
	trust = _base_snapshot.get("trust", trust)
	loyalty_tier = _base_snapshot.get("loyalty_tier", loyalty_tier)
	armor_degradation = 0
	shield_regen_bonus = 0
	ward_strength_bonus = 0


## Capture the current stat values as the base for reset_to_base().
func _snapshot_base() -> void:
	_base_snapshot = {
		"hp_max": hp_max,
		"speed": speed,
		"armor": armor,
		"shields": shields,
		"wards": wards,
		"attack": attack,
		"lattice_affinity": lattice_affinity,
		"heat_capacity": heat_capacity,
		"resonance_resistance": resonance_resistance,
		"trust": trust,
		"loyalty_tier": loyalty_tier,
	}
