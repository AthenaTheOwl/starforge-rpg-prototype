class_name RelicWeapon
extends Equipment
## Relic weapon with inlay slots for Lattice upgrades.
##
## Inlay types (from spec/08_characters.md):
##   Bond-Mesh Anchor, Coherence Edge, Veil Stitch, Covenant Thread,
##   Mercy Detonation Bracket, Suture Bloom, Crownstep Stabilizer

## Number of inlay slots (1-3).
@export_range(1, 3) var inlay_slots: int = 1

## Equipped inlays. Each is a Dictionary with keys: name, effect, cost.
@export var inlays: Array[Dictionary] = []

## Known inlay type names for validation.
const VALID_INLAY_TYPES: Array[String] = [
	"Bond-Mesh Anchor",
	"Coherence Edge",
	"Veil Stitch",
	"Covenant Thread",
	"Mercy Detonation Bracket",
	"Suture Bloom",
	"Crownstep Stabilizer",
]


## Add an inlay to this relic weapon. Returns true on success.
func add_inlay(inlay: Dictionary) -> bool:
	if inlays.size() >= inlay_slots:
		push_warning("RelicWeapon '%s': no free inlay slots." % name)
		return false
	if not inlay.has("name"):
		push_warning("RelicWeapon '%s': inlay missing 'name' key." % name)
		return false
	inlays.append(inlay)
	return true


## Remove an inlay by index. Returns the removed inlay or empty dict.
func remove_inlay(index: int) -> Dictionary:
	if index < 0 or index >= inlays.size():
		return {}
	var removed := inlays[index]
	inlays.remove_at(index)
	return removed


## Get combined effects from all equipped inlays as a merged dictionary.
func get_combined_effects() -> Dictionary:
	var combined: Dictionary = {}
	for inlay in inlays:
		var effects: Dictionary = inlay.get("effects", {})
		for key in effects:
			if key in combined:
				if combined[key] is int or combined[key] is float:
					combined[key] += effects[key]
				else:
					combined[key] = effects[key]
			else:
				combined[key] = effects[key]
	return combined


## Create a RelicWeapon from a dictionary.
static func from_dict(data: Dictionary) -> RelicWeapon:
	var rw := RelicWeapon.new()
	rw.id = data.get("id", "")
	rw.name = data.get("name", "")
	rw.description = data.get("description", "")
	rw.lore_text = data.get("lore_text", "")
	rw.slot_type = Equipment._parse_slot_type(data.get("slot_type", "primary_weapon"))
	rw.stat_modifiers = data.get("stat_modifiers", {})
	rw.damage_type = Equipment._parse_damage_type(data.get("damage_type", "physical"))
	rw.base_damage = data.get("base_damage", 0)
	rw.is_runed = data.get("is_runed", true)
	var runes = data.get("rune_effects", [])
	for r in runes:
		rw.rune_effects.append(str(r))
	rw.weight_class = Equipment._parse_weight_class(data.get("weight_class", "light"))
	rw.is_relic = true
	rw.relic_lore = data.get("relic_lore", "")
	rw.inlay_slots = data.get("inlay_slots", 1)
	var inlay_data = data.get("inlays", [])
	for inlay in inlay_data:
		rw.inlays.append(inlay)
	return rw


## Serialize to dictionary.
func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["inlay_slots"] = inlay_slots
	d["inlays"] = inlays
	return d
