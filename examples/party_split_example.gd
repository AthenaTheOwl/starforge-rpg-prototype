extends Node
## Example: How to use the Party Split system in a battle encounter.
##
## This example demonstrates setting up a split encounter for the Act 1 finale,
## where the assault team breaches the main facility while a hold team defends
## the entrance against reinforcements.

## Reference to the battle controller (if extending battle scene)
@onready var split_ui: PartySplitUI = $PartySplitOverlay


func setup_act1_finale_encounter() -> void:
	## Step 1: Define teams
	# Team A: Player-controlled assault team (4 members)
	var assault_team := ["avyanna", "rho", "kael", "cipher"]

	# Team B: AI-controlled hold team (3 members)
	var hold_team := ["sable", "vex", "omega"]

	## Step 2: Define enemies for each team
	# Assault team faces elite enemies in the main facility
	var assault_enemies := [
		{
			"id": "enemy_0",
			"name": "Elite Guard Alpha",
			"hp_max": 100,
			"hp": 100,
			"armor": 15.0,
			"shields": 20.0,
			"speed": 12,
			"attack": 20,
		},
		{
			"id": "enemy_1",
			"name": "Security Mech",
			"hp_max": 120,
			"hp": 120,
			"armor": 25.0,
			"shields": 10.0,
			"speed": 8,
			"attack": 25,
		},
	]

	# Hold team faces raider reinforcements at the entrance
	var hold_enemies := [
		{
			"id": "hold_enemy_0",
			"name": "Rim Raider A",
			"hp_max": 50,
			"hp": 50,
			"armor": 5.0,
			"speed": 10,
			"attack": 12,
		},
		{
			"id": "hold_enemy_1",
			"name": "Rim Raider B",
			"hp_max": 50,
			"hp": 50,
			"armor": 5.0,
			"speed": 10,
			"attack": 12,
		},
		{
			"id": "hold_enemy_2",
			"name": "Rim Raider C",
			"hp_max": 50,
			"hp": 50,
			"armor": 5.0,
			"speed": 10,
			"attack": 12,
		},
	]

	## Step 3: Set up the split encounter
	CombatManager.setup_split_encounter(
		assault_team,
		hold_team,
		assault_enemies,
		hold_enemies
	)

	print("Split encounter initialized!")
	print("  Assault Team (Team A): %s" % str(assault_team))
	print("  Hold Team (Team B): %s" % str(hold_team))
	print("  Team A enemies: %d" % assault_enemies.size())
	print("  Team B enemies: %d" % hold_enemies.size())


func _on_combat_started() -> void:
	## Step 4: Initialize the split UI when combat starts
	if CombatManager.is_split_combat and CombatManager.party_split:
		if split_ui:
			split_ui.setup(CombatManager.party_split)
			split_ui.visible = true
			print("Split UI initialized")


func _on_combat_ended(result: CombatManager.CombatPhase) -> void:
	## Step 5: Clean up split UI when combat ends
	if split_ui:
		split_ui.teardown()

	match result:
		CombatManager.CombatPhase.VICTORY:
			_handle_split_victory()
		CombatManager.CombatPhase.DEFEAT:
			_handle_split_defeat()


func _handle_split_victory() -> void:
	## Handle victory in split combat
	if not CombatManager.party_split:
		return

	var team_b_report := CombatManager.party_split.get_team_b_report()

	if team_b_report["alive_count"] == 0:
		print("Victory, but Team B was defeated!")
		# Could trigger alternative dialogue or consequences
	elif team_b_report["alive_count"] < 2:
		print("Victory! Team B barely survived.")
		# Could trigger "close call" dialogue
	else:
		print("Complete victory! Both teams survived.")
		# Could trigger "perfect execution" dialogue


func _handle_split_defeat() -> void:
	## Handle defeat in split combat
	print("Defeat. Both teams withdraw.")


## Example: Manually change Team B orders mid-combat
func issue_team_b_orders(mode: PartySplit.TeamBMode) -> void:
	if CombatManager.is_split_combat and CombatManager.party_split:
		CombatManager.party_split.set_team_b_orders(mode)
		print("Team B orders changed to: %s" % _get_mode_name(mode))


func _get_mode_name(mode: PartySplit.TeamBMode) -> String:
	match mode:
		PartySplit.TeamBMode.HOLD:
			return "HOLD POSITION"
		PartySplit.TeamBMode.ADVANCE:
			return "ADVANCE"
		PartySplit.TeamBMode.RETREAT:
			return "RETREAT"
		_:
			return "UNKNOWN"


## Example: React to Team B status updates
func _on_team_b_update(report: Dictionary) -> void:
	# This would be connected to CombatManager.team_b_update signal

	# Log important events
	for message in report.get("messages", []):
		print("Team B: %s" % message)

	# Check for critical status
	if report.get("status", "") == "critical":
		# Could show a warning popup or trigger special dialogue
		print("WARNING: Team B in critical condition!")
		# Suggest retreating
		if CombatManager.party_split:
			CombatManager.party_split.set_team_b_orders(PartySplit.TeamBMode.RETREAT)
			print("Auto-issuing RETREAT order to Team B")

	# Check for defeat
	elif report.get("status", "") == "defeated":
		print("Team B has been defeated!")
		# Could trigger narrative consequences or alternative win condition


## Example: Dynamic order changes based on Team A status
func _on_team_a_turn_ended() -> void:
	if not CombatManager.is_split_combat or not CombatManager.party_split:
		return

	# Get Team A status
	var team_a_alive := 0
	var team_a_total_hp := 0
	var team_a_max_hp := 0

	for character in PartyManager.get_active_characters():
		if character.get("hp", 0) > 0:
			team_a_alive += 1
			team_a_total_hp += character.get("hp", 0)
			team_a_max_hp += character.get("hp_max", 100)

	var team_a_hp_percent := float(team_a_total_hp) / float(team_a_max_hp) if team_a_max_hp > 0 else 0.0

	# If Team A is struggling, have Team B advance to help
	if team_a_hp_percent < 0.4 and team_a_alive >= 2:
		CombatManager.party_split.set_team_b_orders(PartySplit.TeamBMode.ADVANCE)
		print("Team A struggling! Team B advancing to provide support.")

	# Get Team B status
	var team_b_report := CombatManager.party_split.get_team_b_report()
	var team_b_hp_percent := float(team_b_report["total_hp"]) / float(team_b_report["total_hp_max"]) if team_b_report["total_hp_max"] > 0 else 0.0

	# If Team B is low on health, retreat
	if team_b_hp_percent < 0.3:
		CombatManager.party_split.set_team_b_orders(PartySplit.TeamBMode.RETREAT)
		print("Team B critically wounded! Ordering retreat and recovery.")


## Example: Load encounter from JSON data file
func load_split_encounter_from_file(path: String) -> void:
	if not FileAccess.file_exists(path):
		push_error("Split encounter file not found: %s" % path)
		return

	var file := FileAccess.open(path, FileAccess.READ)
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("Failed to parse split encounter JSON: %s" % path)
		return

	var data: Dictionary = json.data

	# Expected format:
	# {
	#     "team_a": ["char1", "char2", ...],
	#     "team_b": ["char3", "char4", ...],
	#     "team_a_enemies": [...],
	#     "team_b_enemies": [...]
	# }

	var team_a: Array = data.get("team_a", [])
	var team_b: Array = data.get("team_b", [])
	var team_a_enemies: Array = data.get("team_a_enemies", [])
	var team_b_enemies: Array = data.get("team_b_enemies", [])

	# Convert to typed arrays
	var team_a_ids: Array[String] = []
	var team_b_ids: Array[String] = []
	var team_a_enemy_group: Array[Dictionary] = []
	var team_b_enemy_group: Array[Dictionary] = []

	for id in team_a:
		team_a_ids.append(str(id))
	for id in team_b:
		team_b_ids.append(str(id))
	for enemy in team_a_enemies:
		if enemy is Dictionary:
			team_a_enemy_group.append(enemy)
	for enemy in team_b_enemies:
		if enemy is Dictionary:
			team_b_enemy_group.append(enemy)

	CombatManager.setup_split_encounter(
		team_a_ids,
		team_b_ids,
		team_a_enemy_group,
		team_b_enemy_group
	)

	print("Loaded split encounter from: %s" % path)
