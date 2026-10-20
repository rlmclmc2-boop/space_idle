# Parent GUI acceptance — 2026-10-20

Revision: ea680f33dcc2678d310d19fc1dc63de602e2d7dc. Godot 4.6.3, Linux real X11 display, Mesa llvmpipe software rendering. Isolated project and user data via test/run.py; no player saves used. This is graphical correctness evidence, not hardware performance acceptance.

Commands: python3 test/run.py test_planet_buff_ui.gd --godot /usr/local/bin/godot; python3 test/run.py test_planet_dialog_layout.gd --godot /usr/local/bin/godot. Neither uses --headless for the test process.

Planet buff UI: failed before capture at line 39 because cards["1"] was absent; process subsequently timed out after 180 seconds. Do not count it as passed or attribute it to a missing display. Original cleanup task is repairing the fixture.

Planet dialog layout: 97 checks, 0 failures. Parent visually inspected the generated planet-bonus-groups, planet-bonus-large, facility-long-description, facility-small-1024 and facility-small-1280 screenshots. The dialog remains bounded and its close control is visible; long descriptions are scrollable and large values fit. Other whole-screen layout and rendering performance are outside this acceptance. PNG originals remain in the parent isolated run, not delivered through Library.
