# Verification scope — October 19, 2026

The full native release command ran with official portable Godot 4.7.2. It passed
Python tests, project validation, route/dead-letter and balance checks, clean
engine import, GUT, and 28 deterministic gameplay smoke checks. The previous
October 18 engine `not_run` status is superseded by this actual native evidence.
The [native verification record](native-verification-2026-10-19.md) describes the
exercised controls, repairs and diagnostic limits.

Native tests cover repaired dialogue entrances, accepting or deferring a surname,
authored skill-check outcomes, and every callback with its flag true, false and
absent. Multiple callbacks compose once per render. Structural reachability is
checked separately; it does not mean every branch was played from the title.

The static audit still reports 19 locations, 5 directly reachable from the opening,
13 quests, 14 encounters and 21 enemies. Story-unlocked and one-way location routes
remain queued. Three explicit UI TODOs remain: discard confirmation, party screen
and settings screen. Balance retains four warnings about Cult Hierophant HP
and cumulative Nyx/Rho/Vesper reputation. These are not
newly certified features. Missing chapter music, unsupported custom reputation
keys, manual visual playthrough, full-campaign balance and browser deployment
remain separate scopes documented in the native record.

Reproduce the native gate:

```powershell
python tools/check_release.py --clean --fail-on-generated --require-godot --godot C:\path\to\Godot.exe
```

The command isolates engine state under ignored `reports/native-state/`, rebuilds
the class cache, verifies every source GUT method against JUnit, and removes
`.godot/` after the run. Native steps have 180-second timeouts. Static-only runs
remain useful and explicitly print that engine checks were skipped.
