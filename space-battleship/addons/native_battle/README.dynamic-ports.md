# Native presentation muzzles

`SpaceCombatKernel.input_presentation_muzzles(Array[PackedVector2Array])` is a retained presentation input: one row per native weapon storage slot, with screen-space visual ports. Empty rows preserve the display fallback. Wrong row counts/types and non-finite points are rejected atomically; numeric muzzle, collision, damage and RNG remain separate. This optional input is preserved for later presentation work; the current minimal Session does not publish visual-port rows.

`src/game_session.gd::_sync_geometry` supplies numeric and ballistic muzzles by stable source ID through `input_geometry` and `input_ballistic_geometry`. Player IDs come from equipment/drone entries; enemy IDs include actor UID and mount slot. Disabling a drone or reusing internal weapon storage cannot shift another source's muzzle.

Delayed/repeated births use current presentation ports at actual birth. Straight retained shots freeze their visual ray in the birth record, including launch feedback for shots retired before display. Sustained beams retain their current visual muzzle provider; homing missile motion retains its flight presentation path. Numeric rays remain available for collision and compatibility consumers. The GPU batch retains its 12-float instance format, shader clock and persistent mesh.

Build the Windows 4.7.2 DLL with `build_native.ps1`. `build_native_linux.py --bindings <pinned-checkout> --build-root <outside-source>` builds a local `.so`; it is not a shipping Windows DLL. Current verification scope is compilation and the existing independent Amount test; no presentation test harness is included.
