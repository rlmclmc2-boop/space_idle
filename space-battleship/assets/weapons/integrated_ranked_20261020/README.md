# Independent movable cannon assembly

Purpose: rotating white/gray armored housing and dark graphite barrel, above a stationary foundation already present in the approved ranked hull PNG. Not an equipment icon or projectile. No burgundy stationary base in this sprite.

Source: integrated-gun-source.png generated from the sole approved15a102ac sheet; full request in art_sources/enemy-fleet-20261019/integrated-gun-request.json. prepare_ranked_assets.py performs alpha cleanup, crop, uniform resize and a180° orientation conversion. Runtime320×640 RGBA sprite points DOWN for the enemy renderer; manifest records its mechanical housing pivot, real muzzle pixel, source coordinates and hash. No creative pixel painting by the import script.

The QA painter draws the texture quad about manifest.pivot_px. It never draws another foundation. Per-case scale derives from measured hull well width, and the isolated copied muzzle vector derives from the actual pivot-to-tip distance so retained/canonical rendering agree. The normal production cannon profile, numerical damage/CD/equipment and formation remain untouched. Do not register this prototype automatically for gameplay. Source geometry and future1/2/4 loadout budget decisions are separate from this art asset.
