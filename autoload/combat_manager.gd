extends Node
## CombatManager — Turn-based combat with initiative, Heat, CLI, status effects.
##
## Combat flow:
## 1. setup_encounter() populates enemies
## 2. Battle scene calls start_combat()
## 3. Each round: determine turn order -> each combatant acts -> resolve effects
## 4. Combat ends on victory (all enemies dead) or escape

enum CombatPhase { SETUP, PLAYER_TURN, ENEMY_TURN, RESOLVING, VICTORY, DEFEAT, ESCAPED }

var phase: CombatPhase = CombatPhase.SETUP
var enemies: Array[Dictionary] = []
var turn_order: Array[Dictionary] = []  # {id, is_player, speed}
var current_turn_index: int = 0
var round_number: int = 0

# Regional Coherence Load Index (0-10)
var regional_cli: float = 0.0
const CLI_MAX := 10.0
# CLI decay per round
const CLI_DECAY := 0.5

## Enemy AI controller instance.
var _enemy_ai: EnemyAI = EnemyAI.new()

## Companion behaviour modes keyed by companion id.
var companion_modes: Dictionary = {}  # { id: SquadAI.Mode }

## Party split instance for split combat encounters.
var party_split: PartySplit = null
## Whether current encounter is split combat.
var is_split_combat: bool = false

signal combat_started()
signal turn_started(combatant: Dictionary)
signal turn_ended(combatant: Dictionary)
signal combat_ended(result: CombatPhase)
signal cli_changed(new_value: float)
signal damage_dealt(source: Dictionary, target: Dictionary, amount: int, type: String)
signal status_applied(target: Dictionary, status: String)
signal xp_awarded(total_xp: int)
signal team_b_update(report: Dictionary)


func setup_encounter(enemy_group: Array[Dictionary]) -> void:
	enemies.clear()
	for enemy_data in enemy_group:
		var enemy := enemy_data.duplicate(true)
		enemy["hp"] = enemy.get("hp_max", 50)
		enemy["heat"] = 0
		enemy["statuses"] = []
		enemies.append(enemy)
	phase = CombatPhase.SETUP
	is_split_combat = false
	party_split = null


## Set up a split party encounter for Act 1 finale.
## team_a fights enemies directly (player controlled)
## team_b is AI-controlled with player-issued orders
func setup_split_encounter(
	team_a_ids: Array[String],
	team_b_ids: Array[String],
	enemy_group: Array[Dictionary],
	team_b_enemies: Array[Dictionary] = []
) -> void:
	# Initialize party split
	party_split = PartySplit.new()
	party_split.setup_split(team_a_ids, team_b_ids)

	# Set team B enemies if provided
	if not team_b_enemies.is_empty():
		party_split.set_team_b_enemies(team_b_enemies)

	# Set up normal encounter for team A
	setup_encounter(enemy_group)

	# Mark as split combat
	is_split_combat = true


func start_combat() -> void:
	round_number = 0
	regional_cli = 0.0
	_enemy_ai = EnemyAI.new()
	_build_turn_order()
	phase = CombatPhase.PLAYER_TURN
	combat_started.emit()
	_advance_turn()


func _build_turn_order() -> void:
	turn_order.clear()
	# Add player characters
	for c in PartyManager.get_active_characters():
		turn_order.append({
			"id": c["id"],
			"is_player": true,
			"speed": c.get("speed", 10),
			"ref": c,
		})
	# Add enemies
	for i in enemies.size():
		turn_order.append({
			"id": "enemy_%d" % i,
			"is_player": false,
			"speed": enemies[i].get("speed", 8),
			"ref": enemies[i],
		})
	# Sort by speed descending
	turn_order.sort_custom(func(a, b): return a["speed"] > b["speed"])
	current_turn_index = -1


func _advance_turn() -> void:
	current_turn_index += 1
	if current_turn_index >= turn_order.size():
		# New round
		_end_of_round()
		current_turn_index = 0

	# Skip dead combatants
	var combatant := turn_order[current_turn_index]
	if combatant["ref"].get("hp", 0) <= 0:
		_advance_turn()
		return

	if combatant["is_player"]:
		phase = CombatPhase.PLAYER_TURN
	else:
		phase = CombatPhase.ENEMY_TURN
	turn_started.emit(combatant)


func _end_of_round() -> void:
	round_number += 1
	# Decay CLI
	regional_cli = maxf(0.0, regional_cli - CLI_DECAY)
	cli_changed.emit(regional_cli)
	# Tick status effects
	for entry in turn_order:
		_tick_statuses(entry["ref"])
	# Shield regeneration for all combatants
	for entry in turn_order:
		DamageCalculator.tick_shield_regen(entry["ref"])

	# Handle party split simulation
	if is_split_combat and party_split:
		var team_b_report: Dictionary = party_split.simulate_team_b_turn()
		team_b_update.emit(team_b_report)

		# Check if team B is still alive
		if not party_split.is_team_b_alive():
			# Team B defeated — could trigger special consequences
			push_warning("CombatManager: Team B has been defeated during split combat!")
			# For now, continue combat but signal the defeat


# --- Actions ---

## Execute a player ability. Called by battle UI.
func execute_ability(source_id: String, ability: Dictionary, target_ids: Array[String]) -> void:
	var source := _get_combatant(source_id)
	if source.is_empty():
		return

	# Record for Auditor AI adaptation.
	_enemy_ai.record_player_action(ability.get("name", "unknown"))

	var heat_cost: int = ability.get("heat_cost", 1)
	source["heat"] = mini(source.get("heat", 0) + heat_cost, 5)

	# Increase CLI if ability uses Lattice
	if ability.get("uses_lattice", false):
		var cli_increase: float = ability.get("cli_cost", 0.5)
		regional_cli = minf(regional_cli + cli_increase, CLI_MAX)
		cli_changed.emit(regional_cli)

	# Heat degradation: at 4+ heat, damage reduced
	var heat_penalty := 1.0
	if source.get("heat", 0) >= 5:
		heat_penalty = 0.5
		# Backlash risk at heat 5
		if randf() < 0.3:
			var backlash := DamageCalculator.calculate_damage(
				source, source,
				ability.get("base_damage", 10) / 2,
				"resonance",
				source.get("heat", 0),
			)
			_apply_damage(source, source, backlash, "resonance")
	elif source.get("heat", 0) >= 4:
		heat_penalty = 0.75

	# Apply to each target
	for tid in target_ids:
		var target := _get_combatant(tid)
		if target.is_empty():
			continue

		var base_damage: int = ability.get("base_damage", 0)
		var damage_type: String = ability.get("damage_type", "physical")

		if base_damage > 0:
			var final_damage := DamageCalculator.calculate_damage(
				source, target, base_damage, damage_type, source.get("heat", 0),
			)
			_apply_damage(source, target, final_damage, damage_type)

		# Apply status effects
		for status_data in ability.get("statuses", []):
			_apply_status(target, status_data)

	phase = CombatPhase.RESOLVING
	_check_combat_end()
	if phase == CombatPhase.RESOLVING:
		turn_ended.emit(turn_order[current_turn_index])
		_advance_turn()


## Attempt to escape combat.
func attempt_escape() -> bool:
	# Escape always possible but has consequences
	phase = CombatPhase.ESCAPED
	combat_ended.emit(CombatPhase.ESCAPED)
	return true


## Set companion behaviour mode.
func set_companion_mode(companion_id: String, mode: SquadAI.Mode) -> void:
	companion_modes[companion_id] = mode


## Execute companion auto-action via SquadAI.
func execute_companion_turn(companion: Dictionary) -> void:
	var mode: SquadAI.Mode = companion_modes.get(
		companion.get("id", ""), SquadAI.Mode.FREE
	)
	var allies: Array[Dictionary] = []
	for c in PartyManager.get_active_characters():
		if c.get("hp", 0) > 0:
			allies.append(c)
	var alive_enemies: Array[Dictionary] = []
	for e in enemies:
		if e.get("hp", 0) > 0:
			alive_enemies.append(e)

	var decision := SquadAI.decide(companion, mode, allies, alive_enemies)
	if decision.is_empty():
		# Companion hesitated — skip turn.
		turn_ended.emit(turn_order[current_turn_index])
		_advance_turn()
		return

	var ability: Dictionary = decision.get("ability", {})
	var target_id: String = decision.get("target_id", "")
	if target_id.is_empty() and not alive_enemies.is_empty():
		target_id = alive_enemies[0].get("id", "")

	execute_ability(companion.get("id", ""), ability, [target_id])


## Enemy AI takes a turn — delegates to EnemyAI per-family logic.
func execute_enemy_turn(enemy: Dictionary) -> void:
	var alive_enemies: Array[Dictionary] = []
	for e in enemies:
		if e.get("hp", 0) > 0:
			alive_enemies.append(e)

	var alive_players: Array[Dictionary] = []
	for c in PartyManager.get_active_characters():
		if c.get("hp", 0) > 0:
			alive_players.append(c)

	if alive_players.is_empty():
		return

	var decision := _enemy_ai.decide(enemy, alive_enemies, alive_players)
	var ability: Dictionary = decision.get("ability", {})
	var target_id: String = decision.get("target_id", "")

	if ability.get("name", "") == "Flee":
		# Rim Raider morale break — remove from combat.
		enemy["hp"] = 0
		turn_ended.emit(turn_order[current_turn_index])
		_check_combat_end()
		if phase == CombatPhase.RESOLVING or phase == CombatPhase.ENEMY_TURN:
			_advance_turn()
		return

	if target_id.is_empty() and not alive_players.is_empty():
		target_id = alive_players[0].get("id", "")

	execute_ability(enemy.get("id", "enemy_0"), ability, [target_id])


# --- Damage & Defense ---

func _apply_defenses(target: Dictionary, damage: int, damage_type: String) -> int:
	return DamageCalculator.calculate_damage({}, target, damage, damage_type)


func _apply_damage(source: Dictionary, target: Dictionary, amount: int, damage_type: String) -> void:
	target["hp"] = maxi(target.get("hp", 0) - amount, 0)
	damage_dealt.emit(source, target, amount, damage_type)


# --- Status Effects ---

func _apply_status(target: Dictionary, status_data: Dictionary) -> void:
	var statuses: Array = target.get("statuses", [])
	# If status_data has an "id" key, create a proper StatusEffect.
	if status_data.has("id"):
		var effect := StatusEffect.create(
			status_data["id"],
			status_data.get("duration", -99),
		)
		statuses.append(effect)
		target["statuses"] = statuses
		status_applied.emit(target, effect.id)
	else:
		# Legacy dict-based status — keep backward compatible.
		statuses.append(status_data.duplicate(true))
		target["statuses"] = statuses
		status_applied.emit(target, status_data.get("name", "unknown"))


func _tick_statuses(combatant: Dictionary) -> void:
	var statuses: Array = combatant.get("statuses", [])
	var remaining: Array = []
	combatant["stunned_this_round"] = false

	for s in statuses:
		if s is StatusEffect:
			var dot_dmg: int = s.tick(combatant)
			if dot_dmg > 0:
				_apply_damage(combatant, combatant, dot_dmg, s.dot_type)
			if not s.is_expired():
				remaining.append(s)
		elif s is Dictionary:
			# Legacy dict path.
			if s.has("dot_damage"):
				_apply_damage(combatant, combatant, s["dot_damage"], s.get("dot_type", "physical"))
			s["duration"] = s.get("duration", 1) - 1
			if s["duration"] > 0:
				remaining.append(s)

	combatant["statuses"] = remaining


## Cleanse statuses on a combatant using the given method.
func cleanse_statuses(combatant: Dictionary, method: String) -> void:
	var statuses: Array = combatant.get("statuses", [])
	var remaining: Array = []
	for s in statuses:
		if s is StatusEffect:
			if s.can_cleanse(method):
				s.cleanse()
			if not s.is_expired():
				remaining.append(s)
		else:
			remaining.append(s)
	combatant["statuses"] = remaining


# --- Utility ---

func _get_combatant(id: String) -> Dictionary:
	# Check players
	for c in PartyManager.get_active_characters():
		if c.get("id", "") == id:
			return c
	# Check enemies
	for e in enemies:
		if e.get("id", "") == id:
			return e
	return {}


func _check_combat_end() -> void:
	# Check if all enemies dead
	var enemies_alive := false
	for e in enemies:
		if e.get("hp", 0) > 0:
			enemies_alive = true
			break
	if not enemies_alive:
		phase = CombatPhase.VICTORY
		# Award XP: 50 per enemy defeated
		var total_xp: int = enemies.size() * 50
		PartyManager.award_xp(total_xp)
		xp_awarded.emit(total_xp)

		# Merge split teams if applicable
		if is_split_combat and party_split:
			party_split.merge_teams()
			is_split_combat = false

		combat_ended.emit(CombatPhase.VICTORY)
		# Trigger autosave after combat victory
		if SaveManager:
			SaveManager.autosave()
		return

	# Check if all players dead
	var players_alive := false
	for c in PartyManager.get_active_characters():
		if c.get("hp", 0) > 0:
			players_alive = true
			break
	if not players_alive:
		phase = CombatPhase.DEFEAT

		# Merge split teams even on defeat to sync status
		if is_split_combat and party_split:
			party_split.merge_teams()
			is_split_combat = false

		combat_ended.emit(CombatPhase.DEFEAT)
