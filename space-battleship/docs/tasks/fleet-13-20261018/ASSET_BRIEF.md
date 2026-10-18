# Single-ship source brief — approved fleet 13

Authority: `art/approved-fleet-reference-20261018@4553ab667a297e437de98bc61e3139e80a3692b9`, `test/evidence/fleet-reference-20261018/approved-fleet-13.png.base64`. The decoded PNG is a reference sheet, **not** an asset source to crop.

Provide **13 independent PNG files**, one numbered design per file. Final canvas: **887×1774**, true transparent alpha; bow up, centered, safe margin, complete hull. Retain the approved sheet's top-down illustrated 3D look, bold readable outline, segmented armor and saturated small lights. Player palette white/navy/cyan; enemy palette graphite/orange with cyan details where shown. No grid, blue field, text, numbers, silhouettes, cast shadow, decorative FX, baked gun/turret, projectile, other ship or opaque matte. Do not merge or invent hulls. The game draws weapon modules from its existing hardpoint map, and rotates enemy textures 180°.

| No. | Existing key | Approved shape cue | Intended new file |
| --- | --- | --- | --- |
| 01 | `Frigate` | pointed teardrop scout, central blue cockpit, compact single rear engine | `player/01-frigate.png` |
| 02 | `Destroyer` | H layout, two long narrow side hulls linked by central bridge, two rear engines | `player/02-destroyer.png` |
| 03 | `Cruiser` | broad curved manta wings, central cockpit and rear engine | `player/03-cruiser.png` |
| 04 | `Battleship` | broad armored rectangular hull with symmetric side pods and three bright aft engines | `player/04-battleship.png` |
| 05 | `Heavy_Battleship` | long central spine with three pairs of short lateral modules, tall narrow whole silhouette | `player/05-heavy-battleship.png` |
| 06 | `scout` | **short, wide, wingless** rounded scout; horizontal cyan front strip, two tiny aft engines | `enemy/06-scout.png` |
| 07 | `sentry` | squat T-shaped sentry, broad rectangular shoulder bar, narrow central stem | `enemy/07-sentry.png` |
| 08 | `interceptor` | **pointed slender long** interceptor, modest swept side fins, two aft engines | `enemy/08-interceptor.png` |
| 09 | `swarm` | **exactly five separate small fighters in one transparent sprite**, loose coherent cluster; no frame or connector | `enemy/09-swarm.png` |
| 10 | `anchor` | very broad heavy angular armored wedge, strong central mass and three aft engines | `enemy/10-anchor.png` |
| 11 | `reactive` | deep U form with two tall parallel side pylons around a low central fuselage | `enemy/11-reactive.png` |
| 12 | `shielded` | armored central hull with **two large circular shield emitters**, one per side, orange centers | `enemy/12-shielded.png` |
| 13 | `command` | **long vertical command hull**, narrow center spine, symmetric slim side towers | `enemy/13-command.png` |

Place delivered files under `res://assets/ships/approved_fleet_20261018/` using the relative filenames above. The integration changes only the 13 `texture` values in `data/ship_weapon_visuals.json`. Five player keys and eight enemy archetype keys already exist. Other size fallback hulls, opening_v1 history and UI portraits stay outside this batch.

Acceptance: 13/13 alpha PNGs have 887×1774 pixels and nonempty alpha silhouettes with safe edges; no reference-sheet grid/lettering survives. The five approved silhouette distinctions called out by the user (06, 08, 09, 12, 13) must be visibly present. Then run a focused import/config check and a single automated real-game capture without manually cycling through GUI images. Preserve original screenshots and disclose any unresolved hardpoint or small-scale readability issue.
