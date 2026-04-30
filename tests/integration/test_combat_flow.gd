extends GutTest
## Integration tests for CombatManager — encounter setup, turn order, damage,
## status persistence, victory/defeat conditions.


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

var _original_roster: Dictionary = {}
var _original_active: Array[String] = []


func _make_player(id: String, speed: int = 10, hp_max: int = 100) -> Dictionary:
	return {
		"id": id,
		"speed": speed,
		"hp_max": hp_max,
		"hp": hp_max,
		"heat": 0,
		"armor": 5.0,
		"shields": 5.0,
		"shields_max": 5.0,
		"wards": 0.0,
		"statuses": [],
		"abilities": [],
	}


func _make_enemy(hp_max: int = 50, speed: int = 8) -> Dictionary:
	return {
		"id": "enemy_test",
		"name": "Test Foe",
		"hp_max": hp_max,
		"speed": speed,
		"armor": 0.0,
		"shields": 0.0,
		"wards": 0.0,
	}


func _setup_mock_party(players: Array[Dictionary]) -> void:
	_original_roster = PartyManager.roster.duplicate(true)
	_original_active = PartyManager.active_party.duplicate()
	PartyManager.roster.clear()
	PartyManager.active_party.clear()
	for p in players:
		PartyManager.roster[p["id"]] = p
		PartyManager.active_party.append(p["id"])


func _restore_party() -> void:
	PartyManager.roster = _original_roster
	PartyManager.active_party.clear()
	for id in _original_active:
		PartyManager.active_party.append(id)


func after_each():
	_restore_party()
	CombatManager.enemies.clear()
	CombatManager.turn_order.clear()
	CombatManager.phase = CombatManager.CombatPhase.SETUP


# ---------------------------------------------------------------------------
# Setup encounter
# ---------------------------------------------------------------------------

func test_setup_encounter_populates_enemies():
	var enemy_group: Array[Dictionary] = [_make_enemy(50, 8)]
	CombatManager.setup_encounter(enemy_group)
	assert_eq(CombatManager.enemies.size(), 1, "One enemy added")
	assert_eq(CombatManager.enemies[0]["hp"], 50, "Enemy HP initialized to hp_max")
	assert_eq(CombatManager.enemies[0]["heat"], 0, "Enemy heat starts at 0")


# ---------------------------------------------------------------------------
# Turn order sorted by speed
# ---------------------------------------------------------------------------

func test_turn_order_sorted_by_speed():
	var fast_player := _make_player("fast", 20)
	var slow_player := _make_player("slow", 5)
	_setup_mock_party([fast_player, slow_player])

	var enemy_group: Array[Dictionary] = [_make_enemy(50, 10)]
	CombatManager.setup_encounter(enemy_group)
	CombatManager._build_turn_order()

	# Verify descending speed order
	for i in range(CombatManager.turn_order.size() - 1):
		assert_true(
			CombatManager.turn_order[i]["speed"] >= CombatManager.turn_order[i + 1]["speed"],
			"Turn order should be sorted by speed descending"
		)


# ---------------------------------------------------------------------------
# Execute ability: damage applied
# ---------------------------------------------------------------------------

func test_execute_ability_applies_damage():
	var player := _make_player("hero", 15, 100)
	_setup_mock_party([player])

	var enemy_data := _make_enemy(50, 8)
	var enemy_group: Array[Dictionary] = [enemy_data]
	CombatManager.setup_encounter(enemy_group)
	CombatManager._build_turn_order()
	CombatManager.current_turn_index = 0
	CombatManager.phase = CombatManager.CombatPhase.PLAYER_TURN

	var ability := {
		"name": "Test Strike",
		"base_damage": 10,
		"damage_type": "physical",
		"heat_cost": 1,
		"statuses": [],
	}

	var enemy_ref := CombatManager.enemies[0]
	var hp_before: int = enemy_ref["hp"]
	CombatManager.execute_ability("hero", ability, ["enemy_test"])
	assert_lt(enemy_ref["hp"], hp_before, "Enemy HP should decrease after ability")


# ---------------------------------------------------------------------------
# Status effects persist across turns (ticked in _end_of_round)
# ---------------------------------------------------------------------------

func test_status_effects_tick_at_end_of_round():
	var player := _make_player("hero", 15, 100)
	# Apply a burning effect (duration 6, dot 4)
	var burning := StatusEffect.create("burning")
	player["statuses"] = [burning]
	_setup_mock_party([player])

	CombatManager.setup_encounter([_make_enemy(50, 8)] as Array[Dictionary])
	CombatManager._build_turn_order()

	var duration_before: int = burning.duration
	CombatManager._end_of_round()
	assert_lt(burning.duration, duration_before, "Burning duration should decrease after round")


# ---------------------------------------------------------------------------
# Victory: all enemies HP <= 0
# ---------------------------------------------------------------------------

func test_victory_when_all_enemies_dead():
	var player := _make_player("hero", 15, 100)
	_setup_mock_party([player])

	var enemy_group: Array[Dictionary] = [_make_enemy(1, 8)]
	CombatManager.setup_encounter(enemy_group)
	CombatManager._build_turn_order()
	CombatManager.current_turn_index = 0
	CombatManager.phase = CombatManager.CombatPhase.PLAYER_TURN

	# Kill the enemy directly
	CombatManager.enemies[0]["hp"] = 0
	CombatManager._check_combat_end()
	assert_eq(CombatManager.phase, CombatManager.CombatPhase.VICTORY, "Combat ends with VICTORY")


# ---------------------------------------------------------------------------
# Defeat: all players HP <= 0
# ---------------------------------------------------------------------------

func test_defeat_when_all_players_dead():
	var player := _make_player("hero", 15, 100)
	player["hp"] = 0
	_setup_mock_party([player])

	CombatManager.setup_encounter([_make_enemy(50, 8)] as Array[Dictionary])
	CombatManager._build_turn_order()

	CombatManager._check_combat_end()
	assert_eq(CombatManager.phase, CombatManager.CombatPhase.DEFEAT, "Combat ends with DEFEAT")
