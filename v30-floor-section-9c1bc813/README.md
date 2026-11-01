# Original facility shell with corrected manufacturing floor

Source: `wip/planet-thread-resume-20261101@9c1bc813014172a60489a2336724befd5b29c404`. Original reference: `8136cef8` complete-state right panel and `1eda07fd` stage image in `space-battleship/docs/game-design/art/modules/planet-six/scheme-b/`.

This version retains the continuous segmented deck, embedded observation station, faceted gold heat dome, manufacturing work zone and armored dock entrance from `701fe90a4`. It replaces an inverted variable-height manufacturing underside with a fixed-thickness pressure floor. The exposed black triangular extension below the work bay is gone in both the author image and Godot page.

`main-page.jpg`, four `stage-*.jpg`, and `normal-speed-6s.mp4` are all Godot 4.7.2 captures from this exact source. Video is 90 consecutive frames at 15 fps. Visual ownership fixtures do not claim natural unlocking. Capture scripts and build/export/import/page/stage/motion logs are included. The only runtime error is ALSA `ERR_CANT_OPEN` from a missing sound device; no script or parse errors occurred.
