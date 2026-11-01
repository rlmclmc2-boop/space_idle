# Curved orbital architecture checkpoint

Source: `wip/planet-thread-resume-20261101@6878ad96697dbb06dfa87b32da2f3feabc77fb68`.

The main station, heat facility and manufacturing hull now bend along the ring's common centerline. Roof, side wall and load root taper together. The manufacturing extension ends in a short inset gate. This is an author checkpoint for the current structure requirement, not user acceptance or a main-branch merge.

`page-facilities-open.jpg` is the actual 1440×900 Godot main page with the facility drawer open. `complete.jpg` and `stage-1.jpg` through `stage-4.jpg` show the ring and its independent construction stages in the 1600×900 art scene. `normal-speed.mp4` is 90 frames at 15 fps (6 seconds) of normal animation; `normal-00/45/89.jpg` are its sampled frames. All were captured against the same source commit with Godot 4.7.2 stable; Blender 4.3.2 built the source GLBs. The main-page run used the preexisting local native extension fixture under `/tmp/planet-native`, copied transiently for the editor import. Capture scripts and build/import/runtime logs are included.

Author check: The page now shows continuous curved major masses and a shorter manufacturing terminal; the independent ends close in the construction images. Main-page selection reached all four facility IDs. The remaining visual work is mid-scale armor layering and facility identity at page size, plus overall-host review. No natural unlock or full gameplay completion is claimed.
