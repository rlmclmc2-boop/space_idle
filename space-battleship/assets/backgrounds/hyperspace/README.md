# Hyperspace route scenery

`routes_atlas.png` is original ImageGen artwork generated for this project, not a screenshot or a runtime render. The 2×2 atlas contains alpha/beta on the top row and gamma/delta below. Source output: `exec-c3e575aa-2b99-4bd4-9796-c2a3c9f233b9.png` (971×1619).

Art direction/prompt: four portrait deep-space environments; cyan optical lens arrays, cracked ochre planet and sparse debris, steel magnetic accelerator spines, violet eclipsed star and tilted accretion disk. Detailed upper/outer scenery with a dark empty lower central combat lane; no ships, projectiles, text or UI.

Consumer: `scripts/starfield.gdshader`, supplied by `scripts/battlefield.gd`. One quadrant covers the existing 572×960 battlefield fog quad; a 2.5% inset provides seam-safe overscan for ±0.8% slow UV motion. Runtime brightness is restrained for target readability. This replaces the route SDF scenery; no additional full-screen pass, GPU noise, screenshot readback or runtime asset generation.

Edit the source image with ImageGen if the composition needs changes. Keep quadrant order, dark combat lane and seam-safe margins. Production appearance and performance require parent validation.
