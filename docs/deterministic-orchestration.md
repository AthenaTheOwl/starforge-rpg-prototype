# Deterministic Orchestration

This repo is the Godot RPG systems proof. Its orchestration should use Godot
and GUT for engine behavior, with Python reserved for static project hygiene.

## Native Tooling

- `python -m pytest` runs lightweight repo and static-validation tests.
- `python tools/validate_project.py` checks JSON, dialogue graph links, callback
  schema and downstream writer provenance, that each callback can render on one
  route through the act and stay silent on another, that every flag the game
  reads has a writer (listed exceptions aside), quest references, Godot resource
  paths, and cleanup boundaries.
- `python tools/playtest_audit.py` checks Act 1 location graph reachability,
  story-unlock queues, quest target links, encounter threat scores, and
  explicit dead-letter markers.
- `python scripts/validate_balance.py` checks character/enemy/encounter/skill
  and reputation tuning for gross balance defects.
- `python tools/check_release.py` runs the deterministic local gate.
- `python tools/check_release.py --godot <path-to-godot>` imports the project,
  adds the GUT suite and runs `tools/runtime_smoke.gd`.
- `python tools/check_release.py --clean --fail-on-generated --require-godot --godot <path-to-godot>`
  is the full release gate for a machine with Godot installed.
- `--clean` removes only known Godot editor churn: `.godot/`.

## Proof Gates

1. Godot project shape is intact: `project.godot`, main scene, scripts, scenes,
   data, and GUT tests are present.
2. Static project validation passes.
3. Playtest path/dead-letter audit passes. One-way and story-unlocked routes
   are queued, not hidden.
4. Balance validation passes with warnings preserved in the queue.
5. All project scripts compile, including unused scene dependencies. Every
   checked-in GUT method passes with assertions. Missing/incomplete JUnit,
   ignored scripts, risky tests and script errors fail the gate.
6. The seeded native smoke covers title launch, dialogue controls, a real combat
   damage/escape route, party/state changes, and save/load. This is automated
   engine proof; manual visual playtesting remains a separate acceptance step.
7. Generated editor state, logs, caches, and private workshop state stay out of
   the repo.

## CI Ring

The workflow retains its static job and adds a native job using official portable
Godot 4.7.2 on Linux, pinned by version and SHA256. It runs the same full release
command. Local Windows evidence does not establish remote CI success: inspect
checks on the exact proposed commit before landing it.

## Release Rule

Do not treat static Python validation as proof of gameplay. Static checks prove
the data and project references are coherent; Godot/GUT and manual smoke prove
the exercised RPG flows are runnable. Neither a passing suite nor a deterministic
smoke proves a complete campaign playthrough, visual quality, or balance.
