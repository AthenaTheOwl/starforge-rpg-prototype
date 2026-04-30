# UI Theme System — Quick Reference

## File Structure

```
scripts/ui/
├── theme_manager.gd     # Theme creation & color palette
├── theme_applier.gd     # Autoload that applies theme
├── hp_bar.gd            # Custom HP bar component
├── scene_transition.gd  # Scene fade transitions
├── THEME_USAGE.md       # Detailed usage guide
└── README_THEME.md      # This file (quick reference)

scenes/test/
└── theme_test.tscn      # Theme demonstration scene

scripts/test/
└── theme_test.gd        # Theme test controller
```

## Quick Start

### Using the Theme

The theme is **automatically applied** to all scenes via the `ThemeApplier` autoload. No manual setup required!

### Color Constants

Access theme colors anywhere in code:
```gdscript
ThemeManager.COLOR_BACKGROUND  # #0a0a14
ThemeManager.COLOR_PANEL       # #141428
ThemeManager.COLOR_TEXT        # #c0c0d0
ThemeManager.COLOR_ACCENT      # #4060a0
ThemeManager.COLOR_DANGER      # #a04040
ThemeManager.COLOR_SUCCESS     # #40a060
ThemeManager.COLOR_WARNING     # #a0a040
```

### HPBar Component

```gdscript
# Create and configure
var hp_bar := HPBar.new()
hp_bar.show_label = true
hp_bar.set_hp_max(100, 75)  # max, current

# Update with animation
hp_bar.set_hp(50, true)

# Update instantly
hp_bar.set_hp(100, false)
```

### Scene Transitions

```gdscript
# Simple transition
SceneTransition.transition_to("res://scenes/battle/battle_scene.tscn")

# With packed scene
var scene := preload("res://scenes/menus/title_screen.tscn")
SceneTransition.transition_to_packed(scene)
```

## Control Styling

All these controls are automatically themed:
- Button (normal, hover, pressed, disabled, focus)
- Label
- PanelContainer
- RichTextLabel
- ProgressBar
- LineEdit
- TabContainer
- ScrollContainer (with scrollbars)
- HSeparator / VSeparator

## Testing

Run `scenes/test/theme_test.tscn` to see all theme features in action.

## Documentation

For detailed documentation, see `THEME_USAGE.md` in this directory.

For implementation details, see `/TASK_5.2_IMPLEMENTATION.md` in project root.
