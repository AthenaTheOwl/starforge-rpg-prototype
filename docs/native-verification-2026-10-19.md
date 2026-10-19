# Native verification — October 19, 2026

## Exercised behavior

The native gate uses official Godot `4.7.2.stable.official.ed1daf0bf` and vendored
GUT 9.3. The fresh release run passed the Python and GUT suites with no skipped,
ignored or risky methods. The seeded smoke
(`1342`) loads the actual title, emits New Game,
advances prologue/rescue through dialogue controls, enters the tutorial battle,
selects Tear-Sense and a target, observes damage and enemy turns, then escapes
to story flow. Escape must not mark victory. It recruits a party member as a
system check, saves/loads through slot and overwrite-confirmation controls,
verifies flags/HP/completed dialogue progress, checks chapter Save interoperability
and Escape/Resume, and returns through a packed-scene transition: 28 checks.

GUT selects the new Nyx safeguard lesson and alternative AI protection question
from their original scene starts and follows each to its exit. It tests accepting
or deferring the surname without blocking progression. Actual authored check
choices are exercised with natural 1 and 20, requiring one roll at the correct
node and the authored outcome rather than a premature scene end.
Nine duplicate inline checks now delegate after their original staging, using
eight new check routers and one existing standalone check. Tests verify the
staging text is displayed, then the original skill/outcome contract rolls once.
Graph validation follows executable successors rather than an ignored `next`.
Packed ChapterFlow/DialogueController tests keep explicit, implicit and
unavailable-choice terminal text visible through typewriter completion. All four
new closing-node callbacks remain readable, and story completion occurs only
after the actual Continue control. Explicit choice-to-end still acknowledges the
conversation. Legacy check buttons use the same normalized skill/difficulty
metadata as resolution.

## Repairs and ongoing gates

Fresh imports register global classes before GUT. A preflight checks Godot's
actual `user://` path is contained in the test state root before any save-deleting
tests run; a mismatch blocks both GUT and smoke. Native steps have 180-second
timeouts. Script errors, ignored/risky tests and missing/incomplete JUnit coverage
fail even if the engine exits zero. The GUT Logger alias and explicit numeric/
collection fixtures support current GDScript. Scene transitions no longer await
already-emitted ready signals, and the actual battle ability closures compile.
Every project GDScript under `autoload/`, `scripts/`, `examples/` and `tools/`
must compile before GUT. This includes unused public scene dependencies. An
isolated Web export exposed the HPBar custom-property parent call and an
exploration closure's Variant inference; those are fixed, with native HPBar
value/maximum/color/tween regressions. Vendored GUT and test scripts are exercised
by their separate inventoried suite.

Dialogue resolves both canonical variant/check formats. Additive same-speaker
`echoes: [{flag, text}]` render every true callback after the resolved base text,
once per render. Native tests cover true/false/unset, simultaneous flags, repeated
renders and unchosen-choice isolation. Static schema and downstream writer checks
reject reference metadata or same-node effects presented as executed callbacks.
The authorized public Act 1 repairs add contextual consequences for 109 unread
decisions/events and reconnect existing branches while preserving original prose.

Naming completion and surname acceptance remain distinct. Waffle's original
accepted-name line is a conditional variant; deferral leaves the surname unset.
Canonical Waffle.bat affinity maps to `waffle`, while faction/stat reputation
does not become character affinity.

Chapter and exploration Save buttons use the same SaveManager format as Load.
Earlier public flat-format saves are normalized only while reading: available
flags, chapter, party/HP and story progress survive; nested records take precedence,
missing history is not invented, and the file is not rewritten. The pause overlay
receives the opening Escape while running and continues processing while paused.

## Diagnostic limits

This is automated headless evidence, not manual visual play, a full campaign, or
balance certification. Test saves live under ignored `reports/native-state/`;
ordinary player saves are untouched. The native gate does not export a browser
build. Inspect the actual publication commit's CI status separately.

The Windows sandbox reports a root-certificate-store read error without making
network requests; trust/TLS settings were unchanged. GUT fonts fall back from
stale UIDs to existing paths. Invalid-slot save tests deliberately emit errors
and assert the return. Float/Int comparison warnings and teardown orphan counts
remain in raw evidence. This is not a zero-diagnostic claim.

Audio directories contain placeholders; AudioManager intentionally tolerates
missing tracks. Custom reputation keys `guild`, `crew_trust`, `lattice_affinity`
have no implemented state mapping. Existing location, balance and UI TODO queues
remain visible. The Linux CI asset SHA256 is
`cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4`.
