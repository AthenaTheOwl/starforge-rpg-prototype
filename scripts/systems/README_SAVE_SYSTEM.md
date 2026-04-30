# Save/Load System Documentation

## Overview

The Save/Load System provides persistent game state management with 3 manual save slots and 1 autosave slot. It serializes all game state, party data, dialogue history, and world progression to JSON files in the user data directory.

## Components

### 1. SaveManager (Autoload Singleton)
**Location:** `scripts/systems/save_manager.gd`

**Key Methods:**
- `save_game(slot: int) -> Error` - Save to slot (0-2 for manual, -1 for autosave)
- `load_game(slot: int) -> Error` - Load from slot
- `autosave() -> Error` - Quick autosave to dedicated slot
- `get_save_info(slot: int) -> Dictionary` - Get metadata without full load
- `has_save(slot: int) -> bool` - Check if save exists
- `delete_save(slot: int) -> Error` - Delete a save
- `get_all_save_info() -> Array[Dictionary]` - Get info for all slots

**Signals:**
- `game_saved(slot: int)` - Emitted when save completes
- `game_loaded(slot: int)` - Emitted when load completes
- `autosave_triggered()` - Emitted when autosave begins

### 2. SaveLoadScreen UI
**Location:** `scenes/menus/save_load_screen.tscn`
**Script:** `scripts/ui/save_load_screen.gd`

**Usage:**
```gdscript
var save_load_scene := load("res://scenes/menus/save_load_screen.tscn")
var screen := save_load_scene.instantiate()
add_child(screen)
screen.setup(SaveLoadScreen.Mode.SAVE)  # or Mode.LOAD
screen.action_complete.connect(_on_save_complete)
```

### 3. Enhanced GameManager
**Added Fields:**
- `cleared_encounters: Array[String]` - Track completed encounters
- `unlocked_locations: Array[String]` - Track accessible locations
- `current_location: String` - Current exploration location

**Added Methods:**
- `mark_encounter_cleared(encounter_id: String)`
- `is_encounter_cleared(encounter_id: String) -> bool`
- `unlock_location(location_id: String)`
- `is_location_unlocked(location_id: String) -> bool`

## Save Data Structure

```json
{
  "version": "1.0",
  "timestamp": "2026-02-01T12:00:00",
  "playtime_seconds": 3600,
  "save_name": "Manual Save 1",
  "party": {
    "roster": {...},
    "active_party": [...],
    "loadouts": {...}
  },
  "game_state": {
    "flags": {...},
    "reputation": {...},
    "current_act": 1,
    "current_chapter": 1,
    "current_location": "act1_site_k9",
    "cleared_encounters": [...],
    "unlocked_locations": [...]
  },
  "dialogue_history": [...]
}
```

## Autosave Triggers

The system automatically saves at key moments:

1. **After Combat Victory** - Triggered in `CombatManager._check_combat_end()`
2. **After Recruitment** - When flags starting with `recruited_` are set
3. **Story Milestones** - When flags starting with `act_`, `chapter_`, or `milestone_` are set

## File Locations

Save files are stored in the Godot user data directory:
- **Linux:** `~/.local/share/godot/app_userdata/Starforge Canticles/saves/`
- **Windows:** `%APPDATA%\Godot\app_userdata\Starforge Canticles\saves\`
- **macOS:** `~/Library/Application Support/Godot/app_userdata/Starforge Canticles/saves/`

Files:
- `save_0.json` - Manual slot 1
- `save_1.json` - Manual slot 2
- `save_2.json` - Manual slot 3
- `autosave.json` - Autosave slot

## Integration Examples

### Manual Save from Exploration Screen
```gdscript
func _on_save_button_pressed() -> void:
    var err := SaveManager.save_game(0)
    if err == OK:
        show_notification("Game saved!")
    else:
        show_error("Save failed: %s" % error_string(err))
```

### Load Game from Title Screen
```gdscript
func _on_load_game() -> void:
    var save_load_screen := preload("res://scenes/menus/save_load_screen.tscn").instantiate()
    add_child(save_load_screen)
    save_load_screen.setup(SaveLoadScreen.Mode.LOAD)
    save_load_screen.action_complete.connect(_on_load_complete)
```

### Trigger Autosave on Story Event
```gdscript
func _on_story_milestone_reached() -> void:
    GameManager.set_flag("milestone_act1_complete")  # This triggers autosave
```

## Testing

Unit tests are located in `tests/unit/test_save_system.gd` and cover:
- Save file creation and validation
- State restoration accuracy
- Round-trip save/load consistency
- Error handling for invalid operations
- Metadata retrieval without full load

Run tests with:
```bash
./gut_tests_runner.sh -gtest=test_save_system.gd
```

## Notes

- Save files are human-readable JSON for debugging purposes
- All save operations are synchronous and complete before returning
- The system handles typed array conversion from JSON automatically
- Autosaves do not overwrite manual saves
- Save operations are safe to call during gameplay state transitions
