extends SceneTree
## Deterministic headless UI-signal smoke, not a visual/manual playthrough.
## Use check_release.py to isolate user:// before this script touches saves.

const TITLE := "res://scenes/menus/title_screen.tscn"
const FLOW := "res://scenes/story/chapter_flow.tscn"
const BATTLE := "res://scenes/battle/battle_scene.tscn"
var checks: Array[String] = []
var _dialogue
var _story
var _party
var _game
var _saves
var _combat


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, label: String) -> bool:
	print("SMOKE %s: %s" % ["PASS" if condition else "FAIL", label])
	if not condition:
		push_error(label)
		quit(1)
		return false
	checks.append(label)
	return true


func _wait_for(predicate: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			return true
		await process_frame
	return false


func _finish_dialogue(dialogue_id: String) -> bool:
	if not await _wait_for(func(): return _dialogue.current_dialogue_id == dialogue_id):
		return false
	for step in range(500):
		if dialogue_id in _story.played_dialogues:
			return true
		var controller: Control = current_scene.get_node("DialogueController")
		if controller._typewriter_active:
			controller._handle_click()
		elif controller.continue_btn.visible:
			controller.continue_btn.pressed.emit()
		else:
			for button in controller.choices_container.get_children():
				if button is Button and not button.is_queued_for_deletion():
					button.pressed.emit()
					break
		await process_frame
	return false


func _run() -> void:
	_dialogue = root.get_node("DialogueManager")
	_story = root.get_node("StoryManager")
	_party = root.get_node("PartyManager")
	_game = root.get_node("GameManager")
	_saves = root.get_node("SaveManager")
	_combat = root.get_node("CombatManager")
	var isolated_root := OS.get_environment("STARFORGE_TEST_STATE_ROOT").replace("\\", "/")
	if not _check(not isolated_root.is_empty() and OS.get_user_data_dir().replace("\\", "/").begins_with(isolated_root + "/"), "isolated user data"): return
	seed(1342)
	Engine.time_scale = 40.0
	for slot in [-1, 0, 1, 2]:
		_saves.delete_save(slot)
	if not _check(change_scene_to_file(TITLE) == OK, "title scene loads"): return
	await process_frame
	await process_frame
	if not _check(current_scene.get_node("VBox/LoadGameBtn").disabled, "empty profile disables Load Game"): return
	current_scene.get_node("VBox/NewGameBtn").pressed.emit()
	if not _check(await _wait_for(func(): return current_scene != null and current_scene.scene_file_path == FLOW), "New Game opens chapter flow"): return
	if not _check(_party.active_party.has("avyanna") and _party.get_character("avyanna").get("hp", 0) > 0, "new game recruits a living protagonist"): return
	if not _check(await _finish_dialogue("act1_prologue_boarding"), "prologue completes through dialogue controls"): return
	if not _check(await _wait_for(func(): return current_scene.hub_panel.visible), "prologue returns to hub"): return
	if not _check(not current_scene.hub_advance_btn.disabled, "prologue advance is enabled"): return
	current_scene.hub_advance_btn.pressed.emit()
	if not _check(await _finish_dialogue("act1_elia_rescue"), "chapter one dialogue completes through controls"): return
	if not _check(await _wait_for(func(): return current_scene.hub_panel.visible), "chapter one returns to hub"): return
	if not _check(not current_scene.hub_advance_btn.disabled, "chapter one advance is enabled"): return
	current_scene.hub_advance_btn.pressed.emit()
	if not _check(await _wait_for(func(): return current_scene != null and current_scene.scene_file_path == BATTLE), "chapter advance opens tutorial battle"): return
	var battle: Control = current_scene
	if not _check(battle.get_script() != null and battle.has_method("_on_escape"), "battle controller compiles"): return
	if not _check(await _wait_for(func(): return battle.escape_btn.visible), "combat reaches player turn"): return
	var hp_before := 0
	for enemy in _combat.enemies: hp_before += int(enemy.get("hp", 0))
	var selected := false
	for button in battle.ability_buttons.get_children():
		if button is Button and button.text.begins_with("Tear-Sense"):
			button.pressed.emit()
			selected = true
			break
	if not _check(selected, "damaging ability is selectable in battle UI"): return
	await process_frame
	var target: Button = battle.enemy_list.get_child(0)
	target.pressed.emit()
	await process_frame
	var hp_after := 0
	for enemy in _combat.enemies: hp_after += int(enemy.get("hp", 0))
	if not _check(hp_after < hp_before, "target control applies real combat damage"): return
	if not _check(await _wait_for(func(): return battle.escape_btn.visible), "enemy turns return control to player"): return
	battle.escape_btn.pressed.emit()
	if not _check(await _wait_for(func(): return current_scene != null and current_scene.scene_file_path == FLOW), "escape returns to story flow"): return
	if not _check(not _game.is_encounter_cleared("act1_tutorial"), "escape does not falsely mark victory"): return
	var hub_chapter: int = _game.current_chapter
	var hub_hp: int = _party.get_character("avyanna")["hp"]
	_game.set_flag("hub_save_marker", true)
	current_scene.hub_save_btn.pressed.emit()
	var hub_save: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://saves/save_0.json"))
	if not _check(hub_save.has("game_state"), "chapter Save writes the same schema used by Load"): return
	_game.story_flags.erase("hub_save_marker")
	_game.current_chapter = 99
	_party.modify_stat("avyanna", "hp", -3)
	var hub_load: Control = load("res://scenes/menus/save_load_screen.tscn").instantiate()
	var previous_flow_id: int = current_scene.get_instance_id()
	root.add_child(hub_load)
	hub_load.setup(1)
	await process_frame
	hub_load.slots_container.get_child(0).get_child(0).pressed.emit()
	if not _check(await _wait_for(func(): return _game.get_flag("hub_save_marker", false) and _game.current_chapter == hub_chapter and _party.get_character("avyanna")["hp"] == hub_hp), "slot Load restores chapter Save flags, chapter and HP"): return
	if not await _wait_for(func(): return current_scene != null and current_scene.get_instance_id() != previous_flow_id and current_scene.scene_file_path == FLOW and current_scene.hub_panel.visible):
		_check(false, "chapter Save load returns to hub")
		return
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	var pause_menu: CanvasLayer = root.get_node("PauseMenu")
	if not _check(await _wait_for(func(): return paused and pause_menu.visible), "Escape opens pause from an unpaused story hub"): return
	pause_menu.resume_btn.pressed.emit()
	if not _check(not paused and not pause_menu.visible, "Resume closes pause and unpauses gameplay"): return
	_party.recruit_character("elia")
	if not _check(_party.active_party.has("elia"), "party recruitment changes active roster"): return
	_game.set_flag("runtime_smoke_marker", true)
	var saved_hp: int = _party.get_character("avyanna")["hp"]
	var menu: Control = load("res://scenes/menus/save_load_screen.tscn").instantiate()
	root.add_child(menu)
	menu.setup(0)
	await process_frame
	menu.slots_container.get_child(0).get_child(0).pressed.emit()
	if menu.confirmation_dialog.visible:
		menu.confirmation_dialog.confirmed.emit()
	var slot_record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://saves/save_0.json"))
	if not _check(slot_record.get("game_state", {}).get("flags", {}).get("runtime_smoke_marker", false), "save slot and overwrite controls write the new state"): return
	_game.story_flags.erase("runtime_smoke_marker")
	_party.modify_stat("avyanna", "hp", -7)
	menu.setup(1)
	await process_frame
	menu.slots_container.get_child(0).get_child(0).pressed.emit()
	await process_frame
	if not _check(_game.has_flag("runtime_smoke_marker") and _party.get_character("avyanna")["hp"] == saved_hp, "load slot restores flags and party HP"): return
	if not _check("act1_prologue_boarding" in _story.played_dialogues and "act1_elia_rescue" in _story.played_dialogues, "save/load preserves completed dialogue progress"): return
	load("res://scripts/ui/scene_transition.gd").transition_to_packed(load(TITLE))
	if not _check(await _wait_for(func(): return current_scene != null and current_scene.scene_file_path == TITLE), "packed-scene transition completes"): return
	print("SMOKE SUMMARY: %d checks passed; no visual, dormant-route reachability or full-campaign claim" % checks.size())
	Engine.time_scale = 1.0
	quit(0)
