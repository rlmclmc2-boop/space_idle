# Eight base enemies — actual battle import check

Base `main 5b3eb6b`; approved source `f9af84734145a6df6bcc1998fff15730936aa78a`.

- `base-eight-battle.png`: actual main window PNG1372×883 (requested1373×883).
- `base-eight-battle-large.png`: second actual window render at1952×1256. Neither screenshot was cropped, rescaled or composited.
- Rows left to right: scout/sentry/interceptor/swarm, then anchor/reactive/shielded/command. Wide hulls are complete; swarm preserves all four craft.
- `battle.json` / `battle.log`: eight intended identities resolved with the new textures and original geometry textures; two friendly launches,72 hostile launches,62 settled hits before pausing. Maximum display-alpha centre error0.00000191 presentation units.
- `asset-check.json`: true RGBA and safe margins, source aspect preserved, swarm4 components/all other hulls1, exact baseline geometry bytes, and only eight display texture fields changed.

The screenshot fixture runs the actual `main.tscn` with a deterministic held-health QA formation and save disabled, then pauses for capture. It is not an authored natural encounter. Local environment: Godot4.6.3 Linux/OpenGL llvmpipe, GDS combat path (`native=false`); no native build or performance claim belongs to this asset-only change. Elite/BOSS overlays remain unchanged.

Replay assets: `python test/check_enemy_base_eight_assets.py` from repository root. Capture: copy `test/test_enemy_base_eight_battle.gd` to an isolated imported project root, run Godot graphically with `--script res://test_enemy_base_eight_battle.gd` and `ENEMY_BASE_OUTPUT=<output>`, using isolated XDG user directories. The fixture changes only in-memory QA actors, never live saves or game data.
