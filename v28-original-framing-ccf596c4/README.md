# Orbital band framing against the original design

Source: `wip/planet-thread-resume-20261101@ccf596c48837f32bb451492400bf5c9c890bc4f5`; reference: `8136cef8` complete-state right panel and `1eda07fd` construction-stage image in `space-battleship/docs/game-design/art/modules/planet-six/scheme-b/`.

The existing band and facility assets are unchanged. This source moves their common runtime orbital frame upward by 0.65 world unit. In the actual page and 1600×900 full-stage view, the far arc now follows the globe's top silhouette, the front arc has a small visible gap below the globe, and the entire lower hull stays inside the viewport with margin. The four separate construction states retain their ownership geometry.

`main-page.jpg`, `stage-1.jpg` through `stage-4.jpg`, and `normal-speed-6s.mp4` are all captured from this exact source in Godot 4.7.2. The video contains 90 consecutive frames at 15 fps. Scripts and import, page, stage, and motion logs are included. Runtime logs contain an ALSA device `ERR_CANT_OPEN` only; there are no GDScript or parse errors. Visual ownership fixtures do not claim natural unlocking.
