class_name PartySplit
extends RefCounted
## PartySplit — Manages split party combat for Act 1 finale.
##
## Player controls team_a directly in combat while team_b is AI-controlled
## with basic player-issued orders. Used during mission split encounters
## where the party divides to handle multiple objectives.

enum TeamBMode { HOLD, ADVANCE, RETREAT }

## Team A: Player-controlled assault team (4 characters)
var team_a: Array[String] = []
## Team B: AI-controlled hold team (3 characters)
var team_b: Array[String] = []
## Team B current orders
var team_b_mode: TeamBMode = TeamBMode.HOLD
## Team B status tracking: { char_id: { hp: int, hp_max: int, statuses: Array } }
var team_b_status: Dictionary = {}

## Enemy group facing team B (simulated encounters)
var team_b_enemies: Array[Dictionary] = []


## Set up the party split with specified teams.
func setup_split(team_a_ids: Array[String], team_b_ids: Array[String]) -> void:
	team_a = team_a_ids.duplicate()
	team_b = team_b_ids.duplicate()
	team_b_mode = TeamBMode.HOLD
	team_b_status.clear()
	team_b_enemies.clear()

	# Initialize team B status from PartyManager
	for char_id in team_b:
		var character := PartyManager.get_character(char_id)
		if character.is_empty():
			continue

		team_b_status[char_id] = {
			"hp": character.get("hp", 100),
			"hp_max": character.get("hp_max", 100),
			"heat": character.get("heat", 0),
			"statuses": character.get("statuses", []).duplicate(true),
			"name": character.get("name", char_id),
		}


## Player issues orders to team B.
func set_team_b_orders(mode: int) -> void:
	if mode >= 0 and mode < TeamBMode.size():
		team_b_mode = mode as TeamBMode


## Simulate team B's turn during split combat.
## Returns a report of what happened: { damage_taken, enemies_defeated, status, messages }
func simulate_team_b_turn() -> Dictionary:
	var report := {
		"damage_taken": 0,
		"enemies_defeated": 0,
		"status": "active",
		"messages": [],
	}

	if not is_team_b_alive():
		report["status"] = "defeated"
		report["messages"].append("Team B has fallen!")
		return report

	# Calculate team B effectiveness based on mode
	var defense_mult := 1.0
	var damage_mult := 1.0
	var heal_per_turn := 0.0

	match team_b_mode:
		TeamBMode.HOLD:
			defense_mult = 0.7  # Take 30% less damage
			damage_mult = 0.5   # Deal 50% less damage
			report["messages"].append("Team B holding defensive position.")
		TeamBMode.ADVANCE:
			defense_mult = 1.0  # Normal damage/defense
			damage_mult = 1.0
			report["messages"].append("Team B advancing aggressively.")
		TeamBMode.RETREAT:
			defense_mult = 0.5  # Take 50% less damage
			damage_mult = 0.0   # Deal no damage
			heal_per_turn = 0.1 # Heal 10% HP/turn
			report["messages"].append("Team B retreating and recovering.")

	# Simulate enemy encounters for team B
	# Base enemy damage per turn (simplified AI combat)
	var base_enemy_damage := 15 * team_b_enemies.size()
	var actual_damage := int(float(base_enemy_damage) * defense_mult)

	# Distribute damage across team B members
	var alive_count := 0
	for char_id in team_b:
		if team_b_status[char_id]["hp"] > 0:
			alive_count += 1

	if alive_count > 0:
		var damage_per_member := actual_damage / alive_count

		for char_id in team_b:
			var member: Dictionary = team_b_status[char_id]
			if member["hp"] <= 0:
				continue

			# Apply damage
			var member_damage := damage_per_member + randi_range(-3, 3)  # Variance
			member["hp"] = maxi(member["hp"] - member_damage, 0)
			report["damage_taken"] += member_damage

			if member["hp"] > 0:
				# Apply healing if retreating
				if heal_per_turn > 0.0:
					var heal_amount := int(float(member["hp_max"]) * heal_per_turn)
					member["hp"] = mini(member["hp"] + heal_amount, member["hp_max"])
					report["messages"].append("%s recovered %d HP." % [member["name"], heal_amount])

				# Log damage taken
				if member_damage > 0:
					report["messages"].append("%s took %d damage." % [member["name"], member_damage])
			else:
				report["messages"].append("%s has fallen!" % member["name"])

	# Team B deals damage back to enemies (if not retreating)
	if damage_mult > 0.0:
		var base_team_damage := 20 * alive_count
		var actual_team_damage := int(float(base_team_damage) * damage_mult)

		# Simulate defeating enemies
		var enemies_defeated := 0
		var remaining_damage := actual_team_damage

		for i in range(team_b_enemies.size() - 1, -1, -1):
			if remaining_damage <= 0:
				break

			var enemy: Dictionary = team_b_enemies[i]
			var enemy_hp: int = enemy.get("hp", 50)

			if remaining_damage >= enemy_hp:
				remaining_damage -= enemy_hp
				team_b_enemies.remove_at(i)
				enemies_defeated += 1
			else:
				enemy["hp"] = enemy_hp - remaining_damage
				remaining_damage = 0

		if enemies_defeated > 0:
			report["enemies_defeated"] = enemies_defeated
			report["messages"].append("Team B defeated %d %s." % [
				enemies_defeated,
				"enemy" if enemies_defeated == 1 else "enemies"
			])

	# Check if team B is still alive
	if not is_team_b_alive():
		report["status"] = "defeated"
		report["messages"].append("Team B has been defeated!")
	elif _is_team_b_critical():
		report["status"] = "critical"
		report["messages"].append("WARNING: Team B is in critical condition!")

	return report


## Get current status of team B for UI display.
func get_team_b_report() -> Dictionary:
	var members := []
	var total_hp := 0
	var total_hp_max := 0
	var alive_count := 0

	for char_id in team_b:
		var member: Dictionary = team_b_status.get(char_id, {})
		if member.is_empty():
			continue

		var hp: int = member.get("hp", 0)
		var hp_max: int = member.get("hp_max", 100)

		members.append({
			"id": char_id,
			"name": member.get("name", char_id),
			"hp": hp,
			"hp_max": hp_max,
			"hp_percent": float(hp) / float(hp_max) if hp_max > 0 else 0.0,
			"alive": hp > 0,
		})

		total_hp += hp
		total_hp_max += hp_max
		if hp > 0:
			alive_count += 1

	return {
		"members": members,
		"total_hp": total_hp,
		"total_hp_max": total_hp_max,
		"alive_count": alive_count,
		"mode": team_b_mode,
		"mode_name": _get_mode_name(team_b_mode),
		"enemies_remaining": team_b_enemies.size(),
	}


## Check if any team B member is still alive.
func is_team_b_alive() -> bool:
	for char_id in team_b:
		var member: Dictionary = team_b_status.get(char_id, {})
		if member.get("hp", 0) > 0:
			return true
	return false


## Check if team B is in critical condition (any member below 30% HP).
func _is_team_b_critical() -> bool:
	for char_id in team_b:
		var member: Dictionary = team_b_status.get(char_id, {})
		var hp: int = member.get("hp", 0)
		var hp_max: int = member.get("hp_max", 100)

		if hp > 0 and hp < hp_max * 0.3:
			return true
	return false


## Merge teams back together after split mission completes.
## Syncs team B status back to PartyManager.
func merge_teams() -> void:
	# Sync team B status back to PartyManager
	for char_id in team_b:
		var member: Dictionary = team_b_status.get(char_id, {})
		if member.is_empty():
			continue

		var character := PartyManager.get_character(char_id)
		if character.is_empty():
			continue

		# Update HP and statuses
		character["hp"] = member.get("hp", character.get("hp", 100))
		character["heat"] = member.get("heat", 0)
		character["statuses"] = member.get("statuses", []).duplicate(true)

	# Clear split state
	team_a.clear()
	team_b.clear()
	team_b_status.clear()
	team_b_enemies.clear()


## Add enemies for team B to face (for simulation).
func set_team_b_enemies(enemies: Array[Dictionary]) -> void:
	team_b_enemies = enemies.duplicate(true)


## Get mode name for display.
func _get_mode_name(mode: TeamBMode) -> String:
	match mode:
		TeamBMode.HOLD:
			return "Hold Position"
		TeamBMode.ADVANCE:
			return "Advance"
		TeamBMode.RETREAT:
			return "Retreat"
		_:
			return "Unknown"
