# Follow-up: actual aircraft motion and bridge continuity

Candidate remains d6c944105d7c44ba67e3021d6d06c9c75797c85e, unmodified and unmerged. This focused capture reruns no broad test suite.

`flight-closeup-1x.gif` and `.mp4` show the original galaxy viewport at 815×558 with a fixed inspection camera (orthographic size 48 instead of the full-city fit). Aircraft scale, routes and production logic are unchanged. No count overlay or player/crew count is drawn in these viewport captures. The ship visibly moves across the open space in front of the headquarters, away from the service bridge plane.

The old full-city recording was not a still: it reported six visible aircraft each frame. The closer instrumented rerun confirms six spawned and visible for every captured frame, zero assigned crew, running=true, paused=false. Crew gates construction craft; it does not gate decorative transport. The full-city camera made those moving craft hard to read.

`flight-positions.json` records all six world/screen positions, route endpoints, running state and visual clock for each of 52 native frames. `positions-per-second.csv` extracts the nearest sample each second. Aircraft 0 moves from (36.668,16.004,11.982) to (-5.982,18.347,32.554); the six sampled travel distances are 47.51, 47.51, 47.26, 47.11, 47.07 and 47.51 world units. Their altitude is independent of the deck/bridge plane at Y≈0.

Playback uses original wall-clock timestamps over 12.136 seconds with game speed=1, no acceleration/interpolation. Under this Linux software renderer the visual clock advances only 6.787 seconds between first and last captured samples because low frame rate limits simulation progress. Thus “1x” means the actual captured wall-time playback, not a claim of full-speed Windows simulation. This also contributes to subtle motion in the earlier overview.

`service-bridge-joint.png` is a separate native inspection-camera capture of the three-way service junction, showing both district connections and the main trunk. No mesh or image edits. The flight GIF and bridge PNG are also confirmed native Library artifacts in `library-deliverables.json`.

Only focused recording/instrumentation was run. Source candidate, economical values, saved data, planet and Windows branches remain unchanged. Parent visual review is still required before any merge.
