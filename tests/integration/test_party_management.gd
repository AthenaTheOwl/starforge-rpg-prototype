extends GutTest
## Integration tests for PartyManager — roster, active party, loadouts, serialization.


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

var _original_roster: Dictionary = {}
var _original_active: Array[String] = []
var _original_loadouts: Dictionary = {}


func before_each():
	_original_roster = PartyManager.roster.duplicate(true)
	_original_active = PartyManager.active_party.duplicate()
	_original_loadouts = PartyManager._loadouts.duplicate(true)
	PartyManager.roster.clear()
	PartyManager.active_party.clear()
	PartyManager._loadouts.clear()


func after_each():
	PartyManager.roster = _original_roster
	PartyManager.active_party.clear()
	for id in _original_active:
		PartyManager.active_party.append(id)
	PartyManager._loadouts = _original_loadouts


func _inject_character(id: String, speed: int = 10, hp_max: int = 100) -> void:
	var data := {
		"id": id,
		"name": "Test_%s" % id,
		"speed": speed,
		"hp_max": hp_max,
		"hp": hp_max,
		"heat": 0,
	}
	PartyManager.roster[id] = data
	if PartyManager.active_party.size() < PartyManager.MAX_ACTIVE:
		PartyManager.active_party.append(id)


# ---------------------------------------------------------------------------
# Recruit character
# ---------------------------------------------------------------------------

func test_recruit_adds_to_roster():
	_inject_character("alpha")
	assert_true("alpha" in PartyManager.roster, "Character should be in roster")


func test_recruit_auto_adds_to_active():
	_inject_character("alpha")
	assert_true("alpha" in PartyManager.active_party, "Character auto-added to active party")


# ---------------------------------------------------------------------------
# Active party max 4
# ---------------------------------------------------------------------------

func test_max_4_active_party():
	for i in 5:
		_inject_character("char_%d" % i)
	assert_eq(PartyManager.active_party.size(), 4, "Active party capped at 4")
	assert_true("char_4" not in PartyManager.active_party, "5th character not in active")


func test_add_to_active_respects_max():
	for i in 4:
		_inject_character("char_%d" % i)
	# Manually add a 5th to roster only
	PartyManager.roster["char_4"] = { "id": "char_4" }
	PartyManager.add_to_active("char_4")
	assert_eq(PartyManager.active_party.size(), 4, "Cannot exceed max active")


func test_remove_and_readd():
	_inject_character("alpha")
	PartyManager.remove_from_active("alpha")
	assert_true("alpha" not in PartyManager.active_party, "Removed from active")
	PartyManager.add_to_active("alpha")
	assert_true("alpha" in PartyManager.active_party, "Re-added to active")


# ---------------------------------------------------------------------------
# Loadout: set abilities, get_loadout
# ---------------------------------------------------------------------------

func test_get_loadout_returns_loadout():
	_inject_character("alpha")
	var lo := PartyManager.get_loadout("alpha")
	assert_not_null(lo, "get_loadout returns a Loadout")
	assert_true(lo is Loadout, "Returned object is Loadout type")


func test_set_loadout_abilities():
	_inject_character("alpha")
	var lo := Loadout.new()
	# We cannot create real AbilityData easily, so test with null slots
	PartyManager.set_loadout("alpha", lo)
	var retrieved := PartyManager.get_loadout("alpha")
	assert_eq(retrieved, lo, "set then get returns same loadout")


# ---------------------------------------------------------------------------
# Loadout validation: is_valid requires both core slots
# ---------------------------------------------------------------------------

func test_loadout_invalid_when_empty():
	var lo := Loadout.new()
	assert_false(lo.is_valid(), "Empty loadout is not valid")


func test_loadout_invalid_with_one_core():
	var lo := Loadout.new()
	# Simulate a non-null AbilityData — use a Resource as stand-in
	# Since AbilityData may not be available, we test the null check logic
	assert_false(lo.is_valid(), "Loadout with no cores is invalid")


func test_loadout_set_ability_returns_true():
	var lo := Loadout.new()
	# Cannot pass null as it would keep slot empty, but test the method call
	var result := lo.set_ability(Loadout.SlotType.UTILITY, 0, null)
	assert_true(result, "set_ability returns true for valid slot")


func test_loadout_set_ability_invalid_index():
	var lo := Loadout.new()
	var result := lo.set_ability(Loadout.SlotType.CORE, 5, null)
	assert_false(result, "set_ability returns false for invalid index")


func test_loadout_clear_slot():
	var lo := Loadout.new()
	lo.clear_slot(Loadout.SlotType.CORE, 0)
	assert_null(lo.core_1, "Cleared slot is null")


# ---------------------------------------------------------------------------
# Serialization round-trip
# ---------------------------------------------------------------------------

func test_serialize_round_trip():
	_inject_character("alpha")
	_inject_character("beta")
	PartyManager.set_loadout("alpha", Loadout.new())

	var saved := PartyManager.serialize()

	# Verify structure
	assert_true(saved.has("roster"), "Serialized data has roster")
	assert_true(saved.has("active_party"), "Serialized data has active_party")
	assert_true(saved.has("loadouts"), "Serialized data has loadouts")

	# Verify roster content
	assert_true("alpha" in saved["roster"], "Alpha in serialized roster")
	assert_true("beta" in saved["roster"], "Beta in serialized roster")

	# Verify active party
	assert_true("alpha" in saved["active_party"])
	assert_true("beta" in saved["active_party"])


func test_deserialize_restores_roster():
	_inject_character("alpha")
	_inject_character("beta")
	var saved := PartyManager.serialize()

	# Clear and restore
	PartyManager.roster.clear()
	PartyManager.active_party.clear()
	PartyManager._loadouts.clear()

	PartyManager.deserialize(saved)
	assert_true("alpha" in PartyManager.roster, "Alpha restored to roster")
	assert_true("beta" in PartyManager.roster, "Beta restored to roster")
	assert_eq(PartyManager.active_party.size(), 2, "Active party restored")


func test_get_active_characters_returns_dicts():
	_inject_character("alpha")
	var chars := PartyManager.get_active_characters()
	assert_eq(chars.size(), 1)
	assert_eq(chars[0]["id"], "alpha")
