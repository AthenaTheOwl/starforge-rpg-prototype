class_name ThemeManager
extends Node
## ThemeManager — Static utility for creating the game's UI theme.
##
## Provides a consistent dark sci-fi aesthetic across all UI elements.
## Use ThemeManager.create_game_theme() to generate a Theme resource at runtime.

## Theme color palette
const COLOR_BACKGROUND := Color(0.04, 0.04, 0.08, 1.0)  # #0a0a14
const COLOR_PANEL := Color(0.08, 0.08, 0.16, 1.0)       # #141428
const COLOR_TEXT := Color(0.75, 0.75, 0.81, 1.0)        # #c0c0d0
const COLOR_ACCENT := Color(0.25, 0.38, 0.63, 1.0)      # #4060a0
const COLOR_DANGER := Color(0.63, 0.25, 0.25, 1.0)      # #a04040
const COLOR_SUCCESS := Color(0.25, 0.63, 0.38, 1.0)     # #40a060
const COLOR_WARNING := Color(0.63, 0.63, 0.25, 1.0)     # #a0a040

const CORNER_RADIUS := 4
const BORDER_WIDTH := 1


## Creates and returns the main game theme with all control styles configured.
static func create_game_theme() -> Theme:
	var theme := Theme.new()

	_setup_button_theme(theme)
	_setup_label_theme(theme)
	_setup_panel_container_theme(theme)
	_setup_rich_text_label_theme(theme)
	_setup_progress_bar_theme(theme)
	_setup_line_edit_theme(theme)
	_setup_tab_container_theme(theme)
	_setup_scroll_container_theme(theme)
	_setup_separator_theme(theme)

	return theme


## Configure Button styles with normal, hover, pressed, and disabled states.
static func _setup_button_theme(theme: Theme) -> void:
	# Normal state
	var normal := _create_stylebox(COLOR_PANEL, COLOR_TEXT * 0.5, 2)
	theme.set_stylebox("normal", "Button", normal)

	# Hover state - accent glow
	var hover := _create_stylebox(COLOR_PANEL * 1.2, COLOR_ACCENT, 2)
	theme.set_stylebox("hover", "Button", hover)

	# Pressed state - darker
	var pressed := _create_stylebox(COLOR_PANEL * 0.7, COLOR_ACCENT, 2)
	theme.set_stylebox("pressed", "Button", pressed)

	# Disabled state - grayed out
	var disabled := _create_stylebox(COLOR_PANEL * 0.5, COLOR_TEXT * 0.3, 2)
	theme.set_stylebox("disabled", "Button", disabled)

	# Focus state
	var focus := _create_stylebox(COLOR_PANEL, COLOR_ACCENT * 1.5, 2)
	theme.set_stylebox("focus", "Button", focus)

	# Text colors
	theme.set_color("font_color", "Button", COLOR_TEXT)
	theme.set_color("font_hover_color", "Button", COLOR_TEXT * 1.1)
	theme.set_color("font_pressed_color", "Button", COLOR_TEXT * 0.9)
	theme.set_color("font_disabled_color", "Button", COLOR_TEXT * 0.5)

	# Padding
	theme.set_constant("h_separation", "Button", 8)


## Configure Label with default text color.
static func _setup_label_theme(theme: Theme) -> void:
	theme.set_color("font_color", "Label", COLOR_TEXT)
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.5))
	theme.set_constant("shadow_offset_x", "Label", 1)
	theme.set_constant("shadow_offset_y", "Label", 1)


## Configure PanelContainer with dark background.
static func _setup_panel_container_theme(theme: Theme) -> void:
	var panel_style := _create_stylebox(COLOR_PANEL, COLOR_TEXT * 0.3, 1)
	panel_style.content_margin_left = 12
	panel_style.content_margin_right = 12
	panel_style.content_margin_top = 12
	panel_style.content_margin_bottom = 12
	theme.set_stylebox("panel", "PanelContainer", panel_style)


## Configure RichTextLabel with default text color.
static func _setup_rich_text_label_theme(theme: Theme) -> void:
	theme.set_color("default_color", "RichTextLabel", COLOR_TEXT)
	theme.set_color("font_shadow_color", "RichTextLabel", Color(0, 0, 0, 0.5))


## Configure ProgressBar with gradient colors based on percentage.
static func _setup_progress_bar_theme(theme: Theme) -> void:
	# Background
	var bg := _create_stylebox(COLOR_PANEL * 0.5, COLOR_TEXT * 0.2, 1)
	theme.set_stylebox("background", "ProgressBar", bg)

	# Foreground - will be overridden by HPBar for dynamic colors
	var fg := _create_stylebox(COLOR_SUCCESS, Color.TRANSPARENT, 0)
	theme.set_stylebox("fill", "ProgressBar", fg)

	theme.set_color("font_color", "ProgressBar", COLOR_TEXT)


## Configure LineEdit with dark background and light text.
static func _setup_line_edit_theme(theme: Theme) -> void:
	# Normal state
	var normal := _create_stylebox(COLOR_BACKGROUND, COLOR_TEXT * 0.4, 1)
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	theme.set_stylebox("normal", "LineEdit", normal)

	# Focus state
	var focus := _create_stylebox(COLOR_BACKGROUND, COLOR_ACCENT, 2)
	focus.content_margin_left = 8
	focus.content_margin_right = 8
	focus.content_margin_top = 6
	focus.content_margin_bottom = 6
	theme.set_stylebox("focus", "LineEdit", focus)

	# Read-only state
	var read_only := _create_stylebox(COLOR_PANEL * 0.5, COLOR_TEXT * 0.2, 1)
	read_only.content_margin_left = 8
	read_only.content_margin_right = 8
	read_only.content_margin_top = 6
	read_only.content_margin_bottom = 6
	theme.set_stylebox("read_only", "LineEdit", read_only)

	# Text colors
	theme.set_color("font_color", "LineEdit", COLOR_TEXT)
	theme.set_color("font_placeholder_color", "LineEdit", COLOR_TEXT * 0.5)
	theme.set_color("caret_color", "LineEdit", COLOR_ACCENT)
	theme.set_color("selection_color", "LineEdit", COLOR_ACCENT * 0.5)


## Configure TabContainer with dark tabs and accent on selected.
static func _setup_tab_container_theme(theme: Theme) -> void:
	# Panel background
	var panel := _create_stylebox(COLOR_PANEL, COLOR_TEXT * 0.3, 1)
	theme.set_stylebox("panel", "TabContainer", panel)

	# Unselected tab
	var tab_unselected := _create_stylebox(COLOR_PANEL * 0.7, Color.TRANSPARENT, 0)
	tab_unselected.content_margin_left = 12
	tab_unselected.content_margin_right = 12
	tab_unselected.content_margin_top = 8
	tab_unselected.content_margin_bottom = 8
	theme.set_stylebox("tab_unselected", "TabContainer", tab_unselected)

	# Selected tab
	var tab_selected := _create_stylebox(COLOR_PANEL, COLOR_ACCENT, 2)
	tab_selected.content_margin_left = 12
	tab_selected.content_margin_right = 12
	tab_selected.content_margin_top = 8
	tab_selected.content_margin_bottom = 8
	theme.set_stylebox("tab_selected", "TabContainer", tab_selected)

	# Disabled tab
	var tab_disabled := _create_stylebox(COLOR_PANEL * 0.4, Color.TRANSPARENT, 0)
	tab_disabled.content_margin_left = 12
	tab_disabled.content_margin_right = 12
	tab_disabled.content_margin_top = 8
	tab_disabled.content_margin_bottom = 8
	theme.set_stylebox("tab_disabled", "TabContainer", tab_disabled)

	# Text colors
	theme.set_color("font_selected_color", "TabContainer", COLOR_TEXT)
	theme.set_color("font_unselected_color", "TabContainer", COLOR_TEXT * 0.7)
	theme.set_color("font_disabled_color", "TabContainer", COLOR_TEXT * 0.4)


## Configure ScrollContainer with thin dark scrollbars.
static func _setup_scroll_container_theme(theme: Theme) -> void:
	# Scrollbar background
	var scroll_bg := StyleBoxFlat.new()
	scroll_bg.bg_color = COLOR_PANEL * 0.5
	theme.set_stylebox("scroll", "VScrollBar", scroll_bg)
	theme.set_stylebox("scroll", "HScrollBar", scroll_bg)

	# Scrollbar grabber (normal)
	var scroll_grabber := StyleBoxFlat.new()
	scroll_grabber.bg_color = COLOR_TEXT * 0.4
	scroll_grabber.corner_radius_top_left = 2
	scroll_grabber.corner_radius_top_right = 2
	scroll_grabber.corner_radius_bottom_left = 2
	scroll_grabber.corner_radius_bottom_right = 2
	theme.set_stylebox("grabber", "VScrollBar", scroll_grabber)
	theme.set_stylebox("grabber", "HScrollBar", scroll_grabber)

	# Scrollbar grabber (hover)
	var scroll_grabber_hover := StyleBoxFlat.new()
	scroll_grabber_hover.bg_color = COLOR_ACCENT
	scroll_grabber_hover.corner_radius_top_left = 2
	scroll_grabber_hover.corner_radius_top_right = 2
	scroll_grabber_hover.corner_radius_bottom_left = 2
	scroll_grabber_hover.corner_radius_bottom_right = 2
	theme.set_stylebox("grabber_highlight", "VScrollBar", scroll_grabber_hover)
	theme.set_stylebox("grabber_highlight", "HScrollBar", scroll_grabber_hover)

	# Scrollbar grabber (pressed)
	var scroll_grabber_pressed := StyleBoxFlat.new()
	scroll_grabber_pressed.bg_color = COLOR_ACCENT * 0.8
	scroll_grabber_pressed.corner_radius_top_left = 2
	scroll_grabber_pressed.corner_radius_top_right = 2
	scroll_grabber_pressed.corner_radius_bottom_left = 2
	scroll_grabber_pressed.corner_radius_bottom_right = 2
	theme.set_stylebox("grabber_pressed", "VScrollBar", scroll_grabber_pressed)
	theme.set_stylebox("grabber_pressed", "HScrollBar", scroll_grabber_pressed)


## Configure separator lines.
static func _setup_separator_theme(theme: Theme) -> void:
	var hsep := StyleBoxFlat.new()
	hsep.bg_color = COLOR_TEXT * 0.2
	hsep.content_margin_top = 1
	hsep.content_margin_bottom = 1
	theme.set_stylebox("separator", "HSeparator", hsep)

	var vsep := StyleBoxFlat.new()
	vsep.bg_color = COLOR_TEXT * 0.2
	vsep.content_margin_left = 1
	vsep.content_margin_right = 1
	theme.set_stylebox("separator", "VSeparator", vsep)


## Helper to create a StyleBoxFlat with specified parameters.
static func _create_stylebox(
	bg_color: Color,
	border_color: Color,
	border_width: int = BORDER_WIDTH
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color

	if border_width > 0:
		style.border_color = border_color
		style.border_width_left = border_width
		style.border_width_right = border_width
		style.border_width_top = border_width
		style.border_width_bottom = border_width

	style.corner_radius_top_left = CORNER_RADIUS
	style.corner_radius_top_right = CORNER_RADIUS
	style.corner_radius_bottom_left = CORNER_RADIUS
	style.corner_radius_bottom_right = CORNER_RADIUS

	return style
