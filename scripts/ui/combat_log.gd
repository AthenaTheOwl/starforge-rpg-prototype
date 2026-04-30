class_name CombatLog
extends VBoxContainer
## CombatLog — Scrollable BBCode combat log with timestamps and round markers.
##
## Contains a ScrollContainer with a RichTextLabel. Auto-scrolls to bottom.

var _scroll: ScrollContainer
var _rich_label: RichTextLabel


func _ready() -> void:
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_scroll)

	_rich_label = RichTextLabel.new()
	_rich_label.bbcode_enabled = true
	_rich_label.fit_content = true
	_rich_label.scroll_active = false
	_rich_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rich_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_rich_label)

	CombatManager.combat_started.connect(_on_combat_started)


func _on_combat_started() -> void:
	clear()


## Append a BBCode line with a timestamp prefix.
func add_entry(text: String) -> void:
	var time_str := _get_timestamp()
	_rich_label.append_text("[color=gray][%s][/color] %s\n" % [time_str, text])
	_scroll_to_bottom()


## Add a round separator line.
func add_round_marker(round_num: int) -> void:
	_rich_label.append_text(
		"\n[color=yellow]──── Round %d ────[/color]\n" % round_num
	)
	_scroll_to_bottom()


## Clear all log content.
func clear() -> void:
	if _rich_label:
		_rich_label.clear()


func _get_timestamp() -> String:
	var ticks := Time.get_ticks_msec()
	var secs := (ticks / 1000) % 60
	var mins := (ticks / 60000) % 60
	return "%02d:%02d" % [mins, secs]


func _scroll_to_bottom() -> void:
	## Defer to ensure layout is updated before scrolling.
	await get_tree().process_frame
	if _scroll:
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)
