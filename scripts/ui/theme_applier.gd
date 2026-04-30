extends Node
## ThemeApplier — Autoload that applies the game theme to all UI.
##
## Creates the theme via ThemeManager and applies it to the root viewport
## so all UI controls inherit the dark sci-fi aesthetic automatically.

var game_theme: Theme


func _ready() -> void:
	_apply_theme()


func _apply_theme() -> void:
	# Create the game theme
	game_theme = ThemeManager.create_game_theme()

	# Apply to root viewport so all UI inherits it
	get_tree().root.set("theme", game_theme)

	print("ThemeApplier: Game theme applied successfully")


## Get the current game theme (useful for runtime theme queries).
func get_game_theme() -> Theme:
	return game_theme
