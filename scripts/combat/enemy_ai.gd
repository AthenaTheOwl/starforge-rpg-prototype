class_name EnemyAI
extends RefCounted
## EnemyAI — Per-family AI decision-making for enemy combatants.
##
## Each enemy dictionary must contain:
##   "family"    : String  — one of corp, raiders, cult, husks, auditor
##   "role"      : String  — unit role within the family
##   "abilities" : Array[Dictionary]
##
## Call decide() to get { "ability": Dictionary, "target_id": String }.

## Tracks how many times the player used each ability (for Auditor adaptation).
var player_action_history: Dictionary = {}  # { ability_name: int }


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Main entry point.  Returns { "ability": Dictionary, "target_id": String }.
func decide(
	enemy: Dictionary,
	allies: Array[Dictionary],
	opponents: Array[Dictionary],
) -> Dictionary:
	var family: String = enemy.get("family", "corp")
	match family:
		"corp":
			return _decide_corp(enemy, allies, opponents)
		"raiders":
			return _decide_raiders(enemy, allies, opponents)
		"cult":
			return _decide_cult(enemy, allies, opponents)
		"husks":
			return _decide_husks(enemy, allies, opponents)
		"auditor":
			return _decide_auditor(enemy, allies, opponents)
		_:
			return _decide_default(enemy, opponents)


## Record a player action for Auditor adaptation tracking.
func record_player_action(ability_name: String) -> void:
	player_action_history[ability_name] = player_action_history.get(ability_name, 0) + 1


# ---------------------------------------------------------------------------
# Per-family decision logic
# ---------------------------------------------------------------------------

## Corp Security: coordinated suppression, focus fire isolated targets,
## drone controller buffs, commander force multiplier.
func _decide_corp(
	enemy: Dictionary,
	allies: Array[Dictionary],
	opponents: Array[Dictionary],
) -> Dictionary:
	var target := target_selection(enemy, opponents, "corp")
	var ability := choose_ability(enemy, target, "corp")
	var role: String = enemy.get("role", "trooper")

	match role:
		"commander":
			# Prefer buff abilities when allies are alive.
			var buff := _find_ability_by_tag(enemy, "buff")
			if not buff.is_empty() and allies.size() > 1:
				ability = buff
				# Target best ally to buff.
				target = _highest_hp(allies, enemy)
		"drone_controller":
			var support := _find_ability_by_tag(enemy, "support")
			if not support.is_empty():
				ability = support
				target = _lowest_hp_ally(allies, enemy)
		"retrieval_specialist":
			# Prioritise isolated (no adjacent allies) opponents.
			var isolated := _find_isolated(opponents)
			if not isolated.is_empty():
				target = isolated
		_:
			# Trooper / Heavy: focus fire on whoever squad is targeting.
			var marked := _find_by_status(opponents, "marked_focus")
			if not marked.is_empty():
				target = marked

	return { "ability": ability, "target_id": target.get("id", "") }


## Rim Raiders: aggressive flanking, swarm, morale-dependent.
func _decide_raiders(
	enemy: Dictionary,
	allies: Array[Dictionary],
	opponents: Array[Dictionary],
) -> Dictionary:
	# Check morale: if war-chief is dead, chance to flee.
	var chief_alive := false
	for a in allies:
		if a.get("role", "") == "war_chief" and a.get("hp", 0) > 0:
			chief_alive = true
			break
	if not chief_alive and randf() < 0.4:
		# Break morale — choose flee / do nothing.
		return { "ability": { "name": "Flee", "base_damage": 0, "heat_cost": 0 }, "target_id": "" }

	# Swarm: pick lowest-hp opponent.
	var target := _lowest_hp_opponent(opponents)
	var ability := choose_ability(enemy, target, "raiders")

	# Flanker role: prefer flank abilities.
	if enemy.get("role", "") == "flanker":
		var flank := _find_ability_by_tag(enemy, "flank")
		if not flank.is_empty():
			ability = flank

	return { "ability": ability, "target_id": target.get("id", "") }


## Cult Wardens: binding priority, sacrifice timing, ward layering.
func _decide_cult(
	enemy: Dictionary,
	allies: Array[Dictionary],
	opponents: Array[Dictionary],
) -> Dictionary:
	var role: String = enemy.get("role", "acolyte")
	var target := target_selection(enemy, opponents, "cult")
	var ability := choose_ability(enemy, target, "cult")

	match role:
		"binder":
			# Priority: bind un-bound targets.
			var unbound := _find_without_status(opponents, "bound")
			if not unbound.is_empty():
				target = unbound
			var bind := _find_ability_by_tag(enemy, "bind")
			if not bind.is_empty():
				ability = bind
		"sacrifice":
			# Self-destruct when HP low or allies need buff.
			if enemy.get("hp", 0) < enemy.get("hp_max", 50) * 0.35:
				var sac := _find_ability_by_tag(enemy, "sacrifice")
				if not sac.is_empty():
					ability = sac
					target = _highest_hp(allies, enemy)
		"warden", "hierophant":
			# Layer wards on self / allies first, then attack.
			var ward_ability := _find_ability_by_tag(enemy, "ward")
			var needs_ward := _find_lowest_ward(allies)
			if not ward_ability.is_empty() and not needs_ward.is_empty():
				ability = ward_ability
				target = needs_ward
		_:
			pass  # Acolyte: default attack

	return { "ability": ability, "target_id": target.get("id", "") }


## Lattice Husks: swarm toward resonance users, echo mirrors, rift spawns.
func _decide_husks(
	enemy: Dictionary,
	_allies: Array[Dictionary],
	opponents: Array[Dictionary],
) -> Dictionary:
	var role: String = enemy.get("role", "shard")
	var target: Dictionary = {}
	var ability: Dictionary = {}

	match role:
		"shard", "shell":
			# Swarm toward highest resonance user.
			target = _highest_resonance(opponents)
			ability = choose_ability(enemy, target, "husks")
		"echo":
			# Mirror: copy last ability used by target.
			target = _highest_resonance(opponents)
			var mirror := _find_ability_by_tag(enemy, "mirror")
			ability = mirror if not mirror.is_empty() else choose_ability(enemy, target, "husks")
		"rift":
			# Spawn shards (self-targeted utility).
			var spawn := _find_ability_by_tag(enemy, "spawn")
			if not spawn.is_empty():
				ability = spawn
				target = enemy  # self
			else:
				target = _highest_resonance(opponents)
				ability = choose_ability(enemy, target, "husks")
		"hollow":
			# Memory harvest: prioritise targets with low wards.
			target = _lowest_ward_opponent(opponents)
			ability = choose_ability(enemy, target, "husks")
		_:
			target = _highest_resonance(opponents)
			ability = choose_ability(enemy, target, "husks")

	if target.is_empty() and not opponents.is_empty():
		target = opponents[0]
	if ability.is_empty():
		ability = { "name": "Attack", "base_damage": enemy.get("attack", 10), "damage_type": "physical", "heat_cost": 0 }

	return { "ability": ability, "target_id": target.get("id", "") }


## Auditor Probes: track player history, adapt counter-tactics, punish patterns.
func _decide_auditor(
	enemy: Dictionary,
	_allies: Array[Dictionary],
	opponents: Array[Dictionary],
) -> Dictionary:
	var target := target_selection(enemy, opponents, "auditor")

	# Find the player's most-used ability and pick a counter.
	var ability := _counter_most_used(enemy)

	# Arbiter role: adapt mid-fight.
	if enemy.get("role", "") == "arbiter" and not player_action_history.is_empty():
		var counter := _find_ability_by_tag(enemy, "counter")
		if not counter.is_empty():
			ability = counter

	# Watcher: mark targets.
	if enemy.get("role", "") == "watcher":
		var mark := _find_ability_by_tag(enemy, "mark")
		if not mark.is_empty():
			ability = mark

	# Accountant: stat drain.
	if enemy.get("role", "") == "accountant":
		var drain := _find_ability_by_tag(enemy, "drain")
		if not drain.is_empty():
			ability = drain

	if ability.is_empty():
		ability = choose_ability(enemy, target, "auditor")

	return { "ability": ability, "target_id": target.get("id", "") }


## Fallback AI.
func _decide_default(enemy: Dictionary, opponents: Array[Dictionary]) -> Dictionary:
	var target := _lowest_hp_opponent(opponents)
	var ability := choose_ability(enemy, target, "default")
	return { "ability": ability, "target_id": target.get("id", "") }


# ---------------------------------------------------------------------------
# Shared decision helpers
# ---------------------------------------------------------------------------

## Select a target based on family doctrine.
func target_selection(
	_enemy: Dictionary,
	opponents: Array[Dictionary],
	family: String,
) -> Dictionary:
	if opponents.is_empty():
		return {}
	match family:
		"corp":
			return _find_isolated(opponents) if not _find_isolated(opponents).is_empty() else _lowest_hp_opponent(opponents)
		"cult":
			# Prefer casters.
			return _highest_resonance(opponents)
		"auditor":
			# Target whoever uses the most Lattice abilities.
			return _highest_resonance(opponents)
		_:
			return _lowest_hp_opponent(opponents)


## Choose an ability based on family and situation.
func choose_ability(enemy: Dictionary, _target: Dictionary, _family: String) -> Dictionary:
	var abilities: Array = enemy.get("abilities", [])
	if abilities.is_empty():
		return { "name": "Attack", "base_damage": enemy.get("attack", 10), "damage_type": "physical", "heat_cost": 0 }
	# Weighted random toward higher-damage abilities.
	var best: Dictionary = abilities[0]
	var best_score: float = -1.0
	for a in abilities:
		var score: float = float(a.get("base_damage", 5)) + randf() * 10.0
		if score > best_score:
			best_score = score
			best = a
	return best


## Evaluate threat level of opponents.  Returns sorted array (highest threat first).
func evaluate_threats(opponents: Array[Dictionary]) -> Array[Dictionary]:
	var scored: Array[Dictionary] = []
	for o in opponents:
		var threat: float = 0.0
		threat += float(o.get("attack", 10))
		threat += float(o.get("resonance", 0)) * 1.5
		threat -= float(o.get("hp", 50)) * 0.1  # lower hp = less sustained threat
		scored.append({ "combatant": o, "threat": threat })
	scored.sort_custom(func(a, b): return a["threat"] > b["threat"])
	var result: Array[Dictionary] = []
	for s in scored:
		result.append(s["combatant"])
	return result


# ---------------------------------------------------------------------------
# Targeting utilities
# ---------------------------------------------------------------------------

func _lowest_hp_opponent(opponents: Array[Dictionary]) -> Dictionary:
	if opponents.is_empty():
		return {}
	var best: Dictionary = opponents[0]
	for o in opponents:
		if o.get("hp", 999) < best.get("hp", 999) and o.get("hp", 0) > 0:
			best = o
	return best


func _highest_hp(group: Array[Dictionary], exclude: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	for g in group:
		if g.get("id", "") == exclude.get("id", "__"):
			continue
		if best.is_empty() or g.get("hp", 0) > best.get("hp", 0):
			best = g
	return best


func _lowest_hp_ally(group: Array[Dictionary], exclude: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	for g in group:
		if g.get("id", "") == exclude.get("id", "__"):
			continue
		if g.get("hp", 0) <= 0:
			continue
		if best.is_empty() or g.get("hp", 999) < best.get("hp", 999):
			best = g
	return best


func _highest_resonance(opponents: Array[Dictionary]) -> Dictionary:
	if opponents.is_empty():
		return {}
	var best: Dictionary = opponents[0]
	for o in opponents:
		if o.get("resonance", 0) > best.get("resonance", 0) and o.get("hp", 0) > 0:
			best = o
	return best


func _find_isolated(opponents: Array[Dictionary]) -> Dictionary:
	## Isolated = has flag or fewest nearby allies (simplified: lowest "allies_nearby").
	var best: Dictionary = {}
	for o in opponents:
		if o.get("hp", 0) <= 0:
			continue
		if best.is_empty() or o.get("allies_nearby", 99) < best.get("allies_nearby", 99):
			best = o
	return best


func _find_by_status(group: Array[Dictionary], status_id: String) -> Dictionary:
	for g in group:
		var statuses: Array = g.get("statuses", [])
		for s in statuses:
			var sid: String = ""
			if s is StatusEffect:
				sid = s.id
			elif s is Dictionary:
				sid = s.get("id", s.get("name", ""))
			if sid == status_id:
				return g
	return {}


func _find_without_status(group: Array[Dictionary], status_id: String) -> Dictionary:
	for g in group:
		if g.get("hp", 0) <= 0:
			continue
		var has_it := false
		var statuses: Array = g.get("statuses", [])
		for s in statuses:
			var sid: String = ""
			if s is StatusEffect:
				sid = s.id
			elif s is Dictionary:
				sid = s.get("id", s.get("name", ""))
			if sid == status_id:
				has_it = true
				break
		if not has_it:
			return g
	return {}


func _find_lowest_ward(group: Array[Dictionary]) -> Dictionary:
	var best: Dictionary = {}
	for g in group:
		if g.get("hp", 0) <= 0:
			continue
		if best.is_empty() or g.get("wards", 999.0) < best.get("wards", 999.0):
			best = g
	return best


func _lowest_ward_opponent(opponents: Array[Dictionary]) -> Dictionary:
	return _find_lowest_ward(opponents)


func _find_ability_by_tag(enemy: Dictionary, tag: String) -> Dictionary:
	var abilities: Array = enemy.get("abilities", [])
	for a in abilities:
		var tags: Array = a.get("tags", [])
		if tag in tags:
			return a
	return {}


func _counter_most_used(enemy: Dictionary) -> Dictionary:
	if player_action_history.is_empty():
		return {}
	# Find the most-used player ability.
	var most_used: String = ""
	var most_count: int = 0
	for ability_name in player_action_history:
		if player_action_history[ability_name] > most_count:
			most_count = player_action_history[ability_name]
			most_used = ability_name
	# Look for a counter ability tagged with "counter".
	var counter := _find_ability_by_tag(enemy, "counter")
	if not counter.is_empty():
		return counter
	return {}
