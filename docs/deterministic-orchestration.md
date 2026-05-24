# Deterministic Orchestration

This repo is the Godot RPG systems proof. Its orchestration should use Godot
and GUT for engine behavior, with Python reserved for static project hygiene.

## Native Tooling

- `python -m pytest` runs lightweight repo and static-validation tests.
- `python tools/validate_project.py` checks JSON, dialogue graph links, quest
  references, Godot resource paths, and cleanup boundaries.
- `python tools/playtest_audit.py` checks Act 1 location graph reachability,
  story-unlock queues, quest target links, encounter threat scores, and
  explicit dead-letter markers.
- `python scripts/validate_balance.py` checks character/enemy/encounter/skill
  and reputation tuning for gross balance defects.
- `python tools/check_release.py` runs the deterministic local gate.
- `python tools/check_release.py --godot <path-to-godot>` adds the GUT suite.
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
5. GUT passes under Godot 4.x.
6. Manual smoke covers title launch, one dialogue route, one combat route,
   party/state changes, and save/load when available.
7. Generated editor state, logs, caches, and private workshop state stay out of
   the repo.

## CI Ring

The GitHub Actions workflow runs `tools/check_release.py`, which covers the
Python, cleanup-boundary, and static gates. GUT remains a native engine release
gate unless CI is later extended to install a pinned Godot binary.

## Release Rule

Do not treat static Python validation as proof of gameplay. Static checks prove
the data and project references are coherent; Godot/GUT and manual smoke prove
the RPG prototype is actually runnable.
