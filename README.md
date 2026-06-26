# starforge-rpg-prototype

The weakest thing in Act 1 is a husk echo: 70 hit points, 16 attack. The nastiest
is a mine breach with 508 and 188. Between those two numbers sits a party of seven,
nineteen locations, and a corporate conspiracy that mostly wants you to fill out
the right paperwork before it kills you. This repo is that game, prototyped.

## What it does

[Starforge Canticles](https://www.royalroad.com/fiction/149065/starforge-canticles)
is a serialized speculative-fiction novel I publish chapter by chapter on Royal Road.
This repo is one of its game-adaptation paths: Act 1 built as a data-driven Godot 4
RPG. Party management, turn-based combat, branching dialogue, relationship state,
quests, save/load, and the UI to drive all of it.

Everything that matters is JSON. Seven playable crew, 21 enemies across 14 encounters,
13 quests, 23 dialogue trees with 50 skill checks in them. The Godot scenes read the
data; change a number in a file and the fight changes. The point of a prototype is
that the systems are real even when the art isn't, and these are.

Active development happens in a private workshop. This public copy is for review and
future iteration. Unreleased later-act material stays sealed.

## Try it

Godot isn't required to inspect the world. The playtest audit walks the data and
reports what it found:

```powershell
python tools\playtest_audit.py
```

```
Godot playtest audit
- locations: 19
- reachable locations: 5
- quests: 13
- encounters: 14
- enemies: 21
- dead-letter marker hits: 3
- lowest encounter threat: act1_husk_echo hp=70 atk=16
- highest encounter threat: act1_mine_breach hp=508 atk=188

Dead-letter / balance queue:
- location act1_guild_station: one-way connection to act1_lumen_thief_bridge
- location act1_contract_sites: one-way connection to act1_lumen_thief_bridge
...
```

Five of nineteen locations are reachable from the opening. The other fourteen are
behind story unlocks, which the audit flags as a dead-letter queue rather than
trusting — a one-way door into a room you can't leave is a bug or a plot point, and
the tool makes you say which.

## Validate without Godot

The lightweight checks run on plain Python:

```powershell
python -m pytest
python tools\validate_project.py
python tools\playtest_audit.py
python scripts\validate_balance.py
python tools\check_release.py
```

`validate_balance.py` is the one that argues with the writer: it'll PASS the seven
character stats and the 14 encounters, then WARN that the Cult Hierophant is an
80-HP boss in a 150-plus weight class, and that Nyx has accrued 99 reputation across
all her dialogues when 50 is the sane ceiling. Balance is a number that drifts; this
catches the drift before a playtester does.

With Godot installed, run the GUT suite from the editor or CLI using the included
`.gutconfig.json`.

For the full native release gate on a machine with Godot installed:

```powershell
python tools\check_release.py --clean --fail-on-generated --require-godot --godot C:\path\to\Godot.exe
```

`tools/check_release.py` is the deterministic orchestration entry point. Python
checks cover static project/data validation, the path/dead-letter audit, and balance.
Godot/GUT is the engine-native gate. The `--clean` flag removes known Godot editor
artifacts before and after the native run; generated editor state is release-blocking.
See `docs/deterministic-orchestration.md` for the proof gates.

## Run locally

1. Install Godot 4.6 or newer.
2. Open this folder in Godot.
3. Run the project. Main scene: `scenes/menus/title_screen.tscn`.

## Browser build (needs the Godot HTML5 export toolchain)

This is a Godot 4.6 project on the GL Compatibility renderer, not a browser-ready
bundle. A web-playable build is feasible through Godot's **Web (HTML5)** export, but
that needs the Godot editor plus matching export templates to emit a WebAssembly
bundle. There's no checked-in HTML5 export, and one can't be faked without that
toolchain, so this repo is documented as run-locally rather than one-click deployable.

To produce the web build on a machine with Godot 4.6:

1. Open the project in the Godot editor.
2. Install the export templates for 4.6 (Editor > Manage Export Templates).
3. Project > Export... > add a **Web** preset.
4. Export the project. Godot emits `index.html`, a `.wasm`, a `.pck`, and loader JS
   into the chosen output directory.
5. That output directory is a static bundle you can host anywhere static
   (Vercel, Netlify, GitHub Pages, itch.io). Note: the Web export needs the server
   to send the `Cross-Origin-Opener-Policy`/`Cross-Origin-Embedder-Policy` headers
   (SharedArrayBuffer requirement) for threaded builds.

Until that export exists, play it locally in the Godot editor as described above.

## Cleanup boundary

Included: Godot source files, data JSON, scenes, scripts, GUT tests, the
deterministic playtest and balance validators, docs and examples.

Excluded: `.git`, `.godot`, `.beads`, local daemon/mayor/refinery task state,
runtime logs and caches.

## How it connects

Part of the Starforge cluster — one serial, several playable shapes:

- [starforge-narrative-tools](https://github.com/AthenaTheOwl/starforge-narrative-tools) — the public Act 1 corpus plus conversion and validation tooling.
- [starforge-renpy-demo](https://github.com/AthenaTheOwl/starforge-renpy-demo) — Act 1 as a Ren'Py narrative demo.
- [starforge-twine-demo](https://github.com/AthenaTheOwl/starforge-twine-demo) — the same Act 1 as a single-HTML Twine/SugarCube demo.
- [starforge-choicescript-demo](https://github.com/AthenaTheOwl/starforge-choicescript-demo) — a stat-forward ChoiceScript demo.

This repo is the heaviest of the four: the others tell Act 1, this one makes you
fight through it.

## License

MIT. See [LICENSE](LICENSE).
