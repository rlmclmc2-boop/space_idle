# Sol continuous player checkpoint

Pure cloud QA save, captured by the game's manual Save button at 2026-10-09 07:12:45 UTC. Independent fresh normal save; no injected resources, unlocks or selected affixes. This backup preserves the running candidate; it does not adopt newer branch code.

- Runtime commit: `4704bfa4fbc4e136959d4158907fa3079a49d7bc`; tree: `732386aa0fd60a658d32f4d931302a31f1350a99`.
- Save SHA-256: `c1e18a473de512a110c29779f7f86a0205804cbc7a330c04b08efa11fe22c16b`. Main stage: 64; rebirth count: 0; ship: 白鲸 / `Heavy_Battleship` (8 weapons, 4 defences, 5 drones).
- Normal 1x online pace. Unspent offline particles: 144 (47 + 97 from normal version restarts); no particle acceleration used.
- Saved resources (native IDs): `{"1": 5.146987068073943e+44, "2": 1.5649407954786083e+31}`. Reactor 215; enhancement purchases 51; AI 390.
- Weapons: `[{"key":"missile","level":564},{"key":"longLaser","level":564},{"key":"missile","level":564},{"key":"cannon","level":564},{"key":"longLaser","level":564},{"key":"cannon","level":564},{"key":"missile","level":563},{"key":"longLaser","level":559}]`. Defences: `[{"key":"armour","level":556},{"key":"armour","level":555},{"key":"shield","level":555},{"key":"shield","level":555}]`.
- Drones: gold beam Lv1 with resource collector; gold rail Lv1 with distributed compute; gold rail Lv3 (chain chance 3.1%, shield capacity 56.7%); legendary rail Lv2 奇异物质; legendary missile Lv1 黑洞. Legendary quota 2/2.
- Planet 1 exploration 55; station/refinery built, workshop 5/10, shipyard 24/180. No colonization/rebirth completed.

## Reached through normal play

Started at zero resources, played equipment/ship unlocks, normal upgrades, crew automation and planet crew training. Reached eight weapon slots and five drone slots. Normal hyperspace clears: Δ1–2, Γ1–3, B1. Latest first clears Γ3 56.60 s and B1 63.30 s; native drops equipped through the player UI. B1 background assigned earned Lv35 crew (UI period 23.02 s); Lv40 crew assigned AI; another crew training on planet; three crews building galaxy and one building planet shipyard. Future-drop filter dismantles white drones and retains other qualities.

## Unresolved observations / continuation

- Reactor Lv215: upgrade price 38.9OcU versus visible 6.99NoU balance; x1/MAX remain disabled, MAX estimate 0, actual click did not upgrade. Other progression continues.
- Lv35 reactor crew displays +1050%, while actual total income changed 8.81Qi to 9.22Qi (about 4.7%). Stacking semantics are not explained; this observation does not establish incorrect arithmetic.
- Legendary rail 希格斯加农炮 rejected with generic rail restriction text when replacing slot 3, and later replacing slot 4 奇异物质; current equipment retained. Exact restriction not explained.
- Cloud galaxy UI observed 9–12 FPS under X11 OpenGL compatibility, Mesa llvmpipe software rendering. Other pages also fluctuate; no hardware performance claim.

Continue B-route rewards and meaningful module spending, planet workshop completion and shipyard construction, galaxy building, equipment and crew choices. Γ4+, B2+, A route, later planets and rebirth remain unverified. Raw images, input logs, private notes and credentials are excluded from this public backup.
