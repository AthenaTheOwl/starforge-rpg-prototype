extends GutTest
## Tests for DamageCalculator — damage pipeline, defense matrix, heat, armor degrade, shield regen.


# --- Helpers ---

func _make_source() -> Dictionary:
	return { "id": "src", "heat": 0 }


func _make_target(armor := 10.0, shields := 10.0, wards := 0.0) -> Dictionary:
	return {
		"id": "tgt",
		"armor": armor,
		"shields": shields,
		"shields_max": shields,
		"wards": wards,
		"shield_type": "personal",
		"shield_last_hit_time": 0.0,
	}


# ---------------------------------------------------------------------------
# Pipeline: base -> heat penalty -> defense reduction -> min 1
# ---------------------------------------------------------------------------

func test_pipeline_no_heat_no_defense():
	var src := _make_source()
	var tgt := _make_target(0.0, 0.0)
	var dmg := DamageCalculator.calculate_damage(src, tgt, 20, "physical", 0)
	assert_eq(dmg, 20, "No defenses, no heat: full damage")


func test_pipeline_zero_base_returns_zero():
	var src := _make_source()
	var tgt := _make_target()
	var dmg := DamageCalculator.calculate_damage(src, tgt, 0, "physical", 0)
	assert_eq(dmg, 0, "Zero base damage returns 0")


func test_pipeline_negative_base_returns_zero():
	var src := _make_source()
	var tgt := _make_target()
	var dmg := DamageCalculator.calculate_damage(src, tgt, -5, "physical", 0)
	assert_eq(dmg, 0, "Negative base damage returns 0")


# ---------------------------------------------------------------------------
# Defense matrix
# ---------------------------------------------------------------------------

func test_physical_absorbed_by_armor():
	var src := _make_source()
	var tgt := _make_target(100.0, 0.0)
	var dmg := DamageCalculator.calculate_damage(src, tgt, 20, "physical", 0)
	# Armor absorbs fully (multiplier 1.0), so remaining = 0, min 1
	assert_eq(dmg, 1, "Physical fully absorbed by high armor yields min 1")


func test_thermal_absorbed_by_shield():
	var src := _make_source()
	var tgt := _make_target(0.0, 100.0)
	var dmg := DamageCalculator.calculate_damage(src, tgt, 20, "thermal", 0)
	# Shield absorbs thermal fully (multiplier 1.0)
	assert_eq(dmg, 1, "Thermal fully absorbed by high shield yields min 1")


func test_resonance_bypasses_armor_and_shield():
	var src := _make_source()
	var tgt := _make_target(100.0, 100.0, 0.0)
	var dmg := DamageCalculator.calculate_damage(src, tgt, 20, "resonance", 0)
	# Resonance: armor 0.0, shield 0.0 — no reduction
	assert_eq(dmg, 20, "Resonance bypasses armor and shield completely")


func test_resonance_absorbed_by_ward():
	var src := _make_source()
	var tgt := _make_target(0.0, 0.0, 100.0)
	var dmg := DamageCalculator.calculate_damage(src, tgt, 20, "resonance", 0)
	# Ward absorbs resonance (multiplier 1.0)
	assert_eq(dmg, 1, "Resonance absorbed by ward")


# ---------------------------------------------------------------------------
# Heat penalty
# ---------------------------------------------------------------------------

func test_heat_4_penalty():
	var src := _make_source()
	var tgt := _make_target(0.0, 0.0)
	var dmg := DamageCalculator.calculate_damage(src, tgt, 20, "physical", 4)
	# 20 * 0.75 = 15
	assert_eq(dmg, 15, "Heat 4 applies 0.75x penalty")


func test_heat_5_penalty():
	var src := _make_source()
	var tgt := _make_target(0.0, 0.0)
	var dmg := DamageCalculator.calculate_damage(src, tgt, 20, "physical", 5)
	# 20 * 0.5 = 10
	assert_eq(dmg, 10, "Heat 5 applies 0.5x penalty")


func test_heat_below_4_no_penalty():
	var src := _make_source()
	var tgt := _make_target(0.0, 0.0)
	var dmg := DamageCalculator.calculate_damage(src, tgt, 20, "physical", 3)
	assert_eq(dmg, 20, "Heat 3 has no penalty")


# ---------------------------------------------------------------------------
# Armor degradation
# ---------------------------------------------------------------------------

func test_armor_degrades_on_physical_hit():
	var src := _make_source()
	var tgt := _make_target(20.0, 0.0)
	var original_armor: float = tgt["armor"]
	DamageCalculator.calculate_damage(src, tgt, 10, "physical", 0)
	assert_lt(tgt["armor"], original_armor, "Armor should degrade after physical hit")


func test_armor_degrade_rate():
	var src := _make_source()
	var tgt := _make_target(20.0, 0.0)
	# Physical 10 dmg vs 20 armor: absorbed = min(10, 20*1.0) = 10
	# Degradation = 10 * 0.05 = 0.5
	DamageCalculator.calculate_damage(src, tgt, 10, "physical", 0)
	assert_almost_eq(tgt["armor"], 19.5, 0.01, "Armor degrades by absorbed * 0.05")


func test_armor_degrades_over_sustained_hits():
	var src := _make_source()
	var tgt := _make_target(20.0, 0.0)
	for i in 10:
		DamageCalculator.calculate_damage(src, tgt, 10, "physical", 0)
	assert_lt(tgt["armor"], 20.0, "Armor degrades over multiple hits")
	assert_gt(tgt["armor"], 0.0, "Armor does not go below 0 easily with moderate hits")


# ---------------------------------------------------------------------------
# Shield regeneration
# ---------------------------------------------------------------------------

func test_shield_regen_restores_shields():
	var tgt := _make_target(0.0, 5.0)
	tgt["shields_max"] = 10.0
	tgt["shields"] = 5.0
	# Set last hit time far in the past so regen delay is passed
	tgt["shield_last_hit_time"] = (Time.get_ticks_msec() / 1000.0) - 10.0
	DamageCalculator.tick_shield_regen(tgt, 1.0)
	assert_gt(tgt["shields"], 5.0, "Shield regen should increase shields")


func test_shield_regen_caps_at_max():
	var tgt := _make_target(0.0, 10.0)
	tgt["shields_max"] = 10.0
	tgt["shield_last_hit_time"] = 0.0
	DamageCalculator.tick_shield_regen(tgt, 100.0)
	assert_eq(tgt["shields"], 10.0, "Shield regen should not exceed max")


func test_shield_regen_blocked_during_delay():
	var tgt := _make_target(0.0, 5.0)
	tgt["shields_max"] = 10.0
	# Set last hit time to now (within delay window)
	tgt["shield_last_hit_time"] = Time.get_ticks_msec() / 1000.0
	var before: float = tgt["shields"]
	DamageCalculator.tick_shield_regen(tgt, 1.0)
	assert_eq(tgt["shields"], before, "Shield regen blocked during delay window")


# ---------------------------------------------------------------------------
# Minimum damage
# ---------------------------------------------------------------------------

func test_minimum_damage_is_one():
	var src := _make_source()
	var tgt := _make_target(1000.0, 1000.0, 1000.0)
	var dmg := DamageCalculator.calculate_damage(src, tgt, 1, "physical", 0)
	assert_eq(dmg, 1, "Minimum damage is always 1 when base > 0")
