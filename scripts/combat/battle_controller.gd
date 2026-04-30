extends Control
## BattleController — Drives the battle scene UI.
##
## Connects CombatManager signals to UI updates. Handles player input for
## ability selection and targeting. Wires damage numbers, status icons,
## turn order display, and victory/defeat panels.

## Debug: set to a path like "res://data/encounters/act1_mine_breach.json"
## to auto-load an encounter in _ready().
@export var debug_encounter_path: String = ""

@onready var round_label: Label = $TopBar/RoundLabel
@onready var cli_label: Label = $TopBar/CLILabel
@onready var turn_label: Label = $TopBar/TurnLabel
@onready var turn_order_display: TurnOrderDisplay = $TopBar/TurnOrderDisplay
@onready var combat_log_widget: CombatLog = $HSplit/LeftPanel/CombatLogContainer
@onready var combat_log: RichTextLabel = $HSplit/LeftPanel/CombatLogScroll/CombatLog
@onready var verb_buttons: HBoxContainer = $HSplit/LeftPanel/VerbButtons
@onready var ability_buttons: VBoxContainer = $HSplit/LeftPanel/AbilityButtons
@onready var escape_btn: Button = $HSplit/LeftPanel/EscapeBtn
@onready var enemy_list: VBoxContainer = $HSplit/RightPanel/EnemyList
@onready var party_list: VBoxContainer = $HSplit/RightPanel/PartyList
@onready var ability_bar: HBoxContainer = $AbilityBar
@onready var target_overlay: ColorRect = $TargetOverlay
@onready var victory_panel: PanelContainer = $VictoryPanel
@onready var defeat_panel: PanelContainer = $DefeatPanel
@onready var damage_layer: Control = $DamageLayer

var selected_ability: Dictionary = {}
var targeting_mode: bool = false
var current_player_character: Dictionary = {}

## Track combatant panel positions for damage number spawning.
var _combatant_positions: Dictionary = {}  # { id: Vector2 }
## Track status icon containers per combatant id.
var _status_containers: Dictionary = {}  # { id: HBoxContainer }


func _ready() -> void:
	CombatManager.combat_started.connect(_on_combat_started)
	CombatManager.turn_started.connect(_on_turn_started)
	CombatManager.damage_dealt.connect(_on_damage_dealt)
	CombatManager.status_applied.connect(_on_status_applied)
	CombatManager.cli_changed.connect(_on_cli_changed)
	CombatManager.combat_ended.connect(_on_combat_ended)
	escape_btn.pressed.connect(_on_escape)

	# Hide end-game panels
	if victory_panel:
		victory_panel.visible = false
	if defeat_panel:
		defeat_panel.visible = false
	if target_overlay:
		target_overlay.visible = false

	# Debug encounter loading
	if not debug_encounter_path.is_empty():
		_load_debug_encounter(debug_encounter_path)

	CombatManager.start_combat()


## Load encounter JSON and set up CombatManager enemies before combat starts.
func _load_debug_encounter(path: String) -> void:
	if not FileAccess.file_exists(path):
		push_warning("BattleController: debug encounter not found: %s" % path)
		return

	var file := FileAccess.open(path, FileAccess.READ)
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()

	if err != OK:
		push_warning("BattleController: failed to parse encounter JSON: %s" % path)
		return

	var data: Dictionary = json.data
	var waves: Array = data.get("waves", [])
	if waves.is_empty():
		return

	# Load first wave for now.
	var wave: Dictionary = waves[0]
	var enemy_group: Array[Dictionary] = []
	var enemy_index: int = 0

	for entry in wave.get("enemies", []):
		var enemy_type: String = entry.get("type", "")
		var count: int = entry.get("count", 1)

		# Map encounter type to enemy data file.
		var enemy_file_path := "res://data/enemies/%s.json" % enemy_type
		if not FileAccess.file_exists(enemy_file_path):
			# Try without prefix mapping.
			push_warning("BattleController: enemy data not found: %s" % enemy_file_path)
			continue

		var efile := FileAccess.open(enemy_file_path, FileAccess.READ)
		var ejson := JSON.new()
		var eerr := ejson.parse(efile.get_as_text())
		efile.close()

		if eerr != OK:
			continue

		var template: Dictionary = ejson.data
		for n in count:
			var enemy := template.duplicate(true)
			enemy["id"] = "enemy_%d" % enemy_index
			if count > 1:
				enemy["name"] = "%s %c" % [enemy.get("name", "Enemy"), 65 + n]  # A, B, C...
			enemy_index += 1
			enemy_group.append(enemy)

	if not enemy_group.is_empty():
		CombatManager.setup_encounter(enemy_group)
		_log("[color=yellow]Encounter loaded: %s[/color]" % data.get("name", "Unknown"))


func _on_combat_started() -> void:
	_log("[color=yellow]--- Combat begins ---[/color]")
	if combat_log_widget:
		combat_log_widget.clear()
		combat_log_widget.add_entry("[color=yellow]--- Combat begins ---[/color]")
	_refresh_all_displays()


func _on_turn_started(combatant: Dictionary) -> void:
	round_label.text = "Round %d" % CombatManager.round_number
	var cname: String = combatant["ref"].get("name", combatant["id"])

	# Update turn order display
	if turn_order_display:
		turn_order_display.refresh(CombatManager.turn_order, CombatManager.current_turn_index)

	# Add round marker on first turn of new round
	if CombatManager.current_turn_index == 0 and combat_log_widget:
		combat_log_widget.add_round_marker(CombatManager.round_number)

	if combatant["is_player"]:
		turn_label.text = "%s's Turn" % cname
		current_player_character = combatant["ref"]
		_show_abilities(combatant["ref"])
		_show_ability_bar(combatant["ref"])
		escape_btn.visible = true
		_set_player_input_enabled(true)
		_log("\n[color=cyan]%s's turn.[/color]" % cname)
		if combat_log_widget:
			combat_log_widget.add_entry("[color=cyan]%s's turn.[/color]" % cname)
	else:
		turn_label.text = "%s attacks!" % cname
		_clear_ability_buttons()
		_clear_ability_bar()
		escape_btn.visible = false
		_set_player_input_enabled(false)
		_log("\n[color=red]%s acts.[/color]" % cname)
		if combat_log_widget:
			combat_log_widget.add_entry("[color=red]%s acts.[/color]" % cname)
		# Small delay then enemy acts
		await get_tree().create_timer(0.5).timeout
		CombatManager.execute_enemy_turn(combatant["ref"])
		_refresh_all_displays()


func _show_abilities(character: Dictionary) -> void:
	_clear_ability_buttons()
	targeting_mode = false
	selected_ability = {}

	var abilities: Array = character.get("ability_slots", character.get("abilities", []))
	for ability in abilities:
		var charges: int = ability.get("charges", 1)
		if charges <= 0:
			continue
		var btn := Button.new()
		var heat_cost: int = ability.get("heat_cost", 0)
		btn.text = "%s (Heat: %d, Charges: %d)" % [ability.get("name", "???"), heat_cost, charges]
		btn.tooltip_text = ability.get("description", "")
		var ab := ability  # capture
		btn.pressed.connect(func(): _on_ability_selected(ab))
		ability_buttons.add_child(btn)


## Populate the bottom AbilityBar with ability buttons.
func _show_ability_bar(character: Dictionary) -> void:
	_clear_ability_bar()
	if not ability_bar:
		return

	var abilities: Array = character.get("ability_slots", character.get("abilities", []))
	for ability in abilities:
		var charges: int = ability.get("charges", 1)
		if charges <= 0:
			continue
		var btn := Button.new()
		var heat_cost: int = ability.get("heat_cost", 0)
		btn.text = ability.get("name", "???")
		btn.tooltip_text = "%s\nHeat: %d | Charges: %d\n%s" % [
			ability.get("name", "???"),
			heat_cost,
			charges,
			ability.get("description", ""),
		]
		btn.custom_minimum_size = Vector2(100, 40)
		var ab := ability
		btn.pressed.connect(func(): _on_ability_selected(ab))
		ability_bar.add_child(btn)


func _on_ability_selected(ability: Dictionary) -> void:
	selected_ability = ability
	targeting_mode = true
	_log("  Selected: [b]%s[/b] --- Choose a target." % ability.get("name", "???"))
	if combat_log_widget:
		combat_log_widget.add_entry("Selected: [b]%s[/b] --- Choose a target." % ability.get("name", "???"))
	_show_target_selection(ability)


## Show valid targets based on ability target_type.
func _show_target_selection(ability: Dictionary) -> void:
	if target_overlay:
		target_overlay.visible = true

	var target_type: String = ability.get("target_type", "enemy")

	match target_type:
		"self":
			# Auto-target self.
			_on_target_selected(current_player_character.get("id", ""))
			return
		"ally":
			_refresh_ally_targeting()
		"all_enemies":
			# Auto-target all enemies.
			var target_ids: Array[String] = []
			for e in CombatManager.enemies:
				if e.get("hp", 0) > 0:
					target_ids.append(e.get("id", ""))
			_on_targets_selected(target_ids)
			return
		_:
			# Default: single enemy target.
			_refresh_enemy_display_with_targeting()


func _refresh_enemy_display_with_targeting() -> void:
	for child in enemy_list.get_children():
		child.queue_free()

	for i in CombatManager.enemies.size():
		var enemy: Dictionary = CombatManager.enemies[i]
		if enemy.get("hp", 0) <= 0:
			continue
		var btn := Button.new()
		btn.text = "%s --- HP: %d/%d" % [enemy.get("name", "Enemy"), enemy.get("hp", 0), enemy.get("hp_max", 50)]
		var enemy_id: String = enemy.get("id", "enemy_%d" % i)
		btn.pressed.connect(func(): _on_target_selected(enemy_id))
		enemy_list.add_child(btn)


## Show ally targets for support/heal abilities.
func _refresh_ally_targeting() -> void:
	for child in enemy_list.get_children():
		child.queue_free()

	for c in PartyManager.get_active_characters():
		if c.get("hp", 0) <= 0:
			continue
		var btn := Button.new()
		btn.text = "%s --- HP: %d/%d" % [c.get("name", "???"), c.get("hp", 0), c.get("hp_max", 100)]
		var cid: String = c.get("id", "")
		btn.pressed.connect(func(): _on_target_selected(cid))
		enemy_list.add_child(btn)


func _on_target_selected(target_id: String) -> void:
	if not targeting_mode or selected_ability.is_empty():
		return
	targeting_mode = false

	if target_overlay:
		target_overlay.visible = false

	# Consume a charge
	selected_ability["charges"] = selected_ability.get("charges", 1) - 1

	CombatManager.execute_ability(
		current_player_character.get("id", ""),
		selected_ability,
		[target_id]
	)
	_refresh_all_displays()


## Execute ability against multiple targets (e.g. AoE).
func _on_targets_selected(target_ids: Array[String]) -> void:
	targeting_mode = false

	if target_overlay:
		target_overlay.visible = false

	selected_ability["charges"] = selected_ability.get("charges", 1) - 1

	CombatManager.execute_ability(
		current_player_character.get("id", ""),
		selected_ability,
		target_ids
	)
	_refresh_all_displays()


func _on_escape() -> void:
	CombatManager.attempt_escape()


func _on_damage_dealt(source: Dictionary, target: Dictionary, amount: int, type: String) -> void:
	var src_name: String = source.get("name", "???")
	var tgt_name: String = target.get("name", "???")
	var log_text := "[%s] dealt %d %s damage to %s" % [src_name, amount, type, tgt_name]
	_log("  %s deals [b]%d %s[/b] damage to %s." % [src_name, amount, type, tgt_name])
	if combat_log_widget:
		combat_log_widget.add_entry(log_text)

	AudioManager.play_sfx("attack")

	# Spawn floating damage number
	_spawn_damage_number(target, amount, type, false)

	if target.get("hp", 0) <= 0:
		_log("  [color=red]%s is defeated![/color]" % tgt_name)
		if combat_log_widget:
			combat_log_widget.add_entry("[color=red]%s is defeated![/color]" % tgt_name)
	_refresh_all_displays()


## Spawn a DamageNumber at the target's panel position.
func _spawn_damage_number(target: Dictionary, amount: int, damage_type: String, is_crit: bool) -> void:
	var target_id: String = target.get("id", "")
	var pos: Vector2 = _combatant_positions.get(target_id, Vector2(size.x / 2.0, size.y / 2.0))
	# Add slight randomness to prevent overlap.
	pos += Vector2(randf_range(-20.0, 20.0), randf_range(-10.0, 10.0))

	var dn := DamageNumber.spawn(amount, damage_type, pos, is_crit)
	if damage_layer:
		damage_layer.add_child(dn)
	else:
		add_child(dn)


func _on_status_applied(target: Dictionary, status_name: String) -> void:
	var tgt_name: String = target.get("name", "???")
	_log("  %s is now [b]%s[/b]." % [tgt_name, status_name])
	if combat_log_widget:
		combat_log_widget.add_entry("%s is now [b]%s[/b]." % [tgt_name, status_name])

	# Add StatusIcon to the target's status container.
	_add_status_icon(target, status_name)


## Create and add a StatusIcon to the combatant's status container.
func _add_status_icon(target: Dictionary, status_name: String) -> void:
	var target_id: String = target.get("id", "")
	var container: HBoxContainer = _status_containers.get(target_id)
	if not container:
		return

	var icon := StatusIcon.new()
	# Try to create a proper StatusEffect for richer data.
	var effect := StatusEffect.create(status_name)
	if effect and not effect.id.is_empty():
		icon.setup(effect)
	else:
		icon.setup({"name": status_name, "display_name": status_name, "category": "special"})
	container.add_child(icon)


func _on_cli_changed(new_value: float) -> void:
	cli_label.text = "CLI: %.1f / %.1f" % [new_value, CombatManager.CLI_MAX]
	if new_value >= 8.0:
		_log("[color=red]CLI CRITICAL --- Lattice cascade risk![/color]")
		if combat_log_widget:
			combat_log_widget.add_entry("[color=red]CLI CRITICAL --- Lattice cascade risk![/color]")
	elif new_value >= 6.0:
		_log("[color=yellow]CLI stressed --- visible distortions.[/color]")
		if combat_log_widget:
			combat_log_widget.add_entry("[color=yellow]CLI stressed --- visible distortions.[/color]")


func _on_combat_ended(result: CombatManager.CombatPhase) -> void:
	_clear_ability_buttons()
	_clear_ability_bar()
	escape_btn.visible = false
	_set_player_input_enabled(false)

	match result:
		CombatManager.CombatPhase.VICTORY:
			AudioManager.play_sfx("victory")
			_log("\n[color=green]--- Victory! ---[/color]")
			if combat_log_widget:
				combat_log_widget.add_entry("[color=green]--- Victory! ---[/color]")
			if victory_panel:
				victory_panel.visible = true
			# Mark encounter cleared if triggered from story
			var pending_enc: String = GameManager.get_flag("_pending_encounter", "")
			if not pending_enc.is_empty():
				GameManager.mark_encounter_cleared(pending_enc)
				GameManager.story_flags.erase("_pending_encounter")
			await get_tree().create_timer(2.0).timeout
			GameManager.transition_to_scene("res://scenes/story/chapter_flow.tscn")
		CombatManager.CombatPhase.DEFEAT:
			AudioManager.play_sfx("defeat")
			_log("\n[color=red]--- Defeated. ---[/color]")
			if combat_log_widget:
				combat_log_widget.add_entry("[color=red]--- Defeated. ---[/color]")
			if defeat_panel:
				defeat_panel.visible = true
			await get_tree().create_timer(2.0).timeout
			GameManager.transition_to_scene("res://scenes/menus/title_screen.tscn")
		CombatManager.CombatPhase.ESCAPED:
			_log("\n[color=yellow]--- Escaped. The crew withdraws. ---[/color]")
			if combat_log_widget:
				combat_log_widget.add_entry("[color=yellow]--- Escaped. The crew withdraws. ---[/color]")
			GameManager.story_flags.erase("_pending_encounter")
			await get_tree().create_timer(1.5).timeout
			GameManager.transition_to_scene("res://scenes/story/chapter_flow.tscn")


func _set_player_input_enabled(enabled: bool) -> void:
	ability_buttons.visible = enabled
	if ability_bar:
		ability_bar.visible = enabled
	escape_btn.visible = enabled


func _refresh_all_displays() -> void:
	_refresh_enemy_display()
	_refresh_party_display()


func _refresh_enemy_display() -> void:
	if targeting_mode:
		return  # Don't overwrite targeting buttons
	for child in enemy_list.get_children():
		child.queue_free()
	# Clear enemy positions (will be re-tracked below).
	for key in _combatant_positions.keys():
		if str(key).begins_with("enemy_"):
			_combatant_positions.erase(key)

	for i in CombatManager.enemies.size():
		var enemy: Dictionary = CombatManager.enemies[i]
		var enemy_id: String = enemy.get("id", "enemy_%d" % i)
		var panel := VBoxContainer.new()
		var label := Label.new()

		if enemy.get("hp", 0) <= 0:
			label.text = "%s --- [DEFEATED]" % enemy.get("name", "Enemy")
			label.modulate = Color(0.5, 0.5, 0.5, 0.5)
		else:
			label.text = "%s --- HP: %d/%d  Heat: %d" % [
				enemy.get("name", "Enemy"),
				enemy.get("hp", 0),
				enemy.get("hp_max", 50),
				enemy.get("heat", 0),
			]

		panel.add_child(label)

		# Status icons container
		var status_hbox := HBoxContainer.new()
		_status_containers[enemy_id] = status_hbox
		_rebuild_status_icons(enemy, status_hbox)
		panel.add_child(status_hbox)

		enemy_list.add_child(panel)

		# Track position for damage numbers (deferred for layout).
		_track_position_deferred(enemy_id, panel)


func _refresh_party_display() -> void:
	for child in party_list.get_children():
		child.queue_free()
	for c in PartyManager.get_active_characters():
		var cid: String = c.get("id", "")
		var panel := VBoxContainer.new()
		var label := Label.new()
		var hp: int = c.get("hp", 0)
		var hp_max: int = c.get("hp_max", 100)
		var heat: int = c.get("heat", 0)
		label.text = "%s --- HP: %d/%d  Heat: %d/5" % [c.get("name", "???"), hp, hp_max, heat]

		if hp <= 0:
			label.modulate = Color(0.5, 0.5, 0.5, 0.5)

		panel.add_child(label)

		# Status icons container
		var status_hbox := HBoxContainer.new()
		_status_containers[cid] = status_hbox
		_rebuild_status_icons(c, status_hbox)
		panel.add_child(status_hbox)

		party_list.add_child(panel)

		_track_position_deferred(cid, panel)


## Rebuild all status icons for a combatant.
func _rebuild_status_icons(combatant: Dictionary, container: HBoxContainer) -> void:
	for child in container.get_children():
		child.queue_free()

	var statuses: Array = combatant.get("statuses", [])
	for s in statuses:
		var icon := StatusIcon.new()
		icon.setup(s)
		container.add_child(icon)


## Track panel position for damage number spawning after layout settles.
func _track_position_deferred(combatant_id: String, panel: Control) -> void:
	await get_tree().process_frame
	if is_instance_valid(panel):
		_combatant_positions[combatant_id] = panel.global_position + panel.size * 0.5


func _clear_ability_buttons() -> void:
	for child in ability_buttons.get_children():
		child.queue_free()


func _clear_ability_bar() -> void:
	if not ability_bar:
		return
	for child in ability_bar.get_children():
		child.queue_free()


func _log(text: String) -> void:
	combat_log.append_text(text + "\n")
