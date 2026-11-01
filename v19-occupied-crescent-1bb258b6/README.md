# Occupied crescent runtime check

Source: `wip/planet-thread-resume-20261101@1bb258b62563416a2dede158d1f73bf1c65a3086`.

`complete.jpg` and `stage-1.jpg` through `stage-4.jpg` are 1600×900 captures from the same source and GLBs. The four stages set the built facility owners to the first 1–4 items in order: auto_explore, refinery, equipment, shipyard. `normal-speed.mp4` is 90 frames at 15 fps, with 1/15 game-time second per frame; `normal-00/45/89.jpg` are same-sequence frames. The image capture scripts and execution logs are included.

Blender 4.3.2 generated the source scene and four GLBs. This container has Godot 4.6.3 and an Xorg software renderer; its editor import and visual captures show no GDScript parse or runtime errors. Full-host review under the project's Godot 4.7.2 and the shared page layout is still required. ALSA falls back to dummy audio in this visual check.

Author review: the new upper occupied arc creates a longer continuous mass and the four stages keep their owned ends. In the current view, the middle of that arc still reads as a separation between the command and heat volumes, and the lower sections remain visually isolated. This is an in-progress structure check, not a final art acceptance or main merge.
