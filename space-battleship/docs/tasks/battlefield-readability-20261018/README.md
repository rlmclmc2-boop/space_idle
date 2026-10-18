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

`capture_live.gd` samples stage 2 point 3 at frames 20, 60,
and 100. It does not change battle damage, enemy health, frame delta, timing,
or pause state. Use the same script and seed on base and candidate for
before/after evidence.

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
