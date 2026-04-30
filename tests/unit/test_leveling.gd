extends GutTest
## Tests for Experience & Leveling System — XP awards, thresholds, level-ups, stat points.


# --- Helpers ---

func _make_test_character(character_id: String) -> Dictionary:
	return {
		"id": character_id,
		"name": "Test Character",
		"hp": 100,
		"hp_max": 100,
		"heat": 0,
		"heat_capacity": 5,
		"xp": 0,
		"level": 1,
		"stat_points": 0,
		"attack_bonus": 0,
		"defense_bonus": 0,
		"lattice_bonus": 0,
		"armor": 10,
		"shields": 10,
		"wards": 5,
	}


func before_each():
	# Clear the roster before each test
	PartyManager.roster.clear()
	PartyManager.active_party.clear()


# ---------------------------------------------------------------------------
# XP Thresholds
# ---------------------------------------------------------------------------

func test_xp_threshold_level_1_to_2():
	assert_eq(PartyManager.get_xp_for_next_level(1), 300, "Level 1→2 requires 300 XP")


func test_xp_threshold_level_2_to_3():
	assert_eq(PartyManager.get_xp_for_next_level(2), 600, "Level 2→3 requires 600 XP")


func test_xp_threshold_level_3_to_4():
	assert_eq(PartyManager.get_xp_for_next_level(3), 900, "Level 3→4 requires 900 XP")


func test_xp_threshold_level_4_to_5():
	assert_eq(PartyManager.get_xp_for_next_level(4), 1200, "Level 4→5 requires 1200 XP")


func test_xp_threshold_max_level():
	assert_eq(PartyManager.get_xp_for_next_level(5), 9999, "Level 5 is max level")


# ---------------------------------------------------------------------------
# XP Award Distribution
# ---------------------------------------------------------------------------

func test_award_xp_to_active_party():
	var char_id := "test_active"
	PartyManager.roster[char_id] = _make_test_character(char_id)
	PartyManager.active_party.append(char_id)

	PartyManager.award_xp(100)

	var c := PartyManager.get_character(char_id)
	assert_eq(c.get("xp", 0), 100, "Active party member receives full XP")


func test_award_xp_to_reserve_party():
	var char_id := "test_reserve"
	PartyManager.roster[char_id] = _make_test_character(char_id)
	# Not in active_party = reserve

	PartyManager.award_xp(100)

	var c := PartyManager.get_character(char_id)
	assert_eq(c.get("xp", 0), 50, "Reserve member receives 50% XP")


func test_award_xp_mixed_party():
	var active_id := "active_char"
	var reserve_id := "reserve_char"
	PartyManager.roster[active_id] = _make_test_character(active_id)
	PartyManager.roster[reserve_id] = _make_test_character(reserve_id)
	PartyManager.active_party.append(active_id)

	PartyManager.award_xp(200)

	assert_eq(PartyManager.get_character(active_id).get("xp", 0), 200, "Active gets full XP")
	assert_eq(PartyManager.get_character(reserve_id).get("xp", 0), 100, "Reserve gets 50% XP")


func test_award_xp_to_individual():
	var char_id := "individual"
	PartyManager.roster[char_id] = _make_test_character(char_id)

	PartyManager.award_xp_to(char_id, 150)

	assert_eq(PartyManager.get_character(char_id).get("xp", 0), 150, "Individual XP award works")


# ---------------------------------------------------------------------------
# Level Up Triggers
# ---------------------------------------------------------------------------

func test_check_level_up_not_enough_xp():
	var char_id := "test"
	PartyManager.roster[char_id] = _make_test_character(char_id)
	PartyManager.roster[char_id]["xp"] = 299

	assert_false(PartyManager.check_level_up(char_id), "299 XP should not trigger level up")


func test_check_level_up_exact_threshold():
	var char_id := "test"
	PartyManager.roster[char_id] = _make_test_character(char_id)
	PartyManager.roster[char_id]["xp"] = 300

	assert_true(PartyManager.check_level_up(char_id), "300 XP should trigger level up")


func test_check_level_up_above_threshold():
	var char_id := "test"
	PartyManager.roster[char_id] = _make_test_character(char_id)
	PartyManager.roster[char_id]["xp"] = 350

	assert_true(PartyManager.check_level_up(char_id), "350 XP should trigger level up")


func test_check_level_up_at_max_level():
	var char_id := "test"
	PartyManager.roster[char_id] = _make_test_character(char_id)
	PartyManager.roster[char_id]["level"] = 5
	PartyManager.roster[char_id]["xp"] = 9999

	assert_false(PartyManager.check_level_up(char_id), "Level 5 cannot level up further")


# ---------------------------------------------------------------------------
# Automatic Level-Up Rewards
# ---------------------------------------------------------------------------

func test_apply_level_up_increments_level():
	var char_id := "test"
	PartyManager.roster[char_id] = _make_test_character(char_id)
	PartyManager.roster[char_id]["xp"] = 300

	PartyManager.apply_level_up(char_id)

	assert_eq(PartyManager.get_character(char_id).get("level", 1), 2, "Level increments to 2")


func test_apply_level_up_deducts_xp():
	var char_id := "test"
	PartyManager.roster[char_id] = _make_test_character(char_id)
	PartyManager.roster[char_id]["xp"] = 350

	PartyManager.apply_level_up(char_id)

	assert_eq(PartyManager.get_character(char_id).get("xp", 0), 50, "XP threshold deducted, 50 remains")


func test_apply_level_up_grants_hp():
	var char_id := "test"
	PartyManager.roster[char_id] = _make_test_character(char_id)
	PartyManager.roster[char_id]["xp"] = 300
	var old_hp_max := PartyManager.roster[char_id]["hp_max"]

	PartyManager.apply_level_up(char_id)

	assert_eq(
		PartyManager.get_character(char_id).get("hp_max", 0),
		old_hp_max + 5,
		"HP max increases by 5"
	)


func test_apply_level_up_grants_heat_capacity():
	var char_id := "test"
	PartyManager.roster[char_id] = _make_test_character(char_id)
	PartyManager.roster[char_id]["xp"] = 300
	var old_heat_cap := PartyManager.roster[char_id]["heat_capacity"]

	PartyManager.apply_level_up(char_id)

	assert_eq(
		PartyManager.get_character(char_id).get("heat_capacity", 5),
		old_heat_cap + 2,
		"Heat capacity increases by 2"
	)


func test_apply_level_up_grants_stat_point():
	var char_id := "test"
	PartyManager.roster[char_id] = _make_test_character(char_id)
	PartyManager.roster[char_id]["xp"] = 300

	PartyManager.apply_level_up(char_id)

	assert_eq(PartyManager.get_character(char_id).get("stat_points", 0), 1, "Grants 1 stat point")


func test_apply_level_up_emits_signal():
	var char_id := "test"
	PartyManager.roster[char_id] = _make_test_character(char_id)
	PartyManager.roster[char_id]["xp"] = 300

	watch_signals(PartyManager)
	PartyManager.apply_level_up(char_id)

	assert_signal_emitted(PartyManager, "level_up", "level_up signal emitted")


# ---------------------------------------------------------------------------
# Multiple Level-Ups
# ---------------------------------------------------------------------------

func test_award_xp_triggers_multiple_level_ups():
	var char_id := "test"
	PartyManager.roster[char_id] = _make_test_character(char_id)

	PartyManager.award_xp_to(char_id, 900)  # Enough for level 1→2→3

	var c := PartyManager.get_character(char_id)
	assert_eq(c.get("level", 1), 3, "Character leveled up twice to level 3")
	assert_eq(c.get("stat_points", 0), 2, "Character has 2 stat points")
	assert_eq(c.get("xp", 0), 0, "XP is 0 after consuming 300+600")


# ---------------------------------------------------------------------------
# Stat Point Assignment
# ---------------------------------------------------------------------------

func test_assign_stat_point_attack():
	var char_id := "test"
	PartyManager.roster[char_id] = _make_test_character(char_id)
	PartyManager.roster[char_id]["stat_points"] = 1

	var success := PartyManager.assign_stat_point(char_id, "Attack")

	assert_true(success, "Attack stat point assigned successfully")
	assert_eq(PartyManager.get_character(char_id).get("attack_bonus", 0), 1, "Attack bonus incremented")
	assert_eq(PartyManager.get_character(char_id).get("stat_points", 1), 0, "Stat point consumed")


func test_assign_stat_point_defense():
	var char_id := "test"
	PartyManager.roster[char_id] = _make_test_character(char_id)
	PartyManager.roster[char_id]["stat_points"] = 1
	var old_armor := PartyManager.roster[char_id]["armor"]
	var old_shields := PartyManager.roster[char_id]["shields"]
	var old_wards := PartyManager.roster[char_id]["wards"]

	var success := PartyManager.assign_stat_point(char_id, "Defense")

	assert_true(success, "Defense stat point assigned successfully")
	var c := PartyManager.get_character(char_id)
	assert_eq(c.get("armor", 0), old_armor + 3, "Armor +3")
	assert_eq(c.get("shields", 0), old_shields + 2, "Shields +2")
	assert_eq(c.get("wards", 0), old_wards + 1, "Wards +1")
	assert_eq(c.get("defense_bonus", 0), 1, "Defense bonus incremented")
	assert_eq(c.get("stat_points", 1), 0, "Stat point consumed")


func test_assign_stat_point_lattice():
	var char_id := "test"
	PartyManager.roster[char_id] = _make_test_character(char_id)
	PartyManager.roster[char_id]["stat_points"] = 1

	var success := PartyManager.assign_stat_point(char_id, "Lattice")

	assert_true(success, "Lattice stat point assigned successfully")
	assert_eq(PartyManager.get_character(char_id).get("lattice_bonus", 0), 1, "Lattice bonus incremented")
	assert_eq(PartyManager.get_character(char_id).get("stat_points", 1), 0, "Stat point consumed")


func test_assign_stat_point_no_points_available():
	var char_id := "test"
	PartyManager.roster[char_id] = _make_test_character(char_id)
	PartyManager.roster[char_id]["stat_points"] = 0

	var success := PartyManager.assign_stat_point(char_id, "Attack")

	assert_false(success, "Cannot assign stat point when none available")
	assert_eq(PartyManager.get_character(char_id).get("attack_bonus", 0), 0, "Attack bonus unchanged")


func test_assign_stat_point_invalid_stat():
	var char_id := "test"
	PartyManager.roster[char_id] = _make_test_character(char_id)
	PartyManager.roster[char_id]["stat_points"] = 1

	var success := PartyManager.assign_stat_point(char_id, "InvalidStat")

	assert_false(success, "Invalid stat name returns false")
	assert_eq(PartyManager.get_character(char_id).get("stat_points", 0), 1, "Stat point not consumed")


# ---------------------------------------------------------------------------
# Level Progress
# ---------------------------------------------------------------------------

func test_get_level_progress_zero():
	var char_id := "test"
	PartyManager.roster[char_id] = _make_test_character(char_id)
	PartyManager.roster[char_id]["xp"] = 0

	var progress := PartyManager.get_level_progress(char_id)

	assert_eq(progress, 0.0, "0 XP = 0% progress")


func test_get_level_progress_half():
	var char_id := "test"
	PartyManager.roster[char_id] = _make_test_character(char_id)
	PartyManager.roster[char_id]["xp"] = 150

	var progress := PartyManager.get_level_progress(char_id)

	assert_almost_eq(progress, 0.5, 0.01, "150/300 XP = 50% progress")


func test_get_level_progress_full():
	var char_id := "test"
	PartyManager.roster[char_id] = _make_test_character(char_id)
	PartyManager.roster[char_id]["xp"] = 300

	var progress := PartyManager.get_level_progress(char_id)

	assert_eq(progress, 1.0, "300/300 XP = 100% progress")


func test_get_level_progress_overflow():
	var char_id := "test"
	PartyManager.roster[char_id] = _make_test_character(char_id)
	PartyManager.roster[char_id]["xp"] = 400

	var progress := PartyManager.get_level_progress(char_id)

	assert_eq(progress, 1.0, "Overflow clamped to 1.0")


# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------

func test_serialization_includes_xp_data():
	var char_id := "test"
	PartyManager.roster[char_id] = _make_test_character(char_id)
	PartyManager.roster[char_id]["xp"] = 250
	PartyManager.roster[char_id]["level"] = 2
	PartyManager.roster[char_id]["stat_points"] = 1
	PartyManager.roster[char_id]["attack_bonus"] = 1
	PartyManager.active_party.append(char_id)

	var save_data := PartyManager.serialize()

	var saved_char = save_data["roster"][char_id]
	assert_eq(saved_char.get("xp", -1), 250, "XP saved")
	assert_eq(saved_char.get("level", -1), 2, "Level saved")
	assert_eq(saved_char.get("stat_points", -1), 1, "Stat points saved")
	assert_eq(saved_char.get("attack_bonus", -1), 1, "Attack bonus saved")


func test_deserialization_restores_xp_data():
	var save_data := {
		"roster": {
			"test": {
				"id": "test",
				"xp": 350,
				"level": 3,
				"stat_points": 2,
				"attack_bonus": 1,
				"defense_bonus": 1,
				"lattice_bonus": 0,
			}
		},
		"active_party": ["test"],
		"loadouts": {},
	}

	PartyManager.deserialize(save_data)

	var c := PartyManager.get_character("test")
	assert_eq(c.get("xp", -1), 350, "XP restored")
	assert_eq(c.get("level", -1), 3, "Level restored")
	assert_eq(c.get("stat_points", -1), 2, "Stat points restored")
	assert_eq(c.get("attack_bonus", -1), 1, "Attack bonus restored")
	assert_eq(c.get("defense_bonus", -1), 1, "Defense bonus restored")
	assert_eq(c.get("lattice_bonus", -1), 0, "Lattice bonus restored")
