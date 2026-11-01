# Front facility medium-detail pass

Source: `wip/planet-thread-resume-20261101@415d3bbdf6418f0c7b08d394989034f83c20a84e`. The original reference is the complete-state right panel at `8136cef8` and the construction-stage image at `1eda07fd` under `space-battleship/docs/game-design/art/modules/planet-six/scheme-b/`.

The manufacturing portals gained angled armor shoulders, dark inner jambs and soffits, a pressure wall with vents, and a more legible machine bed with working jaws. The dock gained a sloped armored entry shell, recessed interior returns, clamp actuators and service lights. These parts remain attached to their owned facility roots; the ring pose, four construction states, animation pivots, business IDs and UI are unchanged.

`main-page.jpg`, `stage-1.jpg` through `stage-4.jpg`, and `normal-speed-6s.mp4` are Godot 4.7.2 captures from this exact source. Video duration is six seconds from 90 consecutive frames at 15 fps. Build/export/import and capture logs and scripts are included. The visual owned states are in-memory fixtures, not natural unlock. Godot logs have no script or parse errors; the sole runtime error is ALSA `ERR_CANT_OPEN` because there is no sound device.
