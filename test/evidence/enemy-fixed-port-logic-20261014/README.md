# Fixed ordinary enemy logical outlets

Continuation of candidate 85c76e79 / evidence cd127056; not merged to main. User explicitly authorized removal of ordinary enemy turret rotation on both display and logical paths, including changed birth points/trajectories. Boss/leader and player design remain unchanged.

`enemy_fixed_ports.gd` is the shared pure geometry rule: center = authored hardpoint (x, 2y) × hull width, transformed only by hull orientation. The logical outlet equals that visible center. Native `simulation_geometry_authority` owns live/frozen publication; after explicit handoff Main uses the same rule. Renderers consume the shared center/descriptor. No old aimed barrel outlet is computed first.

Exited for ordinary enemies: MountRecord/build_weapon and per-turret Canvas transforms (previous candidate); now enemy_weapon_angle, desired angle/wrap/clamp/rotation-limit work, rotating profile muzzle vector, aim-anchor display-row invalidation and aim-only hostile muzzle refresh. Both retained and direct painters use static disks, including missile and continuous-beam mounts. Existing geometry/topology/body invalidation still handles entry, movement, size, scale, equipment, source identity and ownership transfer. Dead records preserve their fixed-port mode during scale refresh. Bosses retain the old branches.

Native firing still consumes the geometry input muzzle; the C++ kernel remains the only native combat executor. No C++ change or rebuild. Direct pulses/cannon retain their initial direction and original hit predicate. Enemy missiles retain their table speed and tracking. Continuous beams retain lock/charge/tick/termination, updating the fixed source center and necessary target direction. The kernel's damage, cooldown, target selection and collision code is unchanged. Born positions and travel time may change as authorized; this is not old-trajectory equivalence.

Legacy births now receive the known weapon slot explicitly: different weapon types can share an old logical offset, so inferring a slot from that position was ambiguous. The presented game asks the active geometry provider for the fixed center; its birth flag survives native handoff and wave residuals. It keeps target coordinates consistent with the drawn player and avoids applying the old display offset a second time. The existing Game execution path after handoff is reused, not duplicated.

Validation, accepted DLL SHA256 45c507c31570d021e9f04f4056c35a92f201f4f028e392b6a65aef2befdf1f1e, Godot 4.7.2, isolated test/work/fixed-port-user directories:
- Existing graphical retained-native test: final **178 checks, 0 failures, exit 0**. Native four-type birth centers, unchanged ordinary outlets under changed aim, no ordinary enemy_weapon_angle calls, direct/retained matching, real handoff/beam origin, size/scale/identity/death/reset and Boss original aim path.
- Existing native handoff test: **45 checks, 0 failures, exit 0**. Includes committed hostile carrier after last-enemy death, pending missiles and continuous beams.
- First targeted run retained: 8 failures (six exposed legacy slot ambiguity, two audit-fixture poses had not entered residence). Second run 163/0 after fixes; final run adds aim-cache and actual transferred-beam assertions. Logs retained. Final screenshots inspected.

No performance run. Prior capped post-draw A/B cannot determine busy-frame savings; see timing-audit.md. Neither the main cost nor >=0.5 ms savings has been established.
