class_name Loadout
extends Resource
## A character's equipped ability loadout — 6 slots following the build system.
##
## Slot layout (from spec/14 Part XIII):
##   Core 1, Core 2       — primary capabilities
##   Utility 1, Utility 2 — situational tools
##   Reaction             — defensive / interrupt
##   Keystone             — ultimate, high-impact, limited use

enum SlotType {
	CORE,
	UTILITY,
	REACTION,
	KEYSTONE,
}

@export var core_1: AbilityData = null
@export var core_2: AbilityData = null
@export var utility_1: AbilityData = null
@export var utility_2: AbilityData = null
@export var reaction: AbilityData = null
@export var keystone: AbilityData = null


## Assign an ability to a slot. Index selects sub-slot for CORE (0/1) and
## UTILITY (0/1); ignored for REACTION and KEYSTONE. Returns true on success.
func set_ability(slot: SlotType, index: int, ability: AbilityData) -> bool:
	match slot:
		SlotType.CORE:
			if index == 0:
				core_1 = ability
			elif index == 1:
				core_2 = ability
			else:
				return false
		SlotType.UTILITY:
			if index == 0:
				utility_1 = ability
			elif index == 1:
				utility_2 = ability
			else:
				return false
		SlotType.REACTION:
			reaction = ability
		SlotType.KEYSTONE:
			keystone = ability
		_:
			return false
	return true


## Return all non-null abilities currently equipped.
func get_all_abilities() -> Array[AbilityData]:
	var abilities: Array[AbilityData] = []
	for ab in [core_1, core_2, utility_1, utility_2, reaction, keystone]:
		if ab != null:
			abilities.append(ab)
	return abilities


## Clear a specific slot. Index rules same as set_ability.
func clear_slot(slot: SlotType, index: int = 0) -> void:
	set_ability(slot, index, null)


## A loadout is valid when both core slots are filled.
func is_valid() -> bool:
	return core_1 != null and core_2 != null


# --- Faction Presets ---

## Build a Compact Regular grunt loadout from the spellbook.
static func compact_regular_preset() -> Loadout:
	var lo := Loadout.new()
	lo.core_1 = Spellbook.get_spell("force_bolt")
	lo.core_2 = Spellbook.get_spell("personal_shield")
	lo.utility_1 = Spellbook.get_spell("push")
	lo.utility_2 = Spellbook.get_spell("stabilize")
	lo.reaction = Spellbook.get_spell("interrupt")
	lo.keystone = Spellbook.get_spell("gravity_well")
	return lo


## Build a Sutured House field-agent loadout from the spellbook.
static func sutured_field_agent_preset() -> Loadout:
	var lo := Loadout.new()
	lo.core_1 = Spellbook.get_spell("dispel")
	lo.core_2 = Spellbook.get_spell("clean_cut")
	lo.utility_1 = Spellbook.get_spell("truth_sense")
	lo.utility_2 = Spellbook.get_spell("mend")
	lo.reaction = Spellbook.get_spell("interrupt")
	lo.keystone = Spellbook.get_spell("overlay_counter_claim")
	return lo


## Build a Writbound agent loadout from the spellbook.
static func writbound_agent_preset() -> Loadout:
	var lo := Loadout.new()
	lo.core_1 = Spellbook.get_spell("extraction_spike")
	lo.core_2 = Spellbook.get_spell("resonance_tracker")
	lo.utility_1 = Spellbook.get_spell("resonance_lock")
	lo.utility_2 = Spellbook.get_spell("hold")
	lo.reaction = Spellbook.get_spell("interrupt")
	lo.keystone = Spellbook.get_spell("lattice_lock")
	return lo
