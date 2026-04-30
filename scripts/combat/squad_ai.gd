class_name SquadAI
extends RefCounted
## SquadAI — Companion auto-action decision-making.
##
## Behaviour modes and trust-dependent execution as per combat spec.

enum Mode { AGGRESSIVE, DEFENSIVE, SUPPORT, FREE }

## Hesitation probability at minimum trust.
const HESITATION_CHANCE_LOW_TRUST := 0.35
## Trust threshold (0-100) below which negative effects apply.
const LOW_TRUST_THRESHOLD := 40
## Trust threshold above which positive effects apply.
const HIGH_TRUST_THRESHOLD := 70


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Decide what a companion does this turn.
## Returns { "ability": Dictionary, "target_id": String } or empty dict if they refuse/hesitate.
static func decide(
	companion: Dictionary,
	mode: Mode,
	allies: Array[Dictionary],
	enemies: Array[Dictionary],
) -> Dictionary:
	var trust: int = companion.get("trust", 50)

	# --- Low trust: possible hesitation or refusal ---
	if trust < LOW_TRUST_THRESHOLD:
		if _should_hesitate(trust):
			return {}  # Hesitate — skip turn.

		# May refuse risky orders (aggressive when HP low).
		if mode == Mode.AGGRESSIVE and _is_risky(companion):
			# Fall back to defensive self-preservation.
			mode = Mode.DEFENSIVE

	# --- Pick action per mode ---
	var decision: Dictionary = {}
	match mode:
		Mode.AGGRESSIVE:
			decision = _decide_aggressive(companion, allies, enemies)
		Mode.DEFENSIVE:
			decision = _decide_defensive(companion, allies, enemies)
		Mode.SUPPORT:
			decision = _decide_support(companion, allies, enemies)
		Mode.FREE:
			decision = _decide_free(companion, allies, enemies)

	# --- High trust: optimal timing adjustments ---
	if trust >= HIGH_TRUST_THRESHOLD:
		decision = _apply_high_trust(companion, decision, allies, enemies)

	return decision


# ---------------------------------------------------------------------------
# Per-mode logic
# ---------------------------------------------------------------------------

## Aggressive: engage nearest/weakest threat, use offensive abilities.
static func _decide_aggressive(
	companion: Dictionary,
	_allies: Array[Dictionary],
	enemies: Array[Dictionary],
) -> Dictionary:
	var target := _lowest_hp(enemies)
	if target.is_empty():
		return {}
	var ability := _pick_ability(companion, "offensive")
	return { "ability": ability, "target_id": target.get("id", "") }


## Defensive: hold position, protect self and allies, defensive abilities.
static func _decide_defensive(
	companion: Dictionary,
	allies: Array[Dictionary],
	enemies: Array[Dictionary],
) -> Dictionary:
	# If an ally is very low, prioritise protection.
	var wounded := _lowest_hp(allies)
	var defend_ability := _pick_ability(companion, "defensive")

	if not wounded.is_empty() and wounded.get("hp", 999) < wounded.get("hp_max", 50) * 0.3:
		if not defend_ability.is_empty():
			return { "ability": defend_ability, "target_id": wounded.get("id", "") }

	# Otherwise, attack the biggest threat.
	if enemies.is_empty():
		return {}
	var target := enemies[0]
	var ability := _pick_ability(companion, "offensive")
	return { "ability": ability, "target_id": target.get("id", "") }


## Support: stay near Avyanna, heal/buff, utility.
static func _decide_support(
	companion: Dictionary,
	allies: Array[Dictionary],
	_enemies: Array[Dictionary],
) -> Dictionary:
	# Find Avyanna or lowest-hp ally.
	var avyanna := _find_by_id(allies, "avyanna")
	var heal_target: Dictionary = {}
	if not avyanna.is_empty() and avyanna.get("hp", 999) < avyanna.get("hp_max", 50) * 0.7:
		heal_target = avyanna
	else:
		heal_target = _lowest_hp(allies)

	var ability := _pick_ability(companion, "support")
	if ability.is_empty():
		ability = _pick_ability(companion, "defensive")
	if ability.is_empty():
		ability = _pick_ability(companion, "offensive")

	var tid: String = heal_target.get("id", companion.get("id", ""))
	return { "ability": ability, "target_id": tid }


## Free: AI judgment — balanced approach.
static func _decide_free(
	companion: Dictionary,
	allies: Array[Dictionary],
	enemies: Array[Dictionary],
) -> Dictionary:
	# If any ally is critical, support.
	var wounded := _lowest_hp(allies)
	if not wounded.is_empty() and wounded.get("hp", 999) < wounded.get("hp_max", 50) * 0.25:
		return _decide_support(companion, allies, enemies)

	# If enemies are few, be aggressive.
	if enemies.size() <= 2:
		return _decide_aggressive(companion, allies, enemies)

	# Default: defensive.
	return _decide_defensive(companion, allies, enemies)


# ---------------------------------------------------------------------------
# Trust effects
# ---------------------------------------------------------------------------

static func _should_hesitate(trust: int) -> bool:
	## Lower trust = higher hesitation chance (linear interpolation).
	var chance: float = lerpf(HESITATION_CHANCE_LOW_TRUST, 0.0, float(trust) / float(LOW_TRUST_THRESHOLD))
	return randf() < chance


static func _is_risky(companion: Dictionary) -> bool:
	return companion.get("hp", 50) < companion.get("hp_max", 50) * 0.3


## High-trust companions protect Avyanna and optimise timing.
static func _apply_high_trust(
	_companion: Dictionary,
	decision: Dictionary,
	allies: Array[Dictionary],
	_enemies: Array[Dictionary],
) -> Dictionary:
	if decision.is_empty():
		return decision

	# If Avyanna is in danger, switch target to protect her.
	var avyanna := _find_by_id(allies, "avyanna")
	if not avyanna.is_empty() and avyanna.get("hp", 999) < avyanna.get("hp_max", 50) * 0.3:
		var ability: Dictionary = decision.get("ability", {})
		var tags: Array = ability.get("tags", [])
		if "defensive" in tags or "support" in tags:
			decision["target_id"] = avyanna.get("id", "avyanna")

	return decision


# ---------------------------------------------------------------------------
# Utilities
# ---------------------------------------------------------------------------

static func _lowest_hp(group: Array[Dictionary]) -> Dictionary:
	var best: Dictionary = {}
	for g in group:
		if g.get("hp", 0) <= 0:
			continue
		if best.is_empty() or g.get("hp", 999) < best.get("hp", 999):
			best = g
	return best


static func _find_by_id(group: Array[Dictionary], id: String) -> Dictionary:
	for g in group:
		if g.get("id", "") == id:
			return g
	return {}


static func _pick_ability(companion: Dictionary, preferred_tag: String) -> Dictionary:
	var abilities: Array = companion.get("abilities", [])
	# Try to find an ability with the preferred tag.
	for a in abilities:
		var tags: Array = a.get("tags", [])
		if preferred_tag in tags:
			return a
	# Fallback: first available ability or basic attack.
	if not abilities.is_empty():
		return abilities[0]
	return {
		"name": "Attack",
		"base_damage": companion.get("attack", 8),
		"damage_type": "physical",
		"heat_cost": 0,
	}
