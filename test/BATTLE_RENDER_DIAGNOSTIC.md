# Battle architecture discriminator (draft)

The existing `whole_game_perf.py` default is unchanged. It remains a mixed
background-business fixture. `--battle-only` modifies only the isolated copy's
`Game.tick`: it retains existing static profile/ship modifiers and combat
updates, but omits the noncombat update block. `BATTLE_SCOPE` records the exact
omissions, starting ship/weapon parameters, inventory and quality settings.
Hidden UI is still instantiated; its autonomous processing requires a separate
runtime inventory before calling the whole entry fully isolated.

`--dynamic-replay` requires `--battle-only` and records the final native visual
state into RAM. The original CanvasItem tree, native draw commands/order,
Controls, original 3D meshes/materials/shadows and live subviewport remain.
Recording, property discovery, resource discovery, readback and validation
are outside replay timers. The timed replay applies property/uniform deltas
and redraws only command owners changed in that source frame. No game-state
copy, frozen composite, or alternative renderer is used.

The replay is deliberately unaccepted until property, command, counts and
representative image comparisons pass. The initial 30-frame proof reached
recording but stopped at replay setup because a command owner from initialization
had already been freed. Recorded commands must be limited to the settled live
tree; disappearing/new owners during the sample also require explicit handling
or rejection. Do not use recording frame times, aborted replay times, or a
substituted static image as a performance floor.

Both modes use the same explicit exhaust animation clock in the private copy,
preserving its formula, to permit source/replay phase comparison. Production
shader and production gameplay source remain unchanged.

The synthetic fixture holds authored-wave health and uses fixed 1/60 simulation
steps per submitted display frame. This measures fixed-workload throughput;
it is not natural 1x gameplay at 120/144/240 FPS. R1 and production restructuring
remain outside this draft's scope.

Minimal proof command (isolated data; default graphical quality):

```powershell
python test/whole_game_perf.py --label r0-proof --ref 447be5dc --godot <Godot4.7.2> --rich --missile-loadout --authored-stage 20 --organic-economy --stress-enemies 15 --pages 0 --frames 30 --warmup-frames 30 --battle-only --dynamic-replay
```

Private evidence stays under ignored `test/work`; no reports, images or saves
should be uploaded with this harness.
