class_name Spellbook
## Static spell registry — loads ability definitions from spellbook.json.
##
## All spell lookups go through this class. Data is lazy-loaded on first access.

enum School {
	WARD,
	BIND,
	SEVER,
	KINETIC,
	ELEMENTAL,
	MIND,
	UTILITY,
	SPECIALIZED,
	COMBAT,
	HEALING,
	CREW_PROTOCOL,
}

const SPELLBOOK_PATH := "res://data/abilities/spellbook.json"

# Internal registry: spell id -> AbilityData
static var _registry: Dictionary = {}
static var _loaded: bool = false


## Ensure the registry is populated from disk.
static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(SPELLBOOK_PATH):
		push_error("Spellbook: data file not found at %s" % SPELLBOOK_PATH)
		return
	var file := FileAccess.open(SPELLBOOK_PATH, FileAccess.READ)
	if file == null:
		push_error("Spellbook: cannot open %s" % SPELLBOOK_PATH)
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("Spellbook: JSON parse error — %s" % json.get_error_message())
		return
	var entries: Array = json.data
	for entry: Dictionary in entries:
		var spell := _dict_to_ability(entry)
		_registry[spell.id] = spell


## Look up a single spell by its string id. Returns null if not found.
static func get_spell(id: String) -> AbilityData:
	_ensure_loaded()
	if id in _registry:
		return _registry[id]
	push_warning("Spellbook: spell '%s' not found" % id)
	return null


## Return all spells that belong to a given school.
static func get_spells_by_school(school_value: int) -> Array[AbilityData]:
	_ensure_loaded()
	var result: Array[AbilityData] = []
	for spell: AbilityData in _registry.values():
		if spell.school == school_value:
			result.append(spell)
	return result


## Return all spells of a given tier (1-3).
static func get_spells_by_tier(tier: int) -> Array[AbilityData]:
	_ensure_loaded()
	var result: Array[AbilityData] = []
	for spell: AbilityData in _registry.values():
		if spell.tier == tier:
			result.append(spell)
	return result


## Return all Crew Protocol spells (Bond-Mesh cooperative abilities).
static func get_crew_protocols() -> Array[AbilityData]:
	return get_spells_by_school(AbilityData.School.CREW_PROTOCOL)


# --- Internal ---

static func _school_from_string(s: String) -> AbilityData.School:
	match s.to_upper():
		"WARD": return AbilityData.School.WARD
		"BIND": return AbilityData.School.BIND
		"SEVER": return AbilityData.School.SEVER
		"KINETIC": return AbilityData.School.KINETIC
		"ELEMENTAL": return AbilityData.School.ELEMENTAL
		"MIND": return AbilityData.School.MIND
		"UTILITY": return AbilityData.School.UTILITY
		"SPECIALIZED": return AbilityData.School.SPECIALIZED
		"COMBAT": return AbilityData.School.COMBAT
		"HEALING": return AbilityData.School.HEALING
		"CREW_PROTOCOL": return AbilityData.School.CREW_PROTOCOL
	return AbilityData.School.UTILITY


static func _interface_from_string(s: String) -> AbilityData.Interface:
	match s.to_upper():
		"PRIMORDIAL": return AbilityData.Interface.PRIMORDIAL
		"SYNTHETIC": return AbilityData.Interface.SYNTHETIC
		"BOTH": return AbilityData.Interface.BOTH
	return AbilityData.Interface.BOTH


static func _target_from_string(s: String) -> AbilityData.TargetType:
	match s.to_upper():
		"SELF": return AbilityData.TargetType.SELF
		"SINGLE_ENEMY": return AbilityData.TargetType.SINGLE_ENEMY
		"SINGLE_ALLY": return AbilityData.TargetType.SINGLE_ALLY
		"ALL_ENEMIES": return AbilityData.TargetType.ALL_ENEMIES
		"ALL_ALLIES": return AbilityData.TargetType.ALL_ALLIES
		"AOE": return AbilityData.TargetType.AOE
	return AbilityData.TargetType.SINGLE_ENEMY


static func _dict_to_ability(d: Dictionary) -> AbilityData:
	var ab := AbilityData.new()
	ab.id = d.get("id", "")
	ab.name = d.get("name", "")
	ab.description = d.get("description", "")
	ab.school = _school_from_string(d.get("school", "UTILITY"))
	ab.tier = clampi(int(d.get("tier", 1)), 1, 3)
	var prims = d.get("primitives", [])
	for p in prims:
		ab.primitives.append(str(p))
	ab.interface_type = _interface_from_string(d.get("interface", "BOTH"))
	ab.heat_cost = int(d.get("heat_cost", 1))
	ab.cli_cost = int(d.get("cli_cost", 1))
	ab.charges_max = int(d.get("charges_max", -1))
	ab.cooldown_rounds = int(d.get("cooldown_rounds", 0))
	ab.base_damage = int(d.get("base_damage", 0))
	ab.damage_type = d.get("damage_type", "")
	ab.statuses = d.get("statuses", [])
	ab.heal_amount = int(d.get("heal_amount", 0))
	ab.target_type = _target_from_string(d.get("target_type", "SINGLE_ENEMY"))
	ab.failure_description = d.get("failure_mode", "")
	ab.backlash_damage = int(d.get("backlash_damage", 0))
	ab.range_type = d.get("range", "close")
	ab.duration = d.get("duration", "instant")
	return ab
