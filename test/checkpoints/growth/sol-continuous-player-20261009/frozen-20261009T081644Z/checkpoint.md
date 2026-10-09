# Frozen cloud QA checkpoint

This run was retired at the user's direction. It is evidence only and is excluded from normal pacing / experience acceptance. No new save or further gameplay was started in this thread. Previous snapshots are preserved.

- GUI pause: **2026-10-09 08:16:44 UTC**, main stage **68**, wave 4/9. Manual Save confirmation: **08:17:33 UTC**. Game process terminated after saving.
- Runtime commit: `4704bfa4fbc4e136959d4158907fa3079a49d7bc`; tree: `732386aa0fd60a658d32f4d931302a31f1350a99`.
- Frozen save SHA-256: `377bc5a6c48850944cf7fd4894d515d47a446157eafa57007d5473514cbdefaa`; 108806 bytes.
- Ship: 白鲸 / `Heavy_Battleship`. Reactor 215; enhancement 54; AI 402.
- Native resources: `{"1": 2.1363463116634242e+46, "2": 2.297265655702612e+32}`. Production elapsed counter: 15400.650000 seconds.
- Game speed **x1**; particles **144**, no particles spent. Normal version restart login grants were 47 + 97; the prior saved balances were 0, 47, then 144.
- Weapons: `[{"key":"missile","level":577},{"key":"longLaser","level":576},{"key":"missile","level":576},{"key":"cannon","level":576},{"key":"longLaser","level":575},{"key":"cannon","level":575},{"key":"missile","level":575},{"key":"longLaser","level":575}]`. Defences: `[{"key":"armour","level":574},{"key":"armour","level":574},{"key":"shield","level":574},{"key":"shield","level":574}]`.
- Crew: equipment Lv44; AI Lv40; enhancement Lv42; planet trainee Lv48; route crew Lv35 currently released; reactor Lv0; three Lv0 galaxy builders and one planet shipyard builder. Occupancy links for planet/hyperspace are stored separately in the save.
- Planet 1 exploration 108; station, refinery and workshop built; shipyard 77/180. No colonization / rebirth completed. Latest Δ3 clear completed before the freeze; no challenge was initiated after pause.

## Provenance and limits

The first real new-save GUI image is 2026-10-09 03:52:26 UTC: stage 1, iron 0, uranium 0, initial ship and Lv1 equipment. A separate empty XDG directory was prepared before launch. No other player's or old QA save was copied; no resource injection, unlock injection, skip-stage action or save editing was used. Normal mouse-input helpers and in-game cost-paying crew automation were used.

This own save crossed authorized runtime versions `9371573d` → `91839814` at 05:03 → `4704bfa4` at 06:26. Startup loads saved progress and rebuilds attributes using the current candidate. **It is not a single-version fresh 4704 pacing run.**

Visually confirmed stage images: 10 at 05:14:16, 30 at 05:59:57, 60 at 06:33:18, 68 at 07:47:40 UTC. These are image timestamps, not exact clear times. Normal training evidence: equipment crew started Lv0 at main65 / exploration67, 07:25:17; observed Lv44 at exploration84, 07:42:46 (about17 rounds of60s). Displayed experience per round rose from71.1K to111K and133K; the first-round level jump was not individually captured. The final Lv48 trainee continued normal planet training from exploration84 to108 before the freeze.

Current process arguments were `godot --path space-battleship --rendering-method gl_compatibility --display-driver x11 --log-file <private-log>`; no capture or QA flag was present. Three used candidates have default speed1. Full initial JSON, continuous video and initial complete command-line archive were not preserved; original startup tool history is needed for the latter. Original screenshots, detailed input logs and private audit notes remain private and are excluded from this backup. No gameplay advice or evaluation is added here.
