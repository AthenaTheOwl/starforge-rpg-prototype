extends GutTest
## Tests for StatusEffect — factory creation, tick, expiry, permissions, cleansing.


# ---------------------------------------------------------------------------
# Factory: create each of the 12 effects
# ---------------------------------------------------------------------------

var ALL_EFFECT_IDS := [
	"silenced", "jammed", "bound", "blinded", "grounded",
	"bleeding", "burning", "corroding", "shocked",
	"marked", "resonance_drain", "ghost_touch",
]


func test_create_all_12_effects():
	for eid in ALL_EFFECT_IDS:
		var e := StatusEffect.create(eid)
		assert_eq(e.id, eid, "Effect id matches for %s" % eid)
		assert_ne(e.display_name, "", "Display name set for %s" % eid)


func test_create_silenced():
	var e := StatusEffect.create("silenced")
	assert_eq(e.category, StatusEffect.Category.CONTROL)
	assert_eq(e.duration, 6)
	assert_true(e.prevents_casting, "Silenced prevents casting")


func test_create_bound():
	var e := StatusEffect.create("bound")
	assert_true(e.prevents_movement, "Bound prevents movement")
	assert_eq(e.duration, 5)


func test_create_blinded():
	var e := StatusEffect.create("blinded")
	assert_true(e.stat_modifiers.has("accuracy"), "Blinded has accuracy modifier")
	assert_eq(e.stat_modifiers["accuracy"], -0.5)


func test_create_bleeding():
	var e := StatusEffect.create("bleeding")
	assert_eq(e.category, StatusEffect.Category.DOT)
	assert_eq(e.duration, -1, "Bleeding lasts until cleansed")
	assert_eq(e.dot_damage, 3)


func test_create_corroding():
	var e := StatusEffect.create("corroding")
	assert_eq(e.dot_damage, 0, "Corroding deals no HP damage")
	assert_eq(e.extra.get("armor_degrade_per_tick", 0), 2)


func test_create_override_duration():
	var e := StatusEffect.create("burning", 2)
	assert_eq(e.duration, 2, "Override duration works")


# ---------------------------------------------------------------------------
# tick() — DoT damage
# ---------------------------------------------------------------------------

func test_tick_bleeding_returns_dot_damage():
	var e := StatusEffect.create("bleeding")
	var combatant := { "armor": 10.0, "moved_this_round": false }
	var dmg := e.tick(combatant)
	assert_eq(dmg, 3, "Bleeding tick deals 3 damage")


func test_tick_bleeding_double_on_move():
	var e := StatusEffect.create("bleeding")
	var combatant := { "armor": 10.0, "moved_this_round": true }
	var dmg := e.tick(combatant)
	assert_eq(dmg, 6, "Bleeding doubles when target moved")


func test_tick_burning_returns_dot_damage():
	var e := StatusEffect.create("burning")
	var combatant := { "armor": 10.0 }
	var dmg := e.tick(combatant)
	assert_eq(dmg, 4, "Burning tick deals 4 damage")


func test_tick_corroding_degrades_armor():
	var e := StatusEffect.create("corroding")
	var combatant := { "armor": 10.0 }
	var dmg := e.tick(combatant)
	assert_eq(dmg, 0, "Corroding deals 0 HP damage")
	assert_eq(combatant["armor"], 8.0, "Corroding reduces armor by 2 per tick")


func test_tick_corroding_armor_floor_zero():
	var e := StatusEffect.create("corroding")
	var combatant := { "armor": 1.0 }
	e.tick(combatant)
	assert_eq(combatant["armor"], 0.0, "Armor does not go below 0")


# ---------------------------------------------------------------------------
# is_expired()
# ---------------------------------------------------------------------------

func test_is_expired_after_duration_depleted():
	var e := StatusEffect.create("burning", 1)
	var combatant := { "armor": 0.0 }
	assert_false(e.is_expired(), "Not expired before tick")
	e.tick(combatant)
	assert_true(e.is_expired(), "Expired after duration reaches 0")


func test_infinite_duration_never_expires():
	var e := StatusEffect.create("bleeding")  # duration = -1
	var combatant := { "armor": 0.0, "moved_this_round": false }
	for i in 20:
		e.tick(combatant)
	assert_false(e.is_expired(), "Infinite duration never expires via tick")


# ---------------------------------------------------------------------------
# can_act, can_move, can_cast
# ---------------------------------------------------------------------------

func test_silenced_can_act_but_not_cast():
	var e := StatusEffect.create("silenced")
	assert_true(e.can_act(), "Silenced can still act")
	assert_true(e.can_move(), "Silenced can still move")
	assert_false(e.can_cast(), "Silenced cannot cast")


func test_bound_cannot_move():
	var e := StatusEffect.create("bound")
	assert_true(e.can_act(), "Bound can act")
	assert_false(e.can_move(), "Bound cannot move")
	assert_true(e.can_cast(), "Bound can cast")


func test_bleeding_no_restrictions():
	var e := StatusEffect.create("bleeding")
	assert_true(e.can_act())
	assert_true(e.can_move())
	assert_true(e.can_cast())


# ---------------------------------------------------------------------------
# can_cleanse(method)
# ---------------------------------------------------------------------------

func test_cleanse_generic_removes_control():
	var e := StatusEffect.create("silenced")
	assert_true(e.can_cleanse("cleanse"), "Generic cleanse removes control effects")


func test_cleanse_generic_removes_dot():
	var e := StatusEffect.create("burning")
	assert_true(e.can_cleanse("cleanse"), "Generic cleanse removes DoT effects")


func test_cleanse_generic_does_not_remove_special():
	var e := StatusEffect.create("marked")
	assert_false(e.can_cleanse("cleanse"), "Generic cleanse does not remove special effects")


func test_sever_removes_magic_tagged():
	var e := StatusEffect.create("silenced")
	assert_true(e.can_cleanse("sever"), "Sever removes magic-tagged effects")


func test_null_salts_removes_jammed():
	var e := StatusEffect.create("jammed")
	assert_true(e.can_cleanse("null_salts"), "Null salts removes tech-tagged effects")


func test_med_removes_bleeding():
	var e := StatusEffect.create("bleeding")
	assert_true(e.can_cleanse("med"), "Med removes bleeding")


func test_ground_removes_shocked():
	var e := StatusEffect.create("shocked")
	assert_true(e.can_cleanse("ground"), "Ground removes shocked")


func test_reduce_debt_removes_marked():
	var e := StatusEffect.create("marked")
	assert_true(e.can_cleanse("reduce_debt"), "Reduce debt removes marked")


func test_destroy_source_removes_ghost_touch():
	var e := StatusEffect.create("ghost_touch")
	assert_true(e.can_cleanse("destroy_source"), "Destroy source removes ghost touch")


func test_unknown_method_cleanses_nothing():
	for eid in ALL_EFFECT_IDS:
		var e := StatusEffect.create(eid)
		assert_false(e.can_cleanse("random_nonsense"), "Unknown method cleanses nothing for %s" % eid)
