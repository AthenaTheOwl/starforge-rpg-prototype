extends GutTest
## Compile the actual HPBar and exercise Range signals, labels and tween updates.

func test_direct_value_and_max_changes_refresh_label_and_color():
	var bar := HPBar.new()
	add_child_autofree(bar)
	bar.set_hp_max(100, 85, false)
	assert_eq(bar._label.text, "HP: 85/100")
	assert_eq(bar.get_theme_stylebox("fill").bg_color, ThemeManager.COLOR_SUCCESS)
	bar.value = 20
	assert_eq(bar._label.text, "HP: 20/100", "A built-in Range value assignment emits an actual update")
	assert_eq(bar.get_theme_stylebox("fill").bg_color, ThemeManager.COLOR_DANGER)
	bar.max_value = 200
	assert_eq(bar._label.text, "HP: 20/200", "Range limits also refresh the overlay")


func test_animated_hp_change_finishes_with_updated_range_and_label():
	var bar := HPBar.new()
	add_child_autofree(bar)
	bar.set_hp_max(100, 80, false)
	bar.set_hp(50, true)
	await bar.value_changed_complete
	# Let the emitting tween callback return before GUT frees its signal owner.
	await get_tree().process_frame
	assert_eq(bar.value, 50.0)
	assert_eq(bar._label.text, "HP: 50/100")
	assert_eq(bar.get_theme_stylebox("fill").bg_color, ThemeManager.COLOR_WARNING)
