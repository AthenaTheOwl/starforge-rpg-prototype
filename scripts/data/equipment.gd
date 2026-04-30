class_name Equipment
extends Resource
## Equipment resource — weapons, armor, shields, wards, accessories.
##
## Defines item stats, slot types, weight classes, and rune properties.

enum SlotType {
	PRIMARY_WEAPON,
	SECONDARY_WEAPON,
	ARMOR,
	SHIELD_GEN,
	WARD_FOCUS,
	ACCESSORY,
}

enum WeightClass {
	LIGHT,
	MEDIUM,
	HEAVY,
}

enum DamageType {
	PHYSICAL,
	THERMAL,
	SHOCK,
	RESONANCE,
	SEVER,
}

# --- Identity ---
@export var id: String = ""
@export var name: String = ""
@export_multiline var description: String = ""
@export_multiline var lore_text: String = ""
@export var slot_type: SlotType = SlotType.PRIMARY_WEAPON

# --- Stat Modifiers ---
## Dictionary of stat_name -> int modifier (e.g. {"armor": 5, "speed": -2})
@export var stat_modifiers: Dictionary = {}

# --- Weapon-Specific ---
@export var damage_type: DamageType = DamageType.PHYSICAL
@export var base_damage: int = 0
@export var is_runed: bool = false
@export var rune_effects: Array[String] = []

# --- Armor-Specific ---
@export var weight_class: WeightClass = WeightClass.LIGHT

# --- Relic ---
@export var is_relic: bool = false
@export_multiline var relic_lore: String = ""


## Create an Equipment resource from a dictionary (e.g. loaded from JSON).
static func from_dict(data: Dictionary) -> Equipment:
	var eq := Equipment.new()
	eq.id = data.get("id", "")
	eq.name = data.get("name", "")
	eq.description = data.get("description", "")
	eq.lore_text = data.get("lore_text", "")
	eq.slot_type = _parse_slot_type(data.get("slot_type", "primary_weapon"))
	eq.stat_modifiers = data.get("stat_modifiers", {})
	eq.damage_type = _parse_damage_type(data.get("damage_type", "physical"))
	eq.base_damage = data.get("base_damage", 0)
	eq.is_runed = data.get("is_runed", false)
	var runes = data.get("rune_effects", [])
	for r in runes:
		eq.rune_effects.append(str(r))
	eq.weight_class = _parse_weight_class(data.get("weight_class", "light"))
	eq.is_relic = data.get("is_relic", false)
	eq.relic_lore = data.get("relic_lore", "")
	return eq


static func _parse_slot_type(s: String) -> SlotType:
	match s.to_lower():
		"primary_weapon": return SlotType.PRIMARY_WEAPON
		"secondary_weapon": return SlotType.SECONDARY_WEAPON
		"armor": return SlotType.ARMOR
		"shield_gen": return SlotType.SHIELD_GEN
		"ward_focus": return SlotType.WARD_FOCUS
		"accessory": return SlotType.ACCESSORY
	return SlotType.PRIMARY_WEAPON


static func _parse_damage_type(s: String) -> DamageType:
	match s.to_lower():
		"physical": return DamageType.PHYSICAL
		"thermal": return DamageType.THERMAL
		"shock": return DamageType.SHOCK
		"resonance": return DamageType.RESONANCE
		"sever": return DamageType.SEVER
	return DamageType.PHYSICAL


static func _parse_weight_class(s: String) -> WeightClass:
	match s.to_lower():
		"light": return WeightClass.LIGHT
		"medium": return WeightClass.MEDIUM
		"heavy": return WeightClass.HEAVY
	return WeightClass.LIGHT


## Serialize back to dictionary for saving.
func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"description": description,
		"lore_text": lore_text,
		"slot_type": SlotType.keys()[slot_type].to_lower(),
		"stat_modifiers": stat_modifiers,
		"damage_type": DamageType.keys()[damage_type].to_lower(),
		"base_damage": base_damage,
		"is_runed": is_runed,
		"rune_effects": rune_effects,
		"weight_class": WeightClass.keys()[weight_class].to_lower(),
		"is_relic": is_relic,
		"relic_lore": relic_lore,
	}
