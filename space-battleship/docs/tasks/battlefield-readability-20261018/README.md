# Battlefield readability candidate

Base: `main@d2f5db1a`. Scope: battlefield presentation and enemy art only.
The right workspace, encounter duration, enemy values, damage rules, and
automatic fighting behavior are unchanged.

The frozen three-way playtest report identified three related issues at the
native 1373 × 883 window: repeated small enemy hulls, thin health/shield bars,
and reward marks mixing with projectile marks. Its stage 2 and stage 6 frames
were inspected before this edit.

Changes:

- Bind the existing eight second-pass top-down enemy hulls to their eight
  archetypes. Warm texture modulation separates hostile plating from the
  player's white/cyan hull without changing visual, collision, or mount size.
- Increase enemy health and shield bars from 4 to 6 logical pixels and keep
  them above the visible hull/protection outline. A brief border on the
  affected meter uses the actual hit event, letting a player see whether a
  hit reached a shield or the hull. Physical attacks use warm and energy
  attacks cyan accents.
- Draw physical enemy rounds as compact amber bolts and energy rounds as
  narrow cyan streaks. Add a static square outline to resource drops so
  rewards do not read as traveling shots.

The hull draw count remains one texture per enemy. The drop frame adds one
rectangle per visible drop. The hit cue adds one rectangle only during its
0.18-second event window. Script projectile cores retain the same two or
three drawing operations as before. No battlefield root redraw request was
added.

`capture_live.gd` samples stage 2 point 3 at frames 20, 60,
and 100. It does not change battle damage, enemy health, frame delta, timing,
or pause state. Use the same script and seed on base and candidate for
before/after evidence.

The raw headless runs are in `evidence/before-headless.log` and
`evidence/after-headless.log`. Both ran at speed 1.0 and had 11 enemies at
each sample. The base resolved all 11 as `enemy_opening_triangle_energy`;
the candidate resolved 10 as `enemy_opening_swarm` and one as
`enemy_opening_interceptor`. Headless uses Godot's dummy renderer, so it
cannot supply pixels or draw-call counts. Both logged `native=false`; a
matching native DLL must be tested separately.

## Encounter key audit

The current `data/game_data.json` uses these eight archetypes. All entries
within each archetype have the armour type expected by the identity resolver:

| Archetype | Texture key | Armour type |
| --- | --- | --- |
| scout | `enemy_opening_scout` | 2 |
| sentry | `enemy_opening_sentry` | 2 |
| interceptor | `enemy_opening_interceptor` | 1 |
| swarm | `enemy_opening_swarm` | 1 |
| anchor | `enemy_opening_anchor` | 1 |
| reactive | `enemy_opening_reactive` | 1 |
| shielded | `enemy_opening_shielded` | 1 |
| command | `enemy_opening_command` | 1 |
