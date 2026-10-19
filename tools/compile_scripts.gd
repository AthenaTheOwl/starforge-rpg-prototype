extends SceneTree
## Compile every project script, including unused public scene dependencies.
## GUT separately compiles and inventories its vendored runner and tests.

func _initialize() -> void:
	var paths: Array[String] = []
	for directory in ["res://autoload", "res://scripts", "res://examples", "res://tools"]:
		_collect_scripts(directory, paths)
	paths.sort()
	var failed := false
	for path in paths:
		var script := load(path) as Script
		if script == null or not script.can_instantiate():
			printerr("PROJECT SCRIPT COMPILE FAILED: %s" % path)
			failed = true
	if paths.is_empty(): failed = true
	print("PROJECT SCRIPT COMPILE: %d scripts; %s" % [paths.size(), "FAIL" if failed else "PASS"])
	quit(1 if failed else 0)


func _collect_scripts(directory: String, paths: Array[String]) -> void:
	var access := DirAccess.open(directory)
	if access == null: return
	access.list_dir_begin()
	var name := access.get_next()
	while not name.is_empty():
		var path := directory.path_join(name)
		if not name.begins_with("."):
			if access.current_is_dir(): _collect_scripts(path, paths)
			elif name.ends_with(".gd"): paths.append(path)
		name = access.get_next()
	access.list_dir_end()
