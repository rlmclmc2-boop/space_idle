# Approved eight static enemy hulls

True-alpha top-down PNGs with bow up; enemies rotate 180° at runtime. Source, prompt intent and provenance: `art_sources/enemy-fleet-20261019/README.md`. Regenerate with `python art_sources/enemy-fleet-20261019/prepare_assets.py`; manifest retains source hashes and normalization bounds. Hulls contain no installed weapons; existing weapon components remain independent.

Only the eight enemy_opening_* texture paths change in ship_weapon_visuals.json. geometry_texture keeps the original image for centre-hit geometry. Main.enemy_hull_rect fits these sprites uniformly into the approved 90.4×79.333 logical box (the former single-cell body allowance); the same presentation-only allowance applies to the drawn protection and status bars. No grid allocation, enemy movement, encounter rank inference, actor size, capacity, health/shield values or native simulation changes. Other enemy_* fallback art keeps its original display policy.
