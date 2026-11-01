# Direct reactor furnace outlet candidate

Runtime source: `f7d3d055f811b4e9cf243f6190e18b3b26e8c98d`. Producer is the reactor execution thread itself; no sub-agent made this change.

The open trough shares its vertex path from pool bank through an actual right-wall notch to the delivery tube. Its side walls and liquid surface descend together. The work alpha limits the moving outlet heat to the modeled liquid. Owner, port coordinates, other devices, main and public shell are unchanged.

Godot 4.7.2, Linux Xorg :100, Compatibility, 1440×900. Four enabled routes and 25% each are controlled through the existing Owner-driven preview; not natural progress. `preview.gd` dismisses normal guidance every frame so it does not obscure the run. Video is normal 1×, 25fps, 250 frames, exactly10s. Recording overhead is not a performance measurement. The driver holds the scene four extra seconds after its observation interval so capture ends before the window closes.

The producer viewed all250 furnace frames in the five sequential sheets and whole-page time samples plus original-size active/zero frames. The trough stays connected and the heat travels within its surface. This is author evidence, not independent or user acceptance. Public-shell integration, four-device material consistency, shield volume and target hardware performance are not passed by this packet.

Render: `blender -b -t 3 --python assets/ui/reactor/b01/generate_reactor_devices.py -- --only smelting`; assemble: `REACTOR_ONLY=smelting python assets/ui/reactor/b01/assemble_reactor_devices.py`. Game command uses the existing native descriptor and fresh temporary XDG directories.
