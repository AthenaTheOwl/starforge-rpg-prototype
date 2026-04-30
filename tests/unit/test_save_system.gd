extends GutTest
## Unit tests for SaveManager — save/load system.


func before_each() -> void:
	# Clean up any existing test saves
	_cleanup_test_saves()


func after_each() -> void:
	_cleanup_test_saves()


func test_save_game_creates_valid_json() -> void:
	# Setup test state
	GameManager.current_act = 2
	GameManager.current_chapter = 3
	GameManager.set_flag("test_flag", true)
	GameManager.current_location = "test_location"

	# Save to slot 0
	var err := SaveManager.save_game(0)
	assert_eq(err, OK, "Save should succeed")

	# Verify file exists
	assert_true(SaveManager.has_save(0), "Save file should exist")

	# Verify file contains valid JSON
	var file_path := "user://saves/save_0.json"
	var file := FileAccess.open(file_path, FileAccess.READ)
	assert_ne(file, null, "Should be able to open save file")

	var json := JSON.new()
	var parse_err := json.parse(file.get_as_text())
	file.close()

	assert_eq(parse_err, OK, "Save file should contain valid JSON")

	var data: Dictionary = json.data
	assert_true(data.has("version"), "Should have version field")
	assert_true(data.has("timestamp"), "Should have timestamp field")
	assert_true(data.has("party"), "Should have party data")
	assert_true(data.has("game_state"), "Should have game state")


func test_load_game_restores_state_correctly() -> void:
	# Setup test state
	GameManager.current_act = 3
	GameManager.current_chapter = 5
	GameManager.set_flag("important_flag", true)
	GameManager.current_location = "restored_location"
	GameManager.cleared_encounters = ["encounter_1", "encounter_2"]
	GameManager.unlocked_locations = ["loc_1", "loc_2"]

	# Save
	SaveManager.save_game(1)

	# Modify state
	GameManager.current_act = 1
	GameManager.current_chapter = 1
	GameManager.story_flags.clear()
	GameManager.current_location = ""
	GameManager.cleared_encounters.clear()
	GameManager.unlocked_locations.clear()

	# Load
	var err := SaveManager.load_game(1)
	assert_eq(err, OK, "Load should succeed")

	# Verify restoration
	assert_eq(GameManager.current_act, 3, "Act should be restored")
	assert_eq(GameManager.current_chapter, 5, "Chapter should be restored")
	assert_true(GameManager.has_flag("important_flag"), "Flags should be restored")
	assert_eq(GameManager.current_location, "restored_location", "Location should be restored")
	assert_eq(GameManager.cleared_encounters.size(), 2, "Cleared encounters should be restored")
	assert_eq(GameManager.unlocked_locations.size(), 2, "Unlocked locations should be restored")


func test_has_save_returns_correct_values() -> void:
	assert_false(SaveManager.has_save(0), "Slot 0 should be empty initially")

	SaveManager.save_game(0)
	assert_true(SaveManager.has_save(0), "Slot 0 should exist after save")

	assert_false(SaveManager.has_save(1), "Slot 1 should still be empty")


func test_delete_save_removes_file() -> void:
	# Create a save
	SaveManager.save_game(2)
	assert_true(SaveManager.has_save(2), "Save should exist")

	# Delete it
	var err := SaveManager.delete_save(2)
	assert_eq(err, OK, "Delete should succeed")
	assert_false(SaveManager.has_save(2), "Save should no longer exist")


func test_get_save_info_returns_metadata() -> void:
	# Setup and save
	GameManager.current_act = 2
	GameManager.current_chapter = 4
	GameManager.current_location = "test_loc"
	SaveManager.save_game(0)

	# Get info
	var info := SaveManager.get_save_info(0)

	assert_true(info.has("save_name"), "Should have save_name")
	assert_true(info.has("timestamp"), "Should have timestamp")
	assert_true(info.has("playtime_seconds"), "Should have playtime")
	assert_eq(info.get("current_act"), 2, "Should have correct act")
	assert_eq(info.get("current_chapter"), 4, "Should have correct chapter")
	assert_eq(info.get("current_location"), "test_loc", "Should have correct location")


func test_autosave_uses_autosave_slot() -> void:
	GameManager.current_act = 1
	GameManager.current_chapter = 2

	var err := SaveManager.autosave()
	assert_eq(err, OK, "Autosave should succeed")

	# Check autosave exists
	assert_true(SaveManager.has_save(-1), "Autosave should exist")

	# Verify it's separate from manual saves
	assert_false(SaveManager.has_save(0), "Manual slot 0 should be empty")


func test_round_trip_save_load() -> void:
	# Setup complex state
	GameManager.current_act = 3
	GameManager.current_chapter = 7
	GameManager.set_flag("flag1", true)
	GameManager.set_flag("flag2", "custom_value")
	GameManager.modify_reputation("compact", 25)
	GameManager.current_location = "complex_location"
	GameManager.mark_encounter_cleared("boss_fight_1")
	GameManager.unlock_location("secret_area")

	# Save
	SaveManager.save_game(2)

	# Store original values
	var original_act := GameManager.current_act
	var original_chapter := GameManager.current_chapter
	var original_compact_rep := GameManager.get_reputation("compact")
	var original_location := GameManager.current_location

	# Clear state
	GameManager.current_act = 1
	GameManager.current_chapter = 1
	GameManager.story_flags.clear()
	GameManager.faction_reputation["compact"] = 0
	GameManager.current_location = ""
	GameManager.cleared_encounters.clear()
	GameManager.unlocked_locations.clear()

	# Load
	SaveManager.load_game(2)

	# Verify everything matches
	assert_eq(GameManager.current_act, original_act, "Act should match")
	assert_eq(GameManager.current_chapter, original_chapter, "Chapter should match")
	assert_true(GameManager.has_flag("flag1"), "Flag1 should exist")
	assert_eq(GameManager.get_flag("flag2"), "custom_value", "Flag2 should have correct value")
	assert_eq(GameManager.get_reputation("compact"), original_compact_rep, "Reputation should match")
	assert_eq(GameManager.current_location, original_location, "Location should match")
	assert_true(GameManager.is_encounter_cleared("boss_fight_1"), "Encounter should be cleared")
	assert_true(GameManager.is_location_unlocked("secret_area"), "Location should be unlocked")


func test_get_all_save_info() -> void:
	# Create saves in different slots
	GameManager.current_chapter = 1
	SaveManager.save_game(0)

	GameManager.current_chapter = 2
	SaveManager.save_game(1)

	GameManager.current_chapter = 3
	SaveManager.autosave()

	# Get all info
	var all_info := SaveManager.get_all_save_info()

	assert_eq(all_info.size(), 4, "Should return info for 3 manual + 1 autosave")
	assert_eq(all_info[0].get("current_chapter"), 1, "Slot 0 should have chapter 1")
	assert_eq(all_info[1].get("current_chapter"), 2, "Slot 1 should have chapter 2")
	assert_true(all_info[2].is_empty(), "Slot 2 should be empty")
	assert_eq(all_info[3].get("current_chapter"), 3, "Autosave should have chapter 3")


func test_invalid_slot_returns_error() -> void:
	var err := SaveManager.save_game(99)
	assert_eq(err, ERR_INVALID_PARAMETER, "Invalid slot should return error")

	err = SaveManager.load_game(-99)
	assert_eq(err, ERR_INVALID_PARAMETER, "Invalid negative slot should return error")


func test_load_nonexistent_save_returns_error() -> void:
	var err := SaveManager.load_game(2)
	assert_eq(err, ERR_FILE_NOT_FOUND, "Loading nonexistent save should return error")


# Helper to clean up test saves
func _cleanup_test_saves() -> void:
	var dir := DirAccess.open("user://saves/")
	if dir != null:
		for i in range(SaveManager.MAX_MANUAL_SLOTS):
			var filename := "save_%d.json" % i
			if dir.file_exists(filename):
				dir.remove(filename)
		if dir.file_exists("autosave.json"):
			dir.remove("autosave.json")
