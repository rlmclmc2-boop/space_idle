# Docked craft placement correction

Source `wip/planet-thread-resume-20261101@0292d0b6`, Blender 4.3.2, Godot 4.7.2. The new docked craft's vertices were authored in dock-local coordinates, but its parent had another -0.76 offset; most of the craft sat beyond the fork. It now sits between the cantilevers, visible in complete and 70° views. Four-stage images confirm it appears only with the owned shipyard. This is a local visual correction, not overall art acceptance.
