extends Node
## RelationshipManager — Tracks affinity levels for all characters.
##
## Affinity is a 0-100 score per character. Tier thresholds gate content:
## STRANGER(0) → ACQUAINTANCE(10) → TRUSTED(25) → CLOSE(45) → BONDED(70)

signal relationship_changed(character_id: String, old_level: int, new_level: int)
signal relationship_milestone(character_id: String, milestone: String)

enum Tier { STRANGER, ACQUAINTANCE, TRUSTED, CLOSE, BONDED }

const TIER_THRESHOLDS := {
	Tier.STRANGER: 0,
	Tier.ACQUAINTANCE: 10,
	Tier.TRUSTED: 25,
	Tier.CLOSE: 45,
	Tier.BONDED: 70,
}

const CHARACTERS := {
	# Human crew
	"elia": {"name": "Elia", "type": "crew", "starting_affinity": 15},
	"elisira": {"name": "Elisira", "type": "crew", "starting_affinity": 10},
	"vesper": {"name": "Vesper", "type": "crew", "starting_affinity": 5},
	"jalen": {"name": "Jalen", "type": "crew", "starting_affinity": 5},
	"nyx": {"name": "Nyx", "type": "crew", "starting_affinity": 5},
	"rho": {"name": "Rho", "type": "crew", "starting_affinity": 10},
	# AI citizens
	"waffle": {"name": "Waffle.bat", "type": "ai_citizen", "starting_affinity": 5},
	"bubbles": {"name": "Bubbles", "type": "ai_citizen", "starting_affinity": 5},
	"cinnamon": {"name": "Cinnamon", "type": "ai_citizen", "starting_affinity": 5},
	"souffle": {"name": "Souffle", "type": "ai_citizen", "starting_affinity": 0},
	# Entity
	"bee": {"name": "Bee", "type": "entity", "starting_affinity": 0},
}

## Current affinity scores (0-100)
var affinity: Dictionary = {}


func _ready() -> void:
	_initialize_affinity()


func _initialize_affinity() -> void:
	for char_id in CHARACTERS:
		affinity[char_id] = CHARACTERS[char_id]["starting_affinity"]


func change_affinity(character_id: String, amount: int) -> void:
	if character_id not in affinity:
		push_warning("RelationshipManager: Unknown character: %s" % character_id)
		return
	var old := affinity[character_id] as int
	affinity[character_id] = clampi(old + amount, 0, 100)
	var new_val := affinity[character_id] as int
	relationship_changed.emit(character_id, old, new_val)
	var old_tier := get_tier(character_id, old)
	var new_tier := get_tier(character_id, new_val)
	if new_tier != old_tier:
		_on_tier_change(character_id, old_tier, new_tier)


func get_affinity(character_id: String) -> int:
	return affinity.get(character_id, 0)


func get_tier(character_id: String, override_value: int = -1) -> Tier:
	var val: int = override_value if override_value >= 0 else get_affinity(character_id)
	if val >= TIER_THRESHOLDS[Tier.BONDED]:
		return Tier.BONDED
	elif val >= TIER_THRESHOLDS[Tier.CLOSE]:
		return Tier.CLOSE
	elif val >= TIER_THRESHOLDS[Tier.TRUSTED]:
		return Tier.TRUSTED
	elif val >= TIER_THRESHOLDS[Tier.ACQUAINTANCE]:
		return Tier.ACQUAINTANCE
	else:
		return Tier.STRANGER


func get_tier_name(tier: Tier) -> String:
	match tier:
		Tier.STRANGER: return "Stranger"
		Tier.ACQUAINTANCE: return "Acquaintance"
		Tier.TRUSTED: return "Trusted"
		Tier.CLOSE: return "Close"
		Tier.BONDED: return "Bonded"
	return "Unknown"


func is_at_least(character_id: String, min_tier: Tier) -> bool:
	return get_tier(character_id) >= min_tier


func can_access_dialogue(character_id: String, required_tier: Tier) -> bool:
	return is_at_least(character_id, required_tier)


func _on_tier_change(character_id: String, _old_tier: Tier, new_tier: Tier) -> void:
	var milestone := "%s_tier_%s" % [character_id, get_tier_name(new_tier).to_lower()]
	GameManager.set_flag(milestone)
	relationship_milestone.emit(character_id, get_tier_name(new_tier))


func serialize() -> Dictionary:
	return {"affinity": affinity.duplicate()}


func deserialize(data: Dictionary) -> void:
	affinity = data.get("affinity", {})
	if affinity.is_empty():
		_initialize_affinity()
