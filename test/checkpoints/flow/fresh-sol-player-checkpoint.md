# Fresh Sol player growth checkpoint

- Played build: `4704bfa4fbc4e136959d4158907fa3079a49d7bc` (tree `732386aa0fd60a658d32f4d931302a31f1350a99`).
- QA-only game save: `fresh-sol-player-progress.json`, manually saved 2026-10-09 07:05:39 UTC, SHA-256 `01a055802fbf5c37dfc53299c40f696a850068f6ea09fcf80c0b672fc25b5093`.
- This is the isolated fresh cloud playtest save. It contains game state only. No resource injection, unlock injection, ideal affix generation or imported older QA save was used.
- Main progression: stages 1–19 cleared; stage 20 in progress, group index 3. Entering stage 20 has not unlocked its ship or second crew member.
- Current ship UI: 飞燕护卫舰; weapons cannon 95, continuous beam 100, homing missile 97, pulse laser 91; composite armour 122, shield 74.
- Reactor 64; allocated weapons 7,440,762 / defence 9,808,662, other outputs zero. Enhancement 5, active weapon 熟练 and defence 记忆材料.
- AI 68, distributed 17 to each of four research stations.
- Equipped drones: gold beam level 3 with energy canister; legendary pulse level 3 闪避反击. Original white beam level 3, four mount capacity, retained as a future legendary conversion target.
- Normal resources at save: iron 1,178,759,989,862; uranium 19,932,442,891. Hyperspace materials: degenerate matter 60, glueball 0, antiproton 140, zero-point energy 960.
- Experience multiplier: 1× throughout. Offline particles 217, all unspent: 130 and 87 from downtime for two build updates. Continuous crew exploration currently Δ4, best clear 51.68 seconds. White quality auto-salvage enabled.

## Normal player steps

1. Continue the existing stage 20 fight and Δ4 crew exploration. First stage-20 defeat indicated predominantly physical loss. Use its defeat comparison entry to view the fixed armour upgrade.
2. Normal armour investment increased armour 112→122 for 957B iron. Enhancement 4→5 cost 1,600 fragments; preview showed regeneration 20%→25% per second.
3. Other weapon slots were raised in quoted ×10 batches from 45/50/41 to 95/100/91. The original missile stayed 97. This made catching up the mixed weapon loadout affordable and useful. The stage-19 clear coincided with these upgrades and ongoing automatic growth, so it is not attributed exclusively to those upgrades.
4. Reach 1,000 zero-point energy normally, then inspect conversion of the retained white beam. The previously saved 棱镜塔 collection choice is visible and selected in the conversion target dropdown. Conversion and its equipped result remain unverified.
5. Complete stage 20 before assessing its new ship and crew workflows; neither has been played yet.

## Unresolved observations

- On the natural save transition into this build, defence allocation was reduced despite the prior save retaining the original allocation. Subsequent capacity growth also creates unallocated energy that requires a reactor visit. The displayed current allocations are a player correction, not proof that save restoration is fixed.
- Individual weapon contribution remains difficult to read. Cheap catch-up investment gives other slots meaningful displayed power; earlier claims that only one slot is valuable are too broad.
- Drone legendary collection lists names without ability details. The selected target workflow has been reached, but conversion and combat benefit still await normal materials.
- Actual cloud GUI rendering uses Mesa llvmpipe software rendering. Main-stage multi-enemy scenes have displayed roughly 15–23 FPS; this is a player-experience limitation in this environment, not a hardware benchmark pass.
- This build still inherits drone weapon level from the highest ship weapon slot. It does not contain the later requested minimum-slot inheritance change.
