# Stage 3 safe partial candidate

Base: b2d91c21c1ecfdbd056049edbeb654292abc9434.

## Implemented

- Extracted 26 identical Main/authority geometry bodies into `scripts/geometry_rules.gd`, preserving existing signatures through thin adapters. Each call supplies the original context; state and dynamic dispatch remain with that context. The component cache still belongs to its caller.
- Removed the unused authority `beam_style` copy. Main and its presentation consumers retain the existing implementation.
- Every original duplicate has a direct-consumer row and explicit numerical-context dependency row in [CONSUMERS](CONSUMERS.md).
- Astra high static review, relayed by parent: 26/26 normalized bodies match both originals; differences are host qualification, local inference spelling and whitespace. No other function body changed. Parent dot review remains pending; this is not a completed dual review.

## Verification

Engine: D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64.exe. All runs used `test/run.py` isolated project/user directories.

| Existing entry | Result | Evidence |
|---|---|---|
| test_battle_coordinate_inverse.gd --headless | 10,015 checks, 0 failures; import had no parse errors | coordinate.txt |
| test_player_mount_seating.gd --headless | 90 samples, 0 failures; maximum error 0.00033880010596 | seating.txt |
| test_weapon_fx.gd | Blocked by obsolete fixture before attack: line 23 reads removed game.profile.loadout. Run stopped; assertions unchanged | weapon-fx-blocked.txt |
| git diff --check | Passed | command output |

The certificate-store diagnostic is environmental and also appeared in successful runs. No player save, asset/config table, native binary or original checkout was changed. The seating check covers imported placement, not complete simulation ownership. Full weapon/drone/switch acceptance is not claimed.

## Pending behavior choice and unimplemented closure

No persistent-authority integration has been applied. All following old paths remain:

- Battlefield `create_battle_game` still installs scene target/launch/drone/rail providers.
- Legacy `before_logical_game_tick` still queries/updates ship_view and hyperspace_visual.
- battle_slice_runtime install still captures a new authority and rebinds providers; close still restores providers and transfers poses to the scene.
- Slice/native compact-fire and presentation event callbacks still update numerical turret state.
- Initial descriptors are still captured during native admission rather than once before the first formal logical step.

The correct future install point is after battlefield `_ready` finishes initial ship_view pose (baseline line 175), not `create_battle_game`. Preparation must preserve orbit_elapsed, elapsed, module/carrier/drone transforms as well as asset descriptors.

Material existing difference requiring user selection: battlefield `_set_reference_dimensions` baseline 309-317 honors authored static_height; authority.prepare baseline 590-614 compiles older PNG/formation heights for future sync_hull. First capture uses the scene height, but later native hull changes use prepared_hulls. Consolidating this changes one old path unless a behavior baseline is selected. Parent has asked the user; no answer is assumed.

Anchor distinction: ordinary legacy hull changes reset stable_center_ready and snap, so they must not be described as universally lerped. Same-hull anchor-input changes can use the display-frame lerp while authority only writes player_anchor during prepare/sync_hull. Formal reachable actions must be measured before choosing behavior; no speculative compatibility callback was added.

Two syntactic chain differences were examined, not changed: authority excludes chain_hop beams and does not repeat Main's chain_hop recoil exclusion. Current game.launch_enhancement_chain constructs a non-beam, mountless carrier and emits enhancement_chain, not fire/beam_started; beam chains apply link damage directly. Therefore these differences were not shown reachable through current public production construction.

Existing explicit-formation risk reported by architecture audit: entry-distance calculation can call explicit_formation_geometry.parts -> enemy_status_layout, absent on authority. This predates the extraction and remains a future lifecycle-integration verification item.

## Existing tests disposition

- Retain coordinate inverse and player mount seating; both ran unchanged.
- weapon_fx needs separate fixture migration to the current equipment owner; no gameplay assertion changed here.
- native_geometry_scale is not an accepted current switching test: its contract reads removed battle_slice_runtime.remainder. Do not repair merely to obtain a green result.
- enemy_runtime_art and enemy_base_eight_battle still construct profile.loadout rather than current equipment-owned state; not run as proof of this candidate.
- No test project or new regression suite was added. Complete weapon/drone/legacy-native switching coverage remains required when persistent ownership is implemented.

