# Fixed centre contact

Base main aa3d6b05. User requested both fleets use ship-centre contact, independent of changing hull art; this supersedes the unmerged front-edge contact direction.

- Player contact/display/aim share the ship centre; no nose offset.
- Enemy straight-shot contact uses a constant +/-0.5 presentation-unit numerical tolerance around centre, never the texture polygon. Missile numerical tolerances remain unchanged and centre-based. Moving-target/straight-ray semantics retained.
- Both GDScript and native execution consume the same centre descriptor. No C++/DLL changes or rebuild.
- Reserve display margin by moving the full player assembly, not only its PNG; correct fractional PNG centre rounding in both visual and logical mount descriptors.
- No damage, rate, speed, save or upgrade-table edits. New fleet art not included.

Validation on existing Linux cloud desktop, Godot 4.7.2, reused matching-source Linux native library: outgoing four weapon types x five hulls, native 320 checks / 0 failures; GDScript 230 / 0. Incoming four weapon types x five hulls x both execution paths: 55 / 0, each case observed all four enemy weapons. Centre-invariance unit: 8 / 0. Raw results and scripts adjacent. These are constructed functional cases, not a complete game playtest or Windows release acceptance. No new performance benchmark. Audio unavailable.

Development checks initially caught obsolete fixture references (old enemy asset key and non-compact pulse event schema) and a half-source-pixel centre rounding error; corrected before the final recorded runs. Production native ownership unchanged.

Run scripts with project path space-battleship and --script pointing to the chosen adjacent .gd file. GUI runs require an existing desktop. Unit can run headless.
