# No. 16 - starforge-rpg-prototype

[Starforge Canticles](https://www.royalroad.com/fiction/149065/starforge-canticles)
is a serialized speculative-fiction novel I'm publishing chapter-by-chapter on
Royal Road. This repo is a second game-adaptation path for the same serial:
Act 1 prototyped as a data-driven Godot 4 RPG with party management, combat,
branching dialogue, quests, save/load, and UI.

Active development happens in a private workshop. This public copy is meant for
portfolio review and future iteration; unreleased later-act material is excluded.

## What this proves

- Narrative scope can be backed by data-driven RPG systems.
- The project has concrete mechanics: party management, combat resolution,
  dialogue, relationship state, quests, save/load, and UI.
- The repo is curated for review: source is included, editor/runtime junk is
  excluded, and validation is explicit.
- The project is intentionally in progress: a public serial first, plus an
  exploratory game adaptation shaped by AI-assisted creative tooling.

## Run locally

1. Install Godot 4.6 or newer.
2. Open this folder in Godot.
3. Run the project. Main scene: `scenes/menus/title_screen.tscn`.

## Validate without Godot

Godot is not required for the lightweight repository checks:

```powershell
python -m pytest
python tools\validate_project.py
```

With Godot installed, run the GUT suite from the editor or CLI using the
included `.gutconfig.json`.

## Cleanup boundary

Included:

- Godot source files
- data JSON
- scenes
- scripts
- GUT tests
- docs and examples

Excluded:

- `.git`
- `.godot`
- `.beads`
- local daemon/mayor/refinery task state
- runtime logs and caches

## See also

Part of the Starforge cluster:

- [starforge-narrative-tools](https://github.com/AthenaTheOwl/starforge-narrative-tools) - public Act 1 corpus + conversion/validation tooling
- [starforge-renpy-demo](https://github.com/AthenaTheOwl/starforge-renpy-demo) - Act 1 Ren'Py narrative demo copy
