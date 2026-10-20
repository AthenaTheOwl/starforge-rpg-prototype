extends RefCounted
## GUT scripts that let the game write user://saves (the save tests, and tests
## whose combat victory or story flags trigger an autosave) call this from
## should_skip_script(). They run only after tools/check_release.py has pointed
## user:// inside its isolated state root, so a direct editor or CLI GUT run
## cannot overwrite or delete a player's real saves.


static func skip_reason() -> Variant:
	var root := OS.get_environment("STARFORGE_TEST_STATE_ROOT").replace("\\", "/").simplify_path().trim_suffix("/")
	var actual := OS.get_user_data_dir().replace("\\", "/").simplify_path()
	if OS.get_name() == "Windows":
		root = root.to_lower()
		actual = actual.to_lower()
	if root.is_empty() or not root.is_absolute_path() or not actual.begins_with(root + "/"):
		return "user:// is outside STARFORGE_TEST_STATE_ROOT; run GUT through tools/check_release.py"
	return false
