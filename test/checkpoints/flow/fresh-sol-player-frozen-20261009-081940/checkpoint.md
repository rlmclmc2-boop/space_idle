# Frozen flow QA checkpoint

- Played version: `4704bfa4fbc4e136959d4158907fa3079a49d7bc`; tree `732386aa0fd60a658d32f4d931302a31f1350a99`.
- Manual save: 2026-10-09 08:19:40 UTC. Game process paused at 08:19:41 UTC. This checkpoint is frozen; no further play is recorded here.
- Save SHA-256: `b30fddd5d621af0f5dace0a94bfffb4b585416faf2f4681acd7f7e725d0a4bc9`.
- Isolated cloud QA save only. Existing earlier checkpoints are retained. No personal player save, credentials, conversation, raw screenshots or internal notes are included.
- Main state: stages 1–38 cleared; stage 39, Boss group 9/9 in progress. Ship: 玄甲战列舰.
- Weapons: cannon 320 / continuous beam 321 / homing missile 318 / pulse laser 317 / continuous beam 316 / cannon 321.
- Defence: composite armour 317 / shield 315 / composite armour 318. Reactor 125; enhancement 27; AI 205.
- Equipped drones: gold beam level 3, legendary pulse level 3 闪避反击, legendary beam level 3 棱镜塔. Fourth drone slot remains unused.
- Normal saved resources: iron `9.757891069198487e27`, uranium `4.172212153512395e18`. Resources came from normal combat, production, reactor allocations and crew automation. No injected resources, unlocks or ideal affixes were used.
- Multiplier remained 1×. Offline particles 217 remain unspent, obtained as 130 and 87 during two version-update interruptions.
- Planet save state: 始源星 exploration degree 5, space station built/enabled, automatic exploration assigned to 朱姐. Crew experience is retained in the save. Higher planet facilities remain unverified.

## Recorded operations

Normal GUI play continued on the same fresh QA save. Stages 20 and 30 were cleared and their new ships enabled; free new weapon/defence slots were configured. Crew equipment/AI/fragment automation was assigned through the UI. Normal reactor MAX and equipment upgrades consumed displayed resources. Two manual planet explorations built the space station, which was enabled before automatic exploration. At the final checkpoint, the manual-save control was clicked and the game process was paused immediately afterward.

## Unresolved observations in this played version

- Natural save restoration previously reduced the player's defence allocation. The later correction build was not played in this checkpoint.
- Assigning reactor automation changed the previously manual weapon/defence split into four equal outputs; the automation description did not first explain this allocation policy.
- A selected 棱镜塔 legendary conversion displayed a 1K price while the material-exchange flow requested an additional 2K when 1K was held. The selected conversion was not executed.
- Cloud software-rendered GUI scenes displayed low FPS, including approximately 14–28 during the final active interval. This is not a hardware performance certification.
