# Display bounds, runtime mounts and timing closeout

Baseline: `51a7e1b9bc5784927e7d5b232a112194d990a41c`. Unfixed candidate: `9cbd3d86453e25db9f73609c704d5ae6f57b00de`. The existing native DLL was reused, SHA-256 `B89310037FB78690470FFE8D47E37C264B15FF9B1828BA345A6F323D159068DA`.

## Bounds finding

`simulation_geometry_authority.prepare` intentionally captures the approved display PNG's normalized opaque rectangle as descriptor `bounds`, while `profile` and `identity` use the main51 geometry PNG. `captured_bounds` is written and cleared only. No production call site invokes the authority's `enemy_hull_bounds` or `visual_region` accessors. They do not enter the active battle path.

The actual consumers of display bounds are `battlefield.enemy_status_layout` and `retained_enemy_contacts.compile_record/update_meters`: sprite corners, meter position and meter width. The latter calls the battlefield owner's `enemy_hull_bounds`, not the authority accessor. Weapon icon `Main.visual_region` also belongs to rendering. These values do not feed layout, collision or muzzle publication.

The battle path is `native_execution_session.prepare_geometry` -> `battle_read_model.ballistic_shape` -> `simulation_geometry_authority.enemy_recognition_geometry` -> `geometry_from_descriptor`. It uses descriptor `profile`, unchanged weapon descriptors and numeric layout. Hostile muzzles come from `execution_enemy_port_offset` -> `_source_enemy_component_pose`. Those functions use the runtime hardpoints, width, rotation and aim, with no descriptor `bounds`. Fixed layout uses `enemy_fixed_layout` and the original model/config dimensions. Therefore changing cached bounds would not fix the timing defect and was unnecessary.

## Actual defect and minimal fix

`Main._ready` rebases each enemy hardpoint using the opaque image center before the authority captures the config. The JSON hardpoints had remained equal to main51, but the runtime rebase still used the approved display PNG. The earlier source/profile/hardpoint check never instantiated Main and missed this mutation.

For scout slot 0, main51's runtime hardpoint was `(0.0372040569782257, -0.0378804963082075)`; the unfixed candidate produced `(-0.0011273956624791, -0.0519729426130652)`. In the retained startup probe this shifted the muzzle offset from `(-2.320048, 10.16748)` to `(-0.273188, 11.76417)`, although width, rotation, player anchor and ballistic hull matched. The hostile projectile travel time consequently changed.

The production diff is four added lines and one replaced line in `scripts/main.gd`: keep `row.origin_offset` computed from display art for sprite centering, and subtract an independently computed `geometry_offset` from battle hardpoints using `ship_geometry_texture`. No geometry algorithm, damage, timer, equipment value, technology tree or DLL changed. Approved textures and the 0.45 turret body scale remain.

## Necessary verification

`verify_geometry_source.gd` now instantiates the actual Main scene without saving and compares its **runtime rebased** enemy hardpoints with main51's image-center calculation. All eight archetypes pass, including their actual rebased muzzle algebra and nine width/shape envelope comparisons apiece. All five player source PNGs remain byte-identical to main51. The display-origin assertion separately confirms that sprite centering still uses the new PNG. Raw output: [runtime-source-check.log](evidence/geometry-timing/runtime-source-check.log).

The existing laser high-load fixture was reused with the same DLL in headless mode. The saved [probe](geometry_input_probe.gd) advances the actual native battle slice at exactly 1/60 second for 720 steps; it does not draw windows or measure performance. It records 721 boundary snapshots, 15 actors per snapshot, actual `equipment_stats` callbacks, event counts and the final native export. No five-case replay was repeated.

- Main51 versus unfixed: native muzzles differ at boundary 0; incoming counters first differ at boundary 72. The startup descriptors expose the image-center mutation above.
- Main51 versus fixed: every recorded player position/reference height, native aim, native muzzle, enemy position/width/angle, ballistic hull/center and enemy port offset matches at every boundary.
- At sample logical steps 240–719, **actual callbacks**, including payload, logical step and both counters, match exactly: 242 `equipment_stats` = 192 defence + 50 weapon notices. The old candidate had 160 defence + 50 weapon notices. The 32 one-step counter shifts are eliminated in this fixture.
- All 720-step event dictionaries match, and final player, enemies, resources, loadout, clocks, counters and transferred RNG state match. Native exports match except the engine-created RNG's historical random `seed` property; its transferred `state` is equal. That exception is recorded explicitly in the audit. The flight exports themselves match exactly.

Compressed original traces, actual event payloads, logs and hashes are under [evidence/geometry-timing](evidence/geometry-timing/audit.json). [Offline analyzer](analyze_geometry_timing.py) asserts these comparisons. [Runner](trace_geometry_inputs.py) documents reproduction using prepared isolated checkouts and existing probe tools. Early setup attempts hit missing imported-resource registration and a headless VSync assertion; the accepted logs end `GEOMETRY_PROBE_DONE 721` with no script errors. The OS certificate-store warning is unrelated to the local simulation.

## Acceptance boundary

The parent has accepted the 5 player and 8 enemy visuals. The bounds doubt is closed, and the specific timing regression has a reproduced cause and a verified fix. The other four weapon fixtures retain their prior **unfixed-candidate** aggregate/performance evidence; they were not rerun and do not establish post-fix universal battle parity or performance. This is the remaining validation limit, not a known remaining defect. Main is not merged.
