# Faceted arc material and normal-speed motion

Source: `wip/planet-thread-resume-20261101@c679963c1c5dc38e17b938909ebd003421ff9588`. Blender 4.3.2; Godot 4.7.2.

The v16 occupied-arc structure is retained. Medium-light pressure armor plates split the broad outer walls; the factory doors gain pressure piers and a broad upper fascia, while the refinery gets contained vertical heat vents. The refinery's animated ore loads were moved onto the new feed channel. Ring and facility connection geometry, UI, business IDs, and construction ownership remain.

`page-facilities-open.jpg` is the actual local game page with the current ship and controls, and `complete.jpg` is the same-source full built visual. `normal-speed.mp4` is 6.0 seconds at 15 fps using 90 frames and an exact `1/15` game-time step per frame; the capture script and start/mid/end samples are included. The earlier accelerated 32-frame video is not used for speed judgment. Logs show no GDScript parse/runtime errors; the headless ALSA fallback reports its known `ERR_CANT_OPEN`. Shared-host visual judgment and user acceptance are still separate.
