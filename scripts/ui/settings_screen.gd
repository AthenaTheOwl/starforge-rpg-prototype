extends Control
## Settings screen controller. Persists user preferences to user://settings.json.

signal closed

const SETTINGS_PATH := "user://settings.json"

## Default values used on first launch or when the file is missing.
const DEFAULTS := {
	"text_speed": 40.0,
	"master_volume": 80.0,
	"sfx_volume": 80.0,
	"music_volume": 80.0,
	"fullscreen": false,
}

## Shared settings dictionary — other scripts can read SettingsScreen.current.
static var current: Dictionary = DEFAULTS.duplicate()

@onready var text_speed_slider: HSlider = %TextSpeedSlider
@onready var master_volume_slider: HSlider = %MasterVolumeSlider
@onready var sfx_volume_slider: HSlider = %SFXVolumeSlider
@onready var music_volume_slider: HSlider = %MusicVolumeSlider
@onready var fullscreen_toggle: CheckButton = %FullscreenToggle
@onready var back_button: Button = %BackButton


func _ready() -> void:
	_load_settings()
	_apply_ui()
	_apply_settings()

	text_speed_slider.value_changed.connect(_on_text_speed_changed)
	master_volume_slider.value_changed.connect(_on_master_volume_changed)
	sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	music_volume_slider.value_changed.connect(_on_music_volume_changed)
	fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	back_button.pressed.connect(_on_back)


## Populate UI controls from the current settings dictionary.
func _apply_ui() -> void:
	text_speed_slider.value = current["text_speed"]
	master_volume_slider.value = current["master_volume"]
	sfx_volume_slider.value = current["sfx_volume"]
	music_volume_slider.value = current["music_volume"]
	fullscreen_toggle.button_pressed = current["fullscreen"]


## Apply runtime effects (fullscreen, audio buses, dialogue speed).
func _apply_settings() -> void:
	# Fullscreen
	if current["fullscreen"]:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	# Audio buses — apply when buses exist, silently skip otherwise
	_set_bus_volume("Master", current["master_volume"])
	_set_bus_volume("SFX", current["sfx_volume"])
	_set_bus_volume("Music", current["music_volume"])

	# Text speed — update DialogueManager if it exposes text_speed
	if Engine.has_singleton("DialogueManager"):
		var dm := Engine.get_singleton("DialogueManager")
		if dm.has_method("set") and "text_speed" in dm:
			dm.set("text_speed", current["text_speed"])


## Convert a 0-100 volume percent to linear and apply to an audio bus.
func _set_bus_volume(bus_name: String, percent: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	var db := linear_to_db(percent / 100.0)
	AudioServer.set_bus_volume_db(idx, db)
	AudioServer.set_bus_mute(idx, percent <= 0.0)


# -- Signal handlers ----------------------------------------------------------

func _on_text_speed_changed(value: float) -> void:
	current["text_speed"] = value
	_apply_settings()
	_save_settings()


func _on_master_volume_changed(value: float) -> void:
	current["master_volume"] = value
	_apply_settings()
	_save_settings()


func _on_sfx_volume_changed(value: float) -> void:
	current["sfx_volume"] = value
	_apply_settings()
	_save_settings()


func _on_music_volume_changed(value: float) -> void:
	current["music_volume"] = value
	_apply_settings()
	_save_settings()


func _on_fullscreen_toggled(enabled: bool) -> void:
	current["fullscreen"] = enabled
	_apply_settings()
	_save_settings()


func _on_back() -> void:
	closed.emit()
	queue_free()


# -- Persistence ---------------------------------------------------------------

func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		current = DEFAULTS.duplicate()
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		current = DEFAULTS.duplicate()
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		current = DEFAULTS.duplicate()
		return
	var data: Dictionary = json.data
	# Merge with defaults so new keys are always present
	for key in DEFAULTS:
		if key in data:
			current[key] = data[key]
		else:
			current[key] = DEFAULTS[key]


func _save_settings() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(current, "\t"))
	file.close()
