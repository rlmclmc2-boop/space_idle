# Railgun main-cannon review

Original candidate `art/railgun-main-cannon` — `a96190c5e3deac454c77bb8d6ddc317b12179174`, based on main `8b631374a4c8f217af0ce3c68bd1a233ad289b6c`. Not merged to main.

## Latest revision: broader cannon body

Candidate `art/railgun-main-cannon` is now `408d0b26bd39f54fd64710baa850e9c5287ef533` (append to original `a96190c`). Not merged to main. Main was fetched before delivery and remains `8b63137`. Overview gate repair is on its separate UI branch and is not included here.

- [Revised cannon and cyan lasers](revision2/cannon-and-lasers.png), [late charge](revision2/charge.png), [local impact](revision2/impact.png).
- [Revised 8.3-second recording](revision2/revised.mp4). Compare the original thinner warm cannon in [after.mp4](after.mp4) and [native screenshot](after/railgun-and-laser-flight.png).
- [Actual table test log](revision2/candidate.log): 27 checks, 0 failures. Cannon launches still at 3.5167/7.0333 s; 32 laser launches and 2 cannon impacts in 8.3 simulated seconds. ALSA is unavailable in this environment and the engine falls back to Dummy; no GDScript errors occurred.
- [Edited-table test log](revision2/variant.log): 27 checks, 0 failures with CD 4.25 and charge 1.3, authored/exported only in an isolated project via the [official importer](revision2/variant-import.log). Recorded cannon launches 4.2667/8.5333 s. Source workbooks retain the authorized 3.5/0.9 timing. Tests infer editable values and capture duration; fixed formula checks use explicit in-memory timing fixtures.
- [Preservation audit](revision2/parameter-audit.json): equipment.xlsx is byte-identical to original candidate a96190c; weapon_motion changes only charge radius 20→28, trail width 10→28 and impact radius 24→32. Every other workbook ZIP part is unchanged. The JSON projection differs only in those same three visual settings; equipment/growth, CD 3.5, charge 0.9, damage 350, speed 40, multiplier 1, trail length 138, flash 0.09 and impact lifetime 0.16 remain identical.

The cannon has a broad faceted front and tapered short tail, with a more readable contracting charge ring. Its body width is now 28 versus laser core width 9 (glow width 12); the captured native screen shows a clear size/color distinction. Muzzle flash reach was bounded as width increased. No longer-lived effect, full-screen flash or render viewport was added. Images remain native 1372×883; video pads one blank bottom pixel. Replay uses 0.1 game-second frames at 10 fps, not a Windows performance benchmark. The source diff is limited to the motion workbook/projection, rail_vfx.gd and its narrow test. No broad suites were repeated for this visual-only follow-up.

## Original review

- [Before: cannon and lasers](before/railgun-and-laser-flight.png)
- [After: charging](after/railgun-charge.png)
- [After: cannon and lasers](after/railgun-and-laser-flight.png)
- [After: local impact](after/railgun-impact.png)
- [Before recording](before.mp4), [after recording](after.mp4)

Images are native 1372×883 complete game captures; video adds one blank bottom pixel for encoding. Videos contain 82 captured frames at 10 fps, each after 0.1 simulated seconds. They demonstrate deterministic X1 visual timing, not real-time Windows performance. Linux llvmpipe FPS shown in the HUD is not a performance comparison. Both use a synthetic Frigate with one level-1 cannon and two level-1 lasers, no private saves. The target has deliberately high HP; critical/repeat chance is disabled only in this scene fixture.

Before uses the latest user's Excel tables exported through the official importer: cannon CD 2, damage 350, speed para1 40, multiplier 1. Main's checked-in JSON was older than those tables. After changes CD to 3.5; the final 0.9 game-seconds of that period charge at the muzzle. Legal cooldown multipliers scale that window. No charge delay is added to the canonical launch. Warm, capped 138 px trails, 0.09 s muzzle flashes and 0.16 s local impacts replace the sustained cyan path. Lasers keep their existing cyan packets. No damage compensation, growth changes, hit logic, combat RNG, new render viewport or gameplay is added.

## Validation

- [Scene/timing](after/candidate.log): 24 checks, 0 failures, no script errors. Base launches 3.5167 / 7.0333 s, 30 laser launches and 2 cannon impacts in 8.2 game seconds. Legal proficiency interval multiplier 0.7 gives configured CD 2.45; subsequent observed gaps 2.4667 s. Existing discrete tick quantization accounts for the difference. Late log totals include the separate legal-modifier test after capture.
- [Baseline](before/baseline.log): 8 checks, 0 failures; launch gaps about 2.0167 s.
- [Shared enhancement attacks](enhancement-branches.log): 40 checks, 0 failures, including repeats, critical charge and chains.
- [Configuration](config-validation.log): 19 passing cases, including eight modified rail controls through the official Excel exporter; invalid imports preserve the projection. [Details](config-validation-results.json).
- [Workbook preservation](config-preservation.json): only existing cell equipment G8 changes 2→3.5; weapon_motion appends eight rows. All other workbook ZIP parts are byte-identical to main. The user's existing damage, volley, speed and ejection updates remain intact. [Parameter handoff](parameters.json).

Early development runs caught a GDScript type-inference error and fixture-only missing empty-slot/high-HP issues; those were fixed before the final clean run. No Windows performance or whole-game test matrix was run. Accelerated visual guards are unchanged; Windows/high-speed visual acceptance remains unmeasured.

Library upload failed due to network availability; no Library file IDs were issued. This independent evidence branch contains only synthetic game captures, recordings and review logs/data. Candidate source remains on the art branch. When integrating alongside balancing changes, merge the intended Excel cells/added rows and re-export JSON; do not replace the balance thread's entire workbooks with this snapshot.
