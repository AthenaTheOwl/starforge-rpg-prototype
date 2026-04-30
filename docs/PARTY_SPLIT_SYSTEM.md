# Party Split System

## Overview

The Party Split system enables split-party combat encounters for the Act 1 finale, where the player controls one team (Team A) directly while issuing orders to an AI-controlled team (Team B). This creates strategic depth and narrative tension during critical story moments.

## Architecture

### Core Components

1. **PartySplit** (`scripts/combat/party_split.gd`)
   - Core logic class managing split party state
   - Simulates AI team combat
   - Tracks team B status and applies mode-based effects

2. **PartySplitUI** (`scripts/ui/party_split_ui.gd`)
   - UI controller for the split overlay
   - Displays team B status and allows order changes
   - Shows status updates during combat

3. **Party Split Overlay** (`scenes/battle/party_split_overlay.tscn`)
   - Visual scene displaying team B information
   - Member HP bars, order buttons, and status log

4. **CombatManager Integration**
   - New `is_split_combat` flag
   - `party_split` instance reference
   - `team_b_update` signal for UI updates
   - `setup_split_encounter()` method

## Usage

### Setting Up a Split Encounter

```gdscript
# In your encounter script or battle controller
var team_a := ["avyanna", "rho", "kael", "cipher"]  # Player-controlled
var team_b := ["sable", "vex", "omega"]             # AI-controlled

var team_a_enemies := [
    {"id": "enemy_0", "name": "Elite Guard", "hp": 100, "hp_max": 100},
    {"id": "enemy_1", "name": "Enforcer", "hp": 80, "hp_max": 80},
]

var team_b_enemies := [
    {"id": "enemy_2", "name": "Raider A", "hp": 50, "hp_max": 50},
    {"id": "enemy_3", "name": "Raider B", "hp": 50, "hp_max": 50},
]

# Set up split combat
CombatManager.setup_split_encounter(team_a, team_b, team_a_enemies, team_b_enemies)
```

### Displaying the Split UI

```gdscript
# In your battle scene
@onready var split_overlay: PartySplitUI = $PartySplitOverlay

func _on_combat_started() -> void:
    if CombatManager.is_split_combat and CombatManager.party_split:
        split_overlay.setup(CombatManager.party_split)
        split_overlay.visible = true

func _on_combat_ended(_result) -> void:
    if split_overlay:
        split_overlay.teardown()
```

## Team B Modes

### HOLD (Defensive)
- **Effect**: -30% damage taken, -50% damage dealt
- **Use Case**: When Team B needs to survive while Team A handles primary threats
- **Default mode** for safety

### ADVANCE (Balanced)
- **Effect**: Normal damage and defense
- **Use Case**: When both teams need to actively engage threats
- **Balanced approach** for equal splitting of combat load

### RETREAT (Recovery)
- **Effect**: -50% damage taken, no damage dealt, +10% HP/turn healing
- **Use Case**: When Team B is critically injured and needs to recover
- **Emergency mode** when survival is paramount

## Combat Flow

1. **Setup Phase**
   - Call `setup_split_encounter()` with team assignments
   - Initialize Team B status from PartyManager
   - Set Team B enemies for simulation

2. **Combat Rounds**
   - Player controls Team A directly (normal combat)
   - At end of each round, `simulate_team_b_turn()` is called
   - Team B report is emitted via `team_b_update` signal
   - UI updates to show Team B status

3. **End Phase**
   - When combat ends (victory/defeat), `merge_teams()` is called
   - Team B status is synced back to PartyManager
   - Split state is cleared

## AI Simulation

Team B combat is simulated using simplified mechanics:

### Damage Calculation
```gdscript
base_enemy_damage = 15 * enemy_count
actual_damage = base_enemy_damage * defense_multiplier
damage_per_member = actual_damage / alive_team_b_count
```

### Team Damage Output
```gdscript
base_team_damage = 20 * alive_team_b_count
actual_team_damage = base_team_damage * damage_multiplier
# Damage is distributed to defeat enemies
```

### Mode Multipliers
- **HOLD**: `defense_mult = 0.7`, `damage_mult = 0.5`
- **ADVANCE**: `defense_mult = 1.0`, `damage_mult = 1.0`
- **RETREAT**: `defense_mult = 0.5`, `damage_mult = 0.0`, `heal_rate = 10%`

## Signals

### `team_b_update(report: Dictionary)`
Emitted each round during split combat.

**Report Structure:**
```gdscript
{
    "damage_taken": int,          # Total damage to Team B this turn
    "enemies_defeated": int,      # Enemies defeated this turn
    "status": String,             # "active", "critical", or "defeated"
    "messages": Array[String],    # Status messages for UI
}
```

## Integration Example

### Act 1 Finale Encounter

```gdscript
# setup_act1_finale.gd
extends Node

func setup_finale() -> void:
    # Assault team breaches main door
    var assault_team := ["avyanna", "rho", "kael", "cipher"]

    # Hold team defends entrance
    var hold_team := ["sable", "vex", "omega"]

    # Assault faces elite guards
    var assault_enemies := [
        load_enemy("elite_guard"),
        load_enemy("security_mech"),
    ]

    # Hold team faces raiders
    var hold_enemies := [
        load_enemy("rim_raider"),
        load_enemy("rim_raider"),
        load_enemy("rim_raider"),
    ]

    CombatManager.setup_split_encounter(
        assault_team,
        hold_team,
        assault_enemies,
        hold_enemies
    )

    # Transition to battle scene
    GameManager.transition_to_scene("res://scenes/battle/battle_scene.tscn")
```

## Testing

Comprehensive integration tests are provided in `tests/integration/test_party_split.gd`:

- Team assignment and mode changes
- Damage simulation and reduction based on mode
- Healing in RETREAT mode
- Team alive/defeated detection
- Team merging and state clearing
- Enemy defeat simulation

Run tests with:
```bash
godot --headless --script addons/gut/gut_cmdln.gd -gtest=tests/integration/test_party_split.gd -gexit
```

## Design Considerations

### Balance
- Team B simulation is simplified to avoid deep combat AI
- Multipliers are tuned for strategic choice without micromanagement
- Player has limited but meaningful control over Team B

### Narrative Integration
- Status messages provide narrative flavor ("Rho holds the line!")
- Critical warnings create tension
- Team B defeat doesn't immediately fail mission (design choice)

### Performance
- Lightweight simulation avoids full combat system overhead
- No pathfinding or positioning calculations
- Scales well with multiple simultaneous encounters

## Future Enhancements

Potential improvements for later iterations:

1. **Character-specific AI**: Team B members use their actual abilities
2. **Morale system**: Team B effectiveness varies based on story state
3. **Dynamic objectives**: Team B can complete secondary goals
4. **Visual representation**: Show Team B combat in background/split screen
5. **Trust integration**: High-trust companions perform better in Team B

## File Reference

- **Core Logic**: `scripts/combat/party_split.gd`
- **UI Controller**: `scripts/ui/party_split_ui.gd`
- **Scene**: `scenes/battle/party_split_overlay.tscn`
- **Integration**: `autoload/combat_manager.gd`
- **Tests**: `tests/integration/test_party_split.gd`
- **Documentation**: `docs/PARTY_SPLIT_SYSTEM.md`
