extends SceneTree
## Check the actual Godot user:// destination before any save-deleting test runs.

func _initialize() -> void:
	var expected := OS.get_environment("STARFORGE_TEST_STATE_ROOT").replace("\\", "/").simplify_path().trim_suffix("/")
	var actual := OS.get_user_data_dir().replace("\\", "/").simplify_path()
	if OS.get_name() == "Windows":
		expected = expected.to_lower()
		actual = actual.to_lower()
	if expected.is_empty() or not expected.is_absolute_path() or not actual.begins_with(expected + "/"):
		printerr("NATIVE STATE PREFLIGHT FAILED: actual user:// is outside STARFORGE_TEST_STATE_ROOT; refusing save tests")
		quit(1)
		return
	print("NATIVE STATE PREFLIGHT PASS: actual user:// is contained in the test state root")
	quit(0)
