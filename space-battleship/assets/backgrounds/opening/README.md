# Continuous V2 — first transition runtime assets

`stage_01.png` and `stage_02.png` are two overlapping cuts of ONE refined dock-to-near-orbit painting. Source, lineage and review evidence: [phase 01–02](../../../docs/art/continuous-v2-refinement/phase-01-02/README.md). The accepted parent layout is [continuous V2](../../../docs/art/parent-continuous-v2/README.md); its pixel coordinates and 80-point sequence are not gameplay distances/configuration.

Original painting was actually refined with ImageGen from the approved 253×634 section into 793×1983, preserving the dock, paired pylons, right planet and upper-left array. A second local pass quieted central stars and the planet rim. Runtime preparation downsamples to 572×1430, then cuts two 572×1199 PNGs with 960 shared visible rows and two-pixel filter support at both ends. No independent per-stage generation, crossfade, upscaled 253px runtime art, or per-frame image processing. Source images have `.gdignore` and are not runtime resources.

Rebuild: `python3 tools/build_continuous_v2_opening.py` (Pillow). This performs only technical downsampling, cropping, padding and seam assertions; it refuses source upsampling. `source/asset-report.json` in the review directory records exact sizes, hashes and PNG bytes.

Consumer: existing scenery quad / `starfield.gdshader` through `battlefield.gd`. Two preloaded textures; one texture sample per scenery pixel, same draw owner. Once per stage change: bind texture and normalized padding/visible/travel vector. Existing distance/level-length progress updates only on value changes. No new render pass, viewport, simulation loop, scan, upload-per-frame or runtime blur. Existing star and hyperspace paths remain.

Observed Godot import: lossless (`compress/mode=0`), no mipmaps, no size limit; shader explicitly uses linear filtering, repeat disabled, source color. RGBA8-equivalent residency upper estimate: 5,486,624 bytes / 5.23 MiB for both textures (excludes other game assets and driver overhead). This replaces the R01 three-texture residency estimate of 20.11 MiB. This is memory arithmetic and source inspection, not a measured native full-frame speedup/pass.

Only stages 1–2 are ready in this batch; stages 3–10 retain the existing background fallback until continued refinement. The rejected R01 SVGs and third texture are archived under docs/art/opening-three/revision-01-archive and are not referenced by runtime. Its old generator now outputs review-only files, so it cannot overwrite these paintings.
