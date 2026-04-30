class_name AbilityData
extends Resource
## Data definition for a single ability / spell.
##
## Maps directly to entries in the spellbook JSON. Schools, primitives, and
## interface follow the deep-magic spec (spec/14, spec/15).

# --- Identity ---
@export var id: String = ""
@export var name: String = ""
@export_multiline var description: String = ""

# --- School ---
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

@export var school: School = School.WARD

## Ability tier: 1 (Basic), 2 (Journeyman), 3 (Master).
@export_range(1, 3) var tier: int = 1

# --- Primitives ---
## Spell primitives drawn from {SEVER, BIND, VEIL, WEAVE, ANCHOR, VENT, ECHO}.
@export var primitives: Array[String] = []

# --- Interface ---
enum Interface {
	PRIMORDIAL,
	SYNTHETIC,
	BOTH,
}

@export var interface_type: Interface = Interface.BOTH

# --- Costs ---
## Personal heat added when cast (0-5).
@export_range(0, 5) var heat_cost: int = 1
## Regional Coherence Load Index impact.
@export var cli_cost: int = 1
## Max charges per rest period; -1 means unlimited.
@export var charges_max: int = -1
## Cooldown in combat rounds; 0 means no cooldown.
@export var cooldown_rounds: int = 0

# --- Effects ---
@export var base_damage: int = 0
@export var damage_type: String = ""
## Status effects applied on hit. Each dict: {status, duration, chance}.
@export var statuses: Array[Dictionary] = []
@export var heal_amount: int = 0

# --- Targeting ---
enum TargetType {
	SELF,
	SINGLE_ENEMY,
	SINGLE_ALLY,
	ALL_ENEMIES,
	ALL_ALLIES,
	AOE,
}

@export var target_type: TargetType = TargetType.SINGLE_ENEMY

# --- Failure ---
@export_multiline var failure_description: String = ""
@export var backlash_damage: int = 0

# --- Range & Duration ---
## Range descriptor: "self", "touch", "close", "medium", "long", "extreme".
@export var range_type: String = "close"
## Duration descriptor: "instant", "sustained", "persistent", or round count.
@export var duration: String = "instant"
