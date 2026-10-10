# Battle architecture discriminator (draft)

The existing `whole_game_perf.py` default is unchanged. It remains a mixed
background-business fixture. `--battle-only` modifies only the isolated copy's
`Game.tick`: it retains existing static profile/ship modifiers and combat
updates, but omits the noncombat update block. `BATTLE_SCOPE` records the exact
omissions, starting ship/weapon parameters, inventory and quality settings.
Hidden tab pages remain instantiated but their process/physics callbacks are
explicitly disabled. The runtime manifest reports callbacks disabled and those
still enabled; visible enemy hover inspection remains part of the original UI.

`--dynamic-replay` requires `--battle-only` and records the final native visual
state into RAM. The original CanvasItem tree, native draw commands/order,
Controls, original 3D meshes/materials/shadows and live subviewport remain.
Recording, property discovery, resource discovery, readback and validation
are outside replay timers. The timed replay applies property/uniform deltas
and redraws only command owners changed in that source frame. No game-state
copy, frozen composite, or alternative renderer is used.

Initialization UI may rebuild. Retired owners before sampling are removed;
changes to the sampled hierarchy or an unrecorded visible owner reject replay.
The settled battle/HUD tree includes native internal controls and temporarily
hidden dynamic items. Disabled noncombat tab subtrees are not recorded.

Original draw-signal painters are replaced by the recorded command stream;
script `_draw` guards replay the same stream. Native redraw frequency, owner
identity and order remain. A full preload/warm replay, a separate property/
command/image verification pass, and a contiguous timed replay are distinct.
The initial full snapshot is reduced to cyclic last-to-first deltas outside
timing; this avoids charging tape rewind/setup as steady gameplay work.

The harness rejects absent/aborted/non-equivalent R0. Representative images
allow at most eight nonexact pixels, each at most one 8-bit channel level;
actual errors and exact/nonexact status are reported. No geometric, material
or dynamic-content omission is accepted. Recording frame times are not clean
throughput. A and R0 both end each frame at native `frame_post_draw`.


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
