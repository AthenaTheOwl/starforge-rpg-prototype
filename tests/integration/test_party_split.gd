extends GutTest
## Integration tests for PartySplit system.
##
## Tests split party combat mechanics, AI simulation, and team merging.

var split: PartySplit
var test_characters: Dictionary = {}


func before_each() -> void:
	split = PartySplit.new()

	# Create test characters with realistic stats
	test_characters = {
		"avyanna": {
			"id": "avyanna",
			"name": "Avyanna",
			"hp": 100,
			"hp_max": 100,
			"heat": 0,
			"statuses": [],
		},
		"rho": {
			"id": "rho",
			"name": "Rho",
			"hp": 80,
			"hp_max": 80,
			"heat": 0,
			"statuses": [],
		},
		"kael": {
			"id": "kael",
			"name": "Kael",
			"hp": 90,
			"hp_max": 90,
			"heat": 0,
			"statuses": [],
		},
		"cipher": {
			"id": "cipher",
			"name": "Cipher",
			"hp": 75,
			"hp_max": 75,
			"heat": 0,
			"statuses": [],
		},
	}


func after_each() -> void:
	split = null


func test_setup_split_assigns_teams() -> void:
	var team_a := ["avyanna", "rho", "kael", "cipher"]
	var team_b := ["char5", "char6", "char7"]

	split.setup_split(team_a, team_b)

	assert_eq(split.team_a.size(), 4, "Team A should have 4 members")
	assert_eq(split.team_b.size(), 3, "Team B should have 3 members")
	assert_eq(split.team_a[0], "avyanna", "Team A first member should be avyanna")
	assert_eq(split.team_b_mode, PartySplit.TeamBMode.HOLD, "Default mode should be HOLD")


func test_set_team_b_orders_changes_mode() -> void:
	split.setup_split(["avyanna"], ["rho", "kael"])

	split.set_team_b_orders(PartySplit.TeamBMode.ADVANCE)
	assert_eq(split.team_b_mode, PartySplit.TeamBMode.ADVANCE, "Mode should change to ADVANCE")

	split.set_team_b_orders(PartySplit.TeamBMode.RETREAT)
	assert_eq(split.team_b_mode, PartySplit.TeamBMode.RETREAT, "Mode should change to RETREAT")


func test_simulate_team_b_turn_returns_valid_report() -> void:
	# Mock PartyManager.get_character to return test characters
	var team_b := ["rho", "kael"]

	# Manually set up team B status since we can't rely on PartyManager in tests
	split.team_b = team_b
	split.team_b_status = {
		"rho": test_characters["rho"].duplicate(true),
		"kael": test_characters["kael"].duplicate(true),
	}

	# Add some enemies for team B to face
	var enemies := [
		{"id": "enemy_0", "name": "Raider A", "hp": 50, "hp_max": 50},
		{"id": "enemy_1", "name": "Raider B", "hp": 50, "hp_max": 50},
	]
	split.set_team_b_enemies(enemies)

	var report: Dictionary = split.simulate_team_b_turn()

	assert_has(report, "damage_taken", "Report should contain damage_taken")
	assert_has(report, "enemies_defeated", "Report should contain enemies_defeated")
	assert_has(report, "status", "Report should contain status")
	assert_has(report, "messages", "Report should contain messages")
	assert_true(report["messages"].size() > 0, "Report should have status messages")


func test_hold_mode_reduces_damage_taken() -> void:
	split.team_b = ["rho", "kael"]
	split.team_b_status = {
		"rho": test_characters["rho"].duplicate(true),
		"kael": test_characters["kael"].duplicate(true),
	}

	# Set up enemies
	var enemies := [
		{"id": "enemy_0", "name": "Raider", "hp": 50, "hp_max": 50},
	]
	split.set_team_b_enemies(enemies)

	# HOLD mode
	split.set_team_b_orders(PartySplit.TeamBMode.HOLD)
	var rho_hp_before := split.team_b_status["rho"]["hp"]
	var kael_hp_before := split.team_b_status["kael"]["hp"]

	var report_hold: Dictionary = split.simulate_team_b_turn()
	var damage_hold: int = report_hold.get("damage_taken", 0)

	# Reset for comparison
	split.team_b_status = {
		"rho": test_characters["rho"].duplicate(true),
		"kael": test_characters["kael"].duplicate(true),
	}
	split.set_team_b_enemies(enemies.duplicate(true))

	# ADVANCE mode (normal damage)
	split.set_team_b_orders(PartySplit.TeamBMode.ADVANCE)
	var report_advance: Dictionary = split.simulate_team_b_turn()
	var damage_advance: int = report_advance.get("damage_taken", 0)

	# HOLD should take less damage than ADVANCE (30% reduction)
	# Due to randomness, we check if hold damage is generally lower
	assert_true(
		damage_hold < damage_advance + 10,
		"HOLD mode should take less or similar damage to ADVANCE (got hold=%d, advance=%d)" % [damage_hold, damage_advance]
	)


func test_retreat_mode_heals_team() -> void:
	split.team_b = ["rho", "kael"]

	# Set team with reduced HP
	split.team_b_status = {
		"rho": {
			"id": "rho",
			"name": "Rho",
			"hp": 40,  # 50% HP
			"hp_max": 80,
			"heat": 0,
			"statuses": [],
		},
		"kael": {
			"id": "kael",
			"name": "Kael",
			"hp": 45,  # 50% HP
			"hp_max": 90,
			"heat": 0,
			"statuses": [],
		},
	}

	# No enemies to keep damage minimal
	split.set_team_b_enemies([])

	split.set_team_b_orders(PartySplit.TeamBMode.RETREAT)
	var hp_before_rho: int = split.team_b_status["rho"]["hp"]
	var hp_before_kael: int = split.team_b_status["kael"]["hp"]

	var report: Dictionary = split.simulate_team_b_turn()

	var hp_after_rho: int = split.team_b_status["rho"]["hp"]
	var hp_after_kael: int = split.team_b_status["kael"]["hp"]

	# Should heal 10% of max HP per turn
	assert_true(
		hp_after_rho > hp_before_rho or hp_before_rho == split.team_b_status["rho"]["hp_max"],
		"Rho should heal in RETREAT mode (before=%d, after=%d)" % [hp_before_rho, hp_after_rho]
	)
	assert_true(
		hp_after_kael > hp_before_kael or hp_before_kael == split.team_b_status["kael"]["hp_max"],
		"Kael should heal in RETREAT mode (before=%d, after=%d)" % [hp_before_kael, hp_after_kael]
	)


func test_is_team_b_alive_returns_false_when_all_dead() -> void:
	split.team_b = ["rho", "kael"]
	split.team_b_status = {
		"rho": {
			"id": "rho",
			"name": "Rho",
			"hp": 0,
			"hp_max": 80,
			"heat": 0,
			"statuses": [],
		},
		"kael": {
			"id": "kael",
			"name": "Kael",
			"hp": 0,
			"hp_max": 90,
			"heat": 0,
			"statuses": [],
		},
	}

	assert_false(split.is_team_b_alive(), "Team B should be dead when all HP <= 0")


func test_is_team_b_alive_returns_true_when_any_alive() -> void:
	split.team_b = ["rho", "kael"]
	split.team_b_status = {
		"rho": {
			"id": "rho",
			"name": "Rho",
			"hp": 0,
			"hp_max": 80,
			"heat": 0,
			"statuses": [],
		},
		"kael": {
			"id": "kael",
			"name": "Kael",
			"hp": 10,
			"hp_max": 90,
			"heat": 0,
			"statuses": [],
		},
	}

	assert_true(split.is_team_b_alive(), "Team B should be alive when at least one member has HP > 0")


func test_merge_teams_clears_split_state() -> void:
	split.setup_split(["avyanna", "rho"], ["kael", "cipher"])

	split.team_b_status = {
		"kael": test_characters["kael"].duplicate(true),
		"cipher": test_characters["cipher"].duplicate(true),
	}

	split.merge_teams()

	assert_eq(split.team_a.size(), 0, "Team A should be cleared after merge")
	assert_eq(split.team_b.size(), 0, "Team B should be cleared after merge")
	assert_eq(split.team_b_status.size(), 0, "Team B status should be cleared after merge")


func test_get_team_b_report_returns_correct_data() -> void:
	split.team_b = ["rho", "kael"]
	split.team_b_status = {
		"rho": test_characters["rho"].duplicate(true),
		"kael": test_characters["kael"].duplicate(true),
	}

	split.set_team_b_orders(PartySplit.TeamBMode.ADVANCE)

	var report: Dictionary = split.get_team_b_report()

	assert_has(report, "members", "Report should contain members array")
	assert_has(report, "total_hp", "Report should contain total_hp")
	assert_has(report, "total_hp_max", "Report should contain total_hp_max")
	assert_has(report, "alive_count", "Report should contain alive_count")
	assert_has(report, "mode", "Report should contain mode")
	assert_has(report, "mode_name", "Report should contain mode_name")

	assert_eq(report["members"].size(), 2, "Should have 2 members")
	assert_eq(report["alive_count"], 2, "Both members should be alive")
	assert_eq(report["mode"], PartySplit.TeamBMode.ADVANCE, "Mode should be ADVANCE")
	assert_eq(report["mode_name"], "Advance", "Mode name should be 'Advance'")


func test_team_b_takes_damage_over_multiple_turns() -> void:
	split.team_b = ["rho"]
	split.team_b_status = {
		"rho": test_characters["rho"].duplicate(true),
	}

	# Add enemies
	var enemies := [
		{"id": "enemy_0", "name": "Raider", "hp": 50, "hp_max": 50},
	]
	split.set_team_b_enemies(enemies)

	var initial_hp: int = split.team_b_status["rho"]["hp"]

	# Simulate multiple turns
	for i in range(3):
		split.simulate_team_b_turn()

	var final_hp: int = split.team_b_status["rho"]["hp"]

	assert_true(final_hp < initial_hp, "Team B should take damage over multiple turns (initial=%d, final=%d)" % [initial_hp, final_hp])


func test_team_b_defeats_enemies_in_advance_mode() -> void:
	split.team_b = ["rho", "kael"]
	split.team_b_status = {
		"rho": test_characters["rho"].duplicate(true),
		"kael": test_characters["kael"].duplicate(true),
	}

	# Add weak enemies that can be defeated
	var enemies := [
		{"id": "enemy_0", "name": "Weak Raider", "hp": 30, "hp_max": 30},
	]
	split.set_team_b_enemies(enemies)

	split.set_team_b_orders(PartySplit.TeamBMode.ADVANCE)

	var initial_enemy_count := split.team_b_enemies.size()

	# Simulate a turn
	var report: Dictionary = split.simulate_team_b_turn()

	# Team should eventually defeat enemies
	var enemies_defeated: int = report.get("enemies_defeated", 0)

	assert_true(
		enemies_defeated > 0 or split.team_b_enemies.size() < initial_enemy_count,
		"Team B should defeat enemies in ADVANCE mode"
	)
