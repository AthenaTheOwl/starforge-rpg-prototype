#!/usr/bin/env python3
"""
Game Balance Validation Script
Validates game balance data across characters, enemies, encounters, and dialogue.
"""

import json
import os
import sys
from pathlib import Path
from typing import Dict, List, Tuple, Any, Set

# Color codes for terminal output
class Colors:
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    BLUE = '\033[94m'
    RESET = '\033[0m'
    BOLD = '\033[1m'

class ValidationResult:
    def __init__(self):
        self.passes = []
        self.warnings = []
        self.failures = []

    def add_pass(self, message: str):
        self.passes.append(message)

    def add_warning(self, message: str):
        self.warnings.append(message)

    def add_failure(self, message: str):
        self.failures.append(message)

    def has_failures(self) -> bool:
        return len(self.failures) > 0

    def print_results(self):
        print(f"\n{Colors.BOLD}=== VALIDATION RESULTS ==={Colors.RESET}\n")

        if self.passes:
            print(f"{Colors.GREEN}PASS:{Colors.RESET}")
            for msg in self.passes:
                print(f"  ✓ {msg}")

        if self.warnings:
            print(f"\n{Colors.YELLOW}WARN:{Colors.RESET}")
            for msg in self.warnings:
                print(f"  ⚠ {msg}")

        if self.failures:
            print(f"\n{Colors.RED}FAIL:{Colors.RESET}")
            for msg in self.failures:
                print(f"  ✗ {msg}")

        print(f"\n{Colors.BOLD}Summary:{Colors.RESET}")
        print(f"  Passed: {Colors.GREEN}{len(self.passes)}{Colors.RESET}")
        print(f"  Warnings: {Colors.YELLOW}{len(self.warnings)}{Colors.RESET}")
        print(f"  Failed: {Colors.RED}{len(self.failures)}{Colors.RESET}")

def find_project_root() -> Path:
    """Find the project root directory."""
    current = Path.cwd()
    while current != current.parent:
        if (current / "project.godot").exists():
            return current
        current = current.parent
    # If not found from cwd, try from script location
    script_dir = Path(__file__).parent.parent
    if (script_dir / "project.godot").exists():
        return script_dir
    raise RuntimeError("Could not find project root (no project.godot found)")

def load_json_files(directory: Path, pattern: str = "*.json") -> Dict[str, Any]:
    """Load all JSON files from a directory."""
    files = {}
    if not directory.exists():
        return files

    for filepath in directory.glob(pattern):
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                data = json.load(f)
                files[filepath.stem] = {
                    'path': filepath,
                    'data': data
                }
        except json.JSONDecodeError as e:
            print(f"{Colors.RED}Error loading {filepath}: {e}{Colors.RESET}")
        except Exception as e:
            print(f"{Colors.RED}Unexpected error loading {filepath}: {e}{Colors.RESET}")

    return files

def validate_character_stats(characters: Dict[str, Any], result: ValidationResult):
    """Validate character stats are within expected ranges."""
    print(f"\n{Colors.BLUE}Checking character stats...{Colors.RESET}")

    stat_ranges = {
        'hp_max': (60, 120),
        'speed': (6, 14),
        'attack': (8, 18),
        'armor': (0, 12),
        'shields': (0, 8),
        'wards': (0, 10)
    }

    if not characters:
        result.add_warning("No character files found in data/characters/")
        return

    all_valid = True
    for char_id, char_info in characters.items():
        char_data = char_info['data']
        char_name = char_data.get('name', char_id)

        for stat, (min_val, max_val) in stat_ranges.items():
            if stat not in char_data:
                result.add_failure(f"Character '{char_name}': missing stat '{stat}'")
                all_valid = False
                continue

            value = char_data[stat]
            if not isinstance(value, (int, float)):
                result.add_failure(f"Character '{char_name}': stat '{stat}' is not a number (got {type(value).__name__})")
                all_valid = False
                continue

            if value < min_val or value > max_val:
                result.add_failure(f"Character '{char_name}': {stat}={value} out of range [{min_val}-{max_val}]")
                all_valid = False

    if all_valid:
        result.add_pass(f"All {len(characters)} character stats within expected ranges")

def validate_enemy_scaling(enemies: Dict[str, Any], result: ValidationResult):
    """Validate enemy stat scaling and difficulty progression."""
    print(f"\n{Colors.BLUE}Checking enemy stat scaling...{Colors.RESET}")

    if not enemies:
        result.add_warning("No enemy files found in data/enemies/")
        return

    # Categorize enemies by HP
    tutorial_enemies = []  # ~40HP
    mid_enemies = []       # ~60-80HP
    late_enemies = []      # ~90-120HP
    boss_enemies = []      # ~150+HP

    for enemy_id, enemy_info in enemies.items():
        enemy_data = enemy_info['data']
        enemy_name = enemy_data.get('name', enemy_id)
        hp = enemy_data.get('hp_max', 0)

        if 'hp_max' not in enemy_data:
            result.add_failure(f"Enemy '{enemy_name}': missing hp_max")
            continue

        # Check if it's marked as a boss
        is_boss = 'BOSS' in enemy_data.get('description', '').upper() or 'boss' in enemy_id.lower()

        if is_boss:
            if hp < 150:
                result.add_warning(f"Boss '{enemy_name}': HP={hp} is below expected boss range (150+)")
            boss_enemies.append((enemy_name, hp))
        elif hp <= 45:
            tutorial_enemies.append((enemy_name, hp))
        elif hp <= 85:
            mid_enemies.append((enemy_name, hp))
        elif hp <= 125:
            late_enemies.append((enemy_name, hp))
        else:
            boss_enemies.append((enemy_name, hp))

    # Report findings
    if tutorial_enemies:
        result.add_pass(f"Found {len(tutorial_enemies)} tutorial-tier enemies (≤45 HP)")
    if mid_enemies:
        result.add_pass(f"Found {len(mid_enemies)} mid-tier enemies (46-85 HP)")
    if late_enemies:
        result.add_pass(f"Found {len(late_enemies)} late-tier enemies (86-125 HP)")
    if boss_enemies:
        result.add_pass(f"Found {len(boss_enemies)} boss-tier enemies (126+ HP)")

    # Validate progression exists
    if not tutorial_enemies and not mid_enemies:
        result.add_warning("No early-game enemies found (HP < 85)")

    # Check for stat consistency
    for enemy_id, enemy_info in enemies.items():
        enemy_data = enemy_info['data']
        enemy_name = enemy_data.get('name', enemy_id)

        required_stats = ['hp_max', 'speed', 'attack', 'armor', 'shields', 'wards']
        for stat in required_stats:
            if stat not in enemy_data:
                result.add_failure(f"Enemy '{enemy_name}': missing required stat '{stat}'")

def validate_encounter_validity(encounters: Dict[str, Any], enemies: Dict[str, Any], result: ValidationResult):
    """Validate encounter structure and enemy references."""
    print(f"\n{Colors.BLUE}Checking encounter validity...{Colors.RESET}")

    if not encounters:
        result.add_warning("No encounter files found in data/encounters/")
        return

    # Build set of valid enemy IDs
    valid_enemy_ids = set(enemies.keys())

    all_valid = True
    for encounter_id, encounter_info in encounters.items():
        encounter_data = encounter_info['data']
        encounter_name = encounter_data.get('name', encounter_id)

        # Check for waves
        if 'waves' not in encounter_data:
            result.add_failure(f"Encounter '{encounter_name}': missing 'waves' field")
            all_valid = False
            continue

        waves = encounter_data['waves']
        if not isinstance(waves, list):
            result.add_failure(f"Encounter '{encounter_name}': 'waves' is not a list")
            all_valid = False
            continue

        if len(waves) == 0:
            result.add_failure(f"Encounter '{encounter_name}': has no waves")
            all_valid = False
            continue

        # Validate each wave
        for wave_idx, wave in enumerate(waves):
            if not isinstance(wave, dict):
                result.add_failure(f"Encounter '{encounter_name}' wave {wave_idx}: not a dict")
                all_valid = False
                continue

            if 'enemies' not in wave:
                result.add_failure(f"Encounter '{encounter_name}' wave {wave_idx}: missing 'enemies' field")
                all_valid = False
                continue

            enemies_list = wave['enemies']
            if not isinstance(enemies_list, list):
                result.add_failure(f"Encounter '{encounter_name}' wave {wave_idx}: 'enemies' is not a list")
                all_valid = False
                continue

            if len(enemies_list) == 0:
                result.add_failure(f"Encounter '{encounter_name}' wave {wave_idx}: no enemies defined")
                all_valid = False
                continue

            # Validate enemy references
            for enemy_idx, enemy_ref in enumerate(enemies_list):
                if not isinstance(enemy_ref, dict):
                    result.add_failure(f"Encounter '{encounter_name}' wave {wave_idx} enemy {enemy_idx}: not a dict")
                    all_valid = False
                    continue

                if 'type' not in enemy_ref:
                    result.add_failure(f"Encounter '{encounter_name}' wave {wave_idx} enemy {enemy_idx}: missing 'type' field")
                    all_valid = False
                    continue

                enemy_type = enemy_ref['type']
                if enemy_type not in valid_enemy_ids:
                    result.add_failure(f"Encounter '{encounter_name}' wave {wave_idx}: references unknown enemy type '{enemy_type}'")
                    all_valid = False

                if 'count' not in enemy_ref:
                    result.add_failure(f"Encounter '{encounter_name}' wave {wave_idx} enemy {enemy_idx}: missing 'count' field")
                    all_valid = False
                elif not isinstance(enemy_ref['count'], int) or enemy_ref['count'] < 1:
                    result.add_failure(f"Encounter '{encounter_name}' wave {wave_idx} enemy {enemy_idx}: invalid count value")
                    all_valid = False

    if all_valid:
        result.add_pass(f"All {len(encounters)} encounters have valid structure and enemy references")

def validate_skill_checks(dialogues: Dict[str, Any], result: ValidationResult):
    """Validate skill check DCs and branch structure."""
    print(f"\n{Colors.BLUE}Checking skill check DCs...{Colors.RESET}")

    if not dialogues:
        result.add_warning("No dialogue files found in data/dialogue/")
        return

    total_skill_checks = 0
    all_valid = True

    for dialogue_id, dialogue_info in dialogues.items():
        dialogue_data = dialogue_info['data']

        if 'nodes' not in dialogue_data:
            continue

        nodes = dialogue_data['nodes']
        for node_id, node_data in nodes.items():
            if not isinstance(node_data, dict):
                continue

            # Check if this node has a skill check
            skill_check = None

            # Skill checks can be in the node itself
            if 'skill_check' in node_data:
                skill_check = node_data['skill_check']
                check_location = f"{dialogue_id}::{node_id}"

            # Or in choices
            if 'choices' in node_data:
                for choice_idx, choice in enumerate(node_data['choices']):
                    if isinstance(choice, dict) and 'skill_check' in choice:
                        skill_check = choice['skill_check']
                        check_location = f"{dialogue_id}::{node_id}::choice[{choice_idx}]"

                        if not isinstance(skill_check, dict):
                            result.add_failure(f"Skill check at {check_location}: not a dict")
                            all_valid = False
                            continue

                        total_skill_checks += 1

                        # Validate DC
                        if 'dc' not in skill_check:
                            result.add_failure(f"Skill check at {check_location}: missing 'dc' field")
                            all_valid = False
                        else:
                            dc = skill_check['dc']
                            if not isinstance(dc, int):
                                result.add_failure(f"Skill check at {check_location}: DC is not an integer")
                                all_valid = False
                            elif dc < 8 or dc > 18:
                                result.add_failure(f"Skill check at {check_location}: DC={dc} out of range [8-18]")
                                all_valid = False

                        # Validate skill name
                        if 'skill' not in skill_check:
                            result.add_failure(f"Skill check at {check_location}: missing 'skill' field")
                            all_valid = False

            # If node itself has skill check, validate it
            if 'skill_check' in node_data:
                skill_check = node_data['skill_check']
                check_location = f"{dialogue_id}::{node_id}"

                if not isinstance(skill_check, dict):
                    result.add_failure(f"Skill check at {check_location}: not a dict")
                    all_valid = False
                    continue

                total_skill_checks += 1

                # Validate DC
                if 'dc' not in skill_check:
                    result.add_failure(f"Skill check at {check_location}: missing 'dc' field")
                    all_valid = False
                else:
                    dc = skill_check['dc']
                    if not isinstance(dc, int):
                        result.add_failure(f"Skill check at {check_location}: DC is not an integer")
                        all_valid = False
                    elif dc < 8 or dc > 18:
                        result.add_failure(f"Skill check at {check_location}: DC={dc} out of range [8-18]")
                        all_valid = False

                # Validate skill name
                if 'skill' not in skill_check:
                    result.add_failure(f"Skill check at {check_location}: missing 'skill' field")
                    all_valid = False

                # Validate both pass and fail branches exist
                has_success = 'on_success' in skill_check
                has_failure = 'on_failure' in skill_check

                if not (has_success and has_failure):
                    result.add_warning(f"Skill check at {check_location}: missing success/failure branches")

    if total_skill_checks == 0:
        result.add_warning("No skill checks found in dialogue files")
    elif all_valid:
        result.add_pass(f"All {total_skill_checks} skill checks have valid DCs (8-18) and structure")

def validate_reputation_sanity(dialogues: Dict[str, Any], result: ValidationResult):
    """Validate reputation amounts and totals."""
    print(f"\n{Colors.BLUE}Checking reputation sanity...{Colors.RESET}")

    if not dialogues:
        result.add_warning("No dialogue files found in data/dialogue/")
        return

    # Track total reputation per character across all dialogues
    total_reputation = {}
    max_single_grant = 0
    max_single_grant_location = ""
    all_valid = True

    for dialogue_id, dialogue_info in dialogues.items():
        dialogue_data = dialogue_info['data']

        if 'nodes' not in dialogue_data:
            continue

        nodes = dialogue_data['nodes']
        for node_id, node_data in nodes.items():
            if not isinstance(node_data, dict):
                continue

            # Check node-level reputation
            if 'reputation' in node_data:
                rep_data = node_data['reputation']
                if isinstance(rep_data, dict):
                    for character, amount in rep_data.items():
                        if not isinstance(amount, (int, float)):
                            result.add_failure(f"Reputation at {dialogue_id}::{node_id}: '{character}' amount is not a number")
                            all_valid = False
                            continue

                        if abs(amount) > 5:
                            result.add_failure(f"Reputation at {dialogue_id}::{node_id}: '{character}' amount={amount} exceeds max (±5)")
                            all_valid = False

                        if abs(amount) > abs(max_single_grant):
                            max_single_grant = amount
                            max_single_grant_location = f"{dialogue_id}::{node_id}"

                        # Track total
                        if character not in total_reputation:
                            total_reputation[character] = 0
                        total_reputation[character] += amount

            # Check choice-level reputation
            if 'choices' in node_data:
                for choice_idx, choice in enumerate(node_data['choices']):
                    if isinstance(choice, dict) and 'reputation' in choice:
                        rep_data = choice['reputation']
                        if isinstance(rep_data, dict):
                            for character, amount in rep_data.items():
                                if not isinstance(amount, (int, float)):
                                    result.add_failure(f"Reputation at {dialogue_id}::{node_id}::choice[{choice_idx}]: '{character}' amount is not a number")
                                    all_valid = False
                                    continue

                                if abs(amount) > 5:
                                    result.add_failure(f"Reputation at {dialogue_id}::{node_id}::choice[{choice_idx}]: '{character}' amount={amount} exceeds max (±5)")
                                    all_valid = False

                                if abs(amount) > abs(max_single_grant):
                                    max_single_grant = amount
                                    max_single_grant_location = f"{dialogue_id}::{node_id}::choice[{choice_idx}]"

                                # Track total
                                if character not in total_reputation:
                                    total_reputation[character] = 0
                                total_reputation[character] += amount

    # Check totals
    for character, total in total_reputation.items():
        if abs(total) > 50:
            result.add_warning(f"Character '{character}': total reputation across all dialogues = {total} (exceeds reasonable max of 50)")

    if total_reputation:
        if all_valid:
            result.add_pass(f"All reputation grants ≤5, total per-character reasonable (<50)")
        result.add_pass(f"Found reputation tracking for {len(total_reputation)} characters")
    else:
        result.add_warning("No reputation grants found in dialogue files")

def main():
    """Main validation function."""
    print(f"{Colors.BOLD}{Colors.BLUE}Starforge RPG - Balance Validation{Colors.RESET}")
    print("=" * 60)

    result = ValidationResult()

    try:
        # Find project root
        project_root = find_project_root()
        print(f"Project root: {project_root}")

        # Load data files
        data_dir = project_root / "data"

        print(f"\n{Colors.BLUE}Loading data files...{Colors.RESET}")
        characters = load_json_files(data_dir / "characters")
        enemies = load_json_files(data_dir / "enemies")
        encounters = load_json_files(data_dir / "encounters")
        dialogues = load_json_files(data_dir / "dialogue")

        print(f"  Characters: {len(characters)}")
        print(f"  Enemies: {len(enemies)}")
        print(f"  Encounters: {len(encounters)}")
        print(f"  Dialogues: {len(dialogues)}")

        # Run validations
        validate_character_stats(characters, result)
        validate_enemy_scaling(enemies, result)
        validate_encounter_validity(encounters, enemies, result)
        validate_skill_checks(dialogues, result)
        validate_reputation_sanity(dialogues, result)

        # Print results
        result.print_results()

        # Exit with appropriate code
        sys.exit(1 if result.has_failures() else 0)

    except Exception as e:
        print(f"\n{Colors.RED}Fatal error: {e}{Colors.RESET}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main()
