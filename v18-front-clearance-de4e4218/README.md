# Front-arc clearance

Source: `wip/planet-thread-resume-20261101@de4e42182def97d2fb38dfa7554bde1271e24cf3`; same v17 GLBs and UI. Godot 4.7.2.

The orbital plane tilt changed from (0.66, 0.751) to the normalized (0.72, 0.694), moving the front arc away from the painted globe in screen projection. Facility sockets, the ring, independent section ends, and the globe mask continue to use the same plane. `page-facilities-open.jpg` is the actual local game page; `complete.jpg` is the full built 2048×768 visual. `normal-speed.mp4` is 6.0 seconds / 90 frames at 15 fps with exactly `1/15` game-time advancement per frame. Start, middle, and end frames show the front negative space remains visible during motion.

Godot import and capture logs show no GDScript parse/runtime errors. Headless ALSA fallback reports its known `ERR_CANT_OPEN`. The first capture after generated-import cleanup failed to load runtime resources; these archived logs are from the successful repeat after editor import. This is an author evidence set for shared-host final integration, not user acceptance or main merge.
