# Static turret visual source

Source commit `c59db3758a26723faca4c62c1937c85fed415ae7`: left to right rail cannon, missile, pulse laser, sustained beam; separate pulse-bolt artwork.

`prepare_assets.py` splits the four solid alpha components, retains their two-pixel anti-aliased fringe, removes isolated low-alpha noise, and pads each PNG by 16 pixels. Hull/weapon interiors are copied directly. The output manifest records bounds, source base centres, padded image anchors, visual pixels-per-model and hashes. The bolt's visible glow is cropped and reduced offline; both presentation paths draw the same vertical PNG at 14 × 34 internal screen pixels.

`assets/weapons/fleet_20261019/manifest.json` controls display geometry only. Each flat turret rotates under the existing TurretPivot. Imported weapon meshes are hidden, while their original RotationBearing, Muzzle/Muzzle02 and transforms remain untouched. Art size and offset align its base centre with the unchanged pivot and its front with the existing emission nodes. The broad missile pod uses separate X/Z visual fit to the existing dual emission-node layout.

No combat tables, weapon timing, speed, damage, target or collision rules are changed. The new pulse GPU shader reuses the existing native retained mesh's first six vertices as a textured quad and collapses only the old pulse decoration triangles. Native C++/DLL and instance motion data remain unchanged.
