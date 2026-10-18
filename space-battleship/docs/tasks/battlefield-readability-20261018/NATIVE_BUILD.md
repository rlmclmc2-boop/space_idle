# Native presentation parity

`addons/native_battle/src/combat_presentation.h` draws ordinary enemy
projectile cores when `SpaceCombatPresentation` is available. The source now
uses the same amber bolt and cyan streak as the GDScript fallback. Only the
projectile painting branch changed; motion, hit, collision, and damage code
did not.

A matching `space_native.dll` was compiled in the task workspace with Godot
4.7.2's pinned `godot-cpp` (`507ed9d840c01a3c5b2a39af8bb4000bfac30bf5`),
the verified single-precision API, and the existing LLVM MinGW toolchain.
The shared D-drive inputs were read only. The library was written to the task
workspace's `native-build/bin/space_native.dll` and temporarily copied into
this working tree for runtime validation; it is not a source commit artifact.

- Native source SHA-256: `0a916f0e848581d4519b19fd05e0ed304ae81be4e4156c3d78dd79469381e1d9`
- Built DLL SHA-256: `29d3f4bd0aea4f2b7ba6b78755f0c40e0e83716c4348917d48d7e4d7182d6552`
- Pinned static library SHA-256: `2f0bdb5f2110d5ac7116257c58d59588437b528befce5251fe1a7d6006198829`

The raw `evidence/native-headless.log` records a normal-speed stage 2 point 3
run with `combat_presentation=true`, eleven enemies, and no script error. By
frame 20 the native presentation had handled 21 draw calls; the game held 15
hostile projectiles at frame 60 and 12 at frame 100. The native execution
kernel was not admitted in this fixture (`native=false`); the native
presentation object was active. The dummy headless renderer cannot provide
pixels or GPU draw-call counts.

Visible OpenGL compatibility captures with matching before/after DLLs did
exercise the native presentation. The recorded GPU draw calls matched at
frames 20, 60, and 100: 261, 268, and 270 respectively. The projectile
geometry stays in the existing native triangle batch; no new per-frame node
or draw submission was introduced.
