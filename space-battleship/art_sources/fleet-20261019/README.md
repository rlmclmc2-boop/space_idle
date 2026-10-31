# Five approved static player hulls

`hulls-transparent.png` supplies the gun-free hull pixels needed by the current extraction script.

Run `python art_sources/fleet-20261019/split_hulls.py` from the project (Pillow, NumPy, SciPy).
The script separates the five solid alpha components, retains the adjacent two-pixel anti-aliased fringe, removes isolated low-alpha noise, and adds 16 transparent pixels on every edge. The touching third/fourth fringes are assigned to their nearest solid component. Hull interiors are copied directly, never redrawn. Output dimensions and sockets consumed at runtime belong in the asset manifest.

Runtime PNGs: `assets/ships/fleet_20261019/player/`. Menu PNGs: `assets/ui/ships/fleet_20261019/`, centred on the menu's existing 768-pixel canvas, all at the same source scale.

`data/ship_weapon_visuals.json` binds the five textures and 1/2/3/4/5 normalized sockets. `static_height` is the opaque atlas height × 0.2; the live view still applies the existing global and per-ship visual multipliers. This replaces the old presentation-only class reductions. `geometry_texture`, gameplay sizes and ship-centre authority remain unchanged. Independent weapon models, pivots and true muzzle sockets remain the existing assets. Menu button locations follow the corresponding static image sockets in `assets/ui/ships/manifest.json`.
