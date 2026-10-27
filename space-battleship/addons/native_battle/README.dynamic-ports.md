# Shared battle geometry and muzzle inputs

`SpaceCombatKernel.input_geometry(points, muzzles)` supplies numerical points and ports. `input_ballistic_geometry(hulls, points, muzzles, stationary)` supplies retained/screen geometry; `input_player_hull` supplies the same visible player convex hull. `Battle._sync_geometry` passes the identical stable-ID port dictionary to both inputs. Player keys come from equipment/drone entries; enemy keys include actor UID and mount slot, so storage reuse cannot shift another source's port.

The current binding has no separate optional presentation-port inventory. The authored alpha hull and configured dimensions produce one world silhouette for drawing and collision. Turret cropping, authored port coordinates and fixed forward mount pose produce one world muzzle for native birth and visible art. Straight retained shots freeze their ray/launch at actual birth; sustained beams and missile motion keep their existing native lifetimes and birth rules.

`geometry_details()` returns copies of the committed native hulls, numeric/screen ports and active-flight birth/motion fields for focused verification. It does not advance gameplay or RNG and is not queried by the production frame loop. `_stage6_geometry_contract_probe.gd` checks actual launches and visible-hull contact through the same kernel; the existing combat/cannon oracles cover unchanged damage rules.

Build the Windows4.7.2 DLL with `build_native.ps1`; local binaries remain outside Git. The retained GPU batch format, shader clock and persistent mesh are unchanged.
