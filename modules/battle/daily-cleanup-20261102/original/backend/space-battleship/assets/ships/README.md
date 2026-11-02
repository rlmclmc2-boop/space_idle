# Current approved fleet assets

The runtime uses five static player hulls in `fleet_20261019/player/` (approved commit `9d485149`), eight archetype hulls in `enemy/fleet_20261019/` (`c45f46c4`), and elite/BOSS variants in `enemy/elite_boss_20261020/` (`24f0751d`). The source sheets, hashes and extraction reports remain in `art_sources/fleet-20261019/` and `art_sources/enemy-fleet-20261019/`.

Player bows face up. The approved global multiplier is1.7; per-ship factors remain in Excel. Source alpha and existing mount metadata define the shared rendered/collision geometry. Enemy source bows face up and rotate180° in battle, with uniform fitting to the approved ordinary90.4×79.333 box or each ranked entry's authored display_size.

Static weapon art and complete pivot/emission geometry come from `assets/weapons/fleet_20261019/manifest.json` (`97990c6e`, final scale `2943101f`). Ranked rotating housings use `assets/weapons/integrated_ranked_20261020/` and `data.enemy_rotating_art`. Missile art has two real ports; neither is dropped by the native adapter.

Enemy archetype/armour identity and encounter tier select one visual_key. Rendering, collision, mounts and intel thumbnails consume that same key. The newly authorized untyped compatibility mapping is recorded in the design/acceptance notes rather than presented as an older approval.

Retired models and retired renderer dependencies are not current manufacturing inputs. Shared effects, retained shaders, the WeaponDrone preview, galaxy assets and current source art are preserved.
