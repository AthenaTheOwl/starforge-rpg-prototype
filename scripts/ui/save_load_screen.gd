extends Control
## SaveLoadScreen — UI for saving and loading game state.
##
## Displays 3 manual save slots + 1 autosave slot with metadata.
## Supports save mode (write to slot) and load mode (read from slot).

enum Mode { SAVE, LOAD }

var current_mode: Mode = Mode.SAVE

@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var slots_container: VBoxContainer = $Panel/VBox/ScrollContainer/SlotsContainer
@onready var back_button: Button = $Panel/VBox/BackButton
@onready var confirmation_dialog: ConfirmationDialog = $ConfirmationDialog

var selected_slot: int = -1

signal action_complete()


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	confirmation_dialog.confirmed.connect(_on_confirmation_confirmed)
	_populate_slots()


## Configure screen for save or load mode.
func setup(mode: Mode) -> void:
	current_mode = mode
	if title_label:
		title_label.text = "SAVE GAME" if mode == Mode.SAVE else "LOAD GAME"
	_populate_slots()


## Populate slot panels with save information.
func _populate_slots() -> void:
	if not slots_container:
		return

	# Clear existing slots
	for child in slots_container.get_children():
		child.queue_free()

	# Create manual save slots (0-2)
	for i in range(SaveManager.MAX_MANUAL_SLOTS):
		var slot_panel := _create_slot_panel(i)
		slots_container.add_child(slot_panel)

	# Create autosave slot (-1)
	var autosave_panel := _create_slot_panel(-1)
	slots_container.add_child(autosave_panel)


func _create_slot_panel(slot: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 80)

	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 80)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT

	var save_info := SaveManager.get_save_info(slot)
	var has_save := SaveManager.has_save(slot)

	# Build button text
	var slot_name := "Autosave" if slot == -1 else "Save Slot %d" % (slot + 1)
	var button_text := "[b]%s[/b]\n" % slot_name

	if has_save:
		var timestamp: String = save_info.get("timestamp", "Unknown")
		var chapter_info := "Act %d - Chapter %d" % [
			save_info.get("current_act", 1),
			save_info.get("current_chapter", 1)
		]
		var playtime_seconds: int = save_info.get("playtime_seconds", 0)
		var hours := playtime_seconds / 3600
		var minutes := (playtime_seconds % 3600) / 60
		var playtime := "%02d:%02d" % [hours, minutes]

		button_text += "%s | %s | %s" % [chapter_info, playtime, timestamp]
	else:
		button_text += "[i]Empty Slot[/i]"

	button.text = button_text

	# Disable button in load mode if slot is empty
	if current_mode == Mode.LOAD and not has_save:
		button.disabled = true

	# Connect button press
	var slot_index := slot  # Capture for lambda
	button.pressed.connect(func(): _on_slot_clicked(slot_index))

	panel.add_child(button)
	return panel


func _on_slot_clicked(slot: int) -> void:
	selected_slot = slot

	if current_mode == Mode.SAVE:
		# Check if slot has existing save
		if SaveManager.has_save(slot):
			var slot_name := "Autosave" if slot == -1 else "Save Slot %d" % (slot + 1)
			confirmation_dialog.dialog_text = "Overwrite %s?" % slot_name
			confirmation_dialog.popup_centered()
		else:
			_perform_save(slot)
	elif current_mode == Mode.LOAD:
		_perform_load(slot)


func _on_confirmation_confirmed() -> void:
	if current_mode == Mode.SAVE and selected_slot >= -1:
		_perform_save(selected_slot)


func _perform_save(slot: int) -> void:
	var err := SaveManager.save_game(slot)
	if err == OK:
		_populate_slots()  # Refresh display
		action_complete.emit()
	else:
		push_error("Save failed: %s" % error_string(err))


func _perform_load(slot: int) -> void:
	var err := SaveManager.load_game(slot)
	if err == OK:
		action_complete.emit()
		# Transition handled by SaveManager
	else:
		push_error("Load failed: %s" % error_string(err))


func _on_back_pressed() -> void:
	action_complete.emit()
	queue_free()
