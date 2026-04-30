extends Node
## AudioManager — Global audio bus: BGM, SFX, and ambient playback.
##
## Provides play/stop methods with graceful fallback when audio files
## are not yet present. Drop .ogg/.wav files into assets/audio/ and
## update the track registries below.

var bgm_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var ambient_player: AudioStreamPlayer

## Volume levels (0.0–1.0). Mapped to AudioServer buses.
var bgm_volume: float = 0.8
var sfx_volume: float = 1.0
var ambient_volume: float = 0.6

## Track registries — map string IDs to resource paths.
var bgm_tracks: Dictionary = {
	"chapter_0": "res://assets/audio/bgm/chapter_0.ogg",
	"chapter_1": "res://assets/audio/bgm/chapter_1.ogg",
	"chapter_2": "res://assets/audio/bgm/chapter_2.ogg",
	"chapter_3": "res://assets/audio/bgm/chapter_3.ogg",
	"chapter_4": "res://assets/audio/bgm/chapter_4.ogg",
	"chapter_5": "res://assets/audio/bgm/chapter_5.ogg",
	"chapter_6": "res://assets/audio/bgm/chapter_6.ogg",
	"chapter_7": "res://assets/audio/bgm/chapter_7.ogg",
	"chapter_8": "res://assets/audio/bgm/chapter_8.ogg",
	"chapter_9": "res://assets/audio/bgm/chapter_9.ogg",
	"chapter_10": "res://assets/audio/bgm/chapter_10.ogg",
	"combat": "res://assets/audio/bgm/combat.ogg",
	"title": "res://assets/audio/bgm/title.ogg",
}

var sfx_tracks: Dictionary = {
	"text_advance": "res://assets/audio/sfx/text_advance.ogg",
	"choice_select": "res://assets/audio/sfx/choice_select.ogg",
	"attack": "res://assets/audio/sfx/attack.ogg",
	"ability": "res://assets/audio/sfx/ability.ogg",
	"victory": "res://assets/audio/sfx/victory.ogg",
	"defeat": "res://assets/audio/sfx/defeat.ogg",
	"menu_open": "res://assets/audio/sfx/menu_open.ogg",
	"menu_close": "res://assets/audio/sfx/menu_close.ogg",
	"save": "res://assets/audio/sfx/save.ogg",
}

var ambient_tracks: Dictionary = {
	"ship_idle": "res://assets/audio/ambient/ship_idle.ogg",
}

var _current_bgm_id: String = ""
var _crossfade_tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	bgm_player = AudioStreamPlayer.new()
	bgm_player.name = "BGMPlayer"
	bgm_player.bus = "Master"
	add_child(bgm_player)

	sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "SFXPlayer"
	sfx_player.bus = "Master"
	add_child(sfx_player)

	ambient_player = AudioStreamPlayer.new()
	ambient_player.name = "AmbientPlayer"
	ambient_player.bus = "Master"
	add_child(ambient_player)

	_apply_volumes()


# --- Public API ---

func play_bgm(track_id: String) -> void:
	if track_id == _current_bgm_id and bgm_player.playing:
		return

	var path: String = bgm_tracks.get(track_id, "")
	if path.is_empty():
		push_warning("AudioManager: Unknown BGM track '%s'" % track_id)
		return

	if not FileAccess.file_exists(path):
		push_warning("AudioManager: BGM file not found '%s'" % path)
		return

	var stream := load(path) as AudioStream
	if stream == null:
		push_warning("AudioManager: Failed to load BGM '%s'" % path)
		return

	# Crossfade if already playing
	if bgm_player.playing:
		if _crossfade_tween and _crossfade_tween.is_valid():
			_crossfade_tween.kill()
		_crossfade_tween = create_tween()
		_crossfade_tween.tween_property(bgm_player, "volume_db", -40.0, 0.5)
		_crossfade_tween.tween_callback(func():
			bgm_player.stream = stream
			bgm_player.volume_db = linear_to_db(bgm_volume)
			bgm_player.play()
		)
	else:
		bgm_player.stream = stream
		bgm_player.volume_db = linear_to_db(bgm_volume)
		bgm_player.play()

	_current_bgm_id = track_id


func stop_bgm(fade_time: float = 1.0) -> void:
	if not bgm_player.playing:
		return
	_current_bgm_id = ""
	if fade_time <= 0.0:
		bgm_player.stop()
		return
	var tween := create_tween()
	tween.tween_property(bgm_player, "volume_db", -40.0, fade_time)
	tween.tween_callback(bgm_player.stop)


func play_sfx(sfx_id: String) -> void:
	var path: String = sfx_tracks.get(sfx_id, "")
	if path.is_empty():
		push_warning("AudioManager: Unknown SFX '%s'" % sfx_id)
		return

	if not FileAccess.file_exists(path):
		# Silently skip — files not yet added
		return

	var stream := load(path) as AudioStream
	if stream == null:
		return

	sfx_player.stream = stream
	sfx_player.volume_db = linear_to_db(sfx_volume)
	sfx_player.play()


func play_ambient(ambient_id: String) -> void:
	var path: String = ambient_tracks.get(ambient_id, "")
	if path.is_empty():
		push_warning("AudioManager: Unknown ambient track '%s'" % ambient_id)
		return

	if not FileAccess.file_exists(path):
		return

	var stream := load(path) as AudioStream
	if stream == null:
		return

	ambient_player.stream = stream
	ambient_player.volume_db = linear_to_db(ambient_volume)
	ambient_player.play()


func stop_ambient() -> void:
	ambient_player.stop()


func set_volume(bus: String, value: float) -> void:
	value = clampf(value, 0.0, 1.0)
	match bus:
		"bgm":
			bgm_volume = value
			if bgm_player.playing:
				bgm_player.volume_db = linear_to_db(value)
		"sfx":
			sfx_volume = value
		"ambient":
			ambient_volume = value
			if ambient_player.playing:
				ambient_player.volume_db = linear_to_db(value)
		_:
			push_warning("AudioManager: Unknown bus '%s'" % bus)


func _apply_volumes() -> void:
	bgm_player.volume_db = linear_to_db(bgm_volume)
	sfx_player.volume_db = linear_to_db(sfx_volume)
	ambient_player.volume_db = linear_to_db(ambient_volume)
