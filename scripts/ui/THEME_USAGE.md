# UI Theme & Polish — Usage Guide

This document explains how to use the theme system and UI components for Starforge Canticles.

## Overview

The theme system provides a consistent dark sci-fi aesthetic across all UI elements. It is automatically applied via the `ThemeApplier` autoload, so all UI controls inherit the styling without manual configuration.

## Color Palette

| Color Name  | Hex Code | RGB (0-1)          | Usage                    |
|-------------|----------|--------------------|-----------------------------|
| Background  | #0a0a14  | (0.04, 0.04, 0.08) | Screen backgrounds         |
| Panel       | #141428  | (0.08, 0.08, 0.16) | Panel backgrounds          |
| Text        | #c0c0d0  | (0.75, 0.75, 0.81) | Default text color         |
| Accent      | #4060a0  | (0.25, 0.38, 0.63) | Highlights, focus states   |
| Danger      | #a04040  | (0.63, 0.25, 0.25) | Low health, errors         |
| Success     | #40a060  | (0.25, 0.63, 0.38) | High health, success msgs  |
| Warning     | #a0a040  | (0.63, 0.63, 0.25) | Medium health, warnings    |

## Themed Controls

The following controls are automatically styled by the theme:

- **Button**: Normal, hover, pressed, disabled, and focus states
- **Label**: Default text color with subtle shadow
- **PanelContainer**: Dark background with border
- **RichTextLabel**: Styled text color
- **ProgressBar**: Dark background with colored fill
- **LineEdit**: Dark input fields with accent focus
- **TabContainer**: Dark tabs with accent on selected
- **ScrollContainer**: Thin dark scrollbars with hover states
- **HSeparator/VSeparator**: Subtle divider lines

## Custom Components

### HPBar

A custom progress bar that changes color based on health percentage.

```gdscript
# Create an HPBar
var hp_bar := HPBar.new()
hp_bar.show_label = true
hp_bar.label_format = "HP: %d/%d"
add_child(hp_bar)

# Set max HP and current HP
hp_bar.set_hp_max(100, 75)  # Max 100, current 75

# Update HP with animation
hp_bar.set_hp(45, true)  # Animate to 45

# Update HP instantly
hp_bar.set_hp(100, false)  # Jump to 100
```

**Color Behavior**:
- **>70%**: Green (#40a060)
- **30-70%**: Yellow (#a0a040)
- **<30%**: Red (#a04040)

### SceneTransition

Provides smooth fade transitions between scenes.

```gdscript
# Simple scene transition (static method)
SceneTransition.transition_to("res://scenes/menus/title_screen.tscn")

# Or with a packed scene
var packed_scene := load("res://scenes/battle/battle_scene.tscn")
SceneTransition.transition_to_packed(packed_scene)

# Advanced: Use instance for custom control
var transition := SceneTransition.new()
add_child(transition)
transition.transition_midpoint.connect(_on_transition_midpoint)
transition.fade_out_in()

func _on_transition_midpoint():
    # Called at the midpoint (between fade out and fade in)
    # Good for changing scenes, swapping UI, etc.
    pass
```

## Accessing Theme Colors in Code

You can access theme colors directly from `ThemeManager`:

```gdscript
var accent_color = ThemeManager.COLOR_ACCENT
var danger_color = ThemeManager.COLOR_DANGER
```

## Example: Creating a Themed Dialog

```gdscript
# All controls automatically inherit the theme
var dialog := PanelContainer.new()
var vbox := VBoxContainer.new()
dialog.add_child(vbox)

var title := Label.new()
title.text = "Mission Briefing"
vbox.add_child(title)

var separator := HSeparator.new()
vbox.add_child(separator)

var message := RichTextLabel.new()
message.bbcode_enabled = true
message.text = "[b]Objective:[/b] Retrieve the data core from Site K-9."
vbox.add_child(message)

var close_btn := Button.new()
close_btn.text = "Acknowledged"
vbox.add_child(close_btn)

add_child(dialog)
```

## Implementation Notes

- The theme is applied in `ThemeApplier._ready()`, which runs before any scene is loaded
- ThemeApplier is registered as the **first** autoload to ensure theme is available immediately
- All existing scenes will automatically use the theme without modification
- Custom StyleBox overrides can be added per-control if needed for special cases

## Testing

To verify the theme is working:
1. Launch the game
2. Check the console for: `"ThemeApplier: Game theme applied successfully"`
3. All buttons should have dark backgrounds with accent borders on hover
4. All text should be light gray (#c0c0d0)
5. Panels should have dark blue-black backgrounds (#141428)

## Future Enhancements

Potential additions to the theme system:
- Sound effects for button clicks and transitions
- Particle effects for scene transitions
- Animated background patterns
- Theme variants (e.g., red alert mode, stealth mode)
- Accessibility options (high contrast, larger fonts)
