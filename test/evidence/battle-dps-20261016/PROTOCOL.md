# Optional native damage statistics protocol

The existing `hit` feedback reports pre-cap damage plus shield absorption. It does not identify the weapon source. Reconstructing actual damage or attribution from that feedback would be wrong for overkill, resistance, shield overflow, derived attacks, and delayed effects.

`SpaceCombatKernel` now exposes only `set_damage_stats_enabled(bool)` and `take_damage_stats()`. When enabled, each settled enemy hit adds its actual shield and health decreases to a per-source ledger. `take_damage_stats()` returns `{source, shield, health}` rows and clears that ledger. When disabled, it stores no rows and does not construct source strings. UI refresh never reads the combat world.

Source comes from the immutable attack birth, missile context, or delayed packet. Derived explosions inherit the triggering hit's source. An external hit with no provenance is `other`. The existing combat feedback, event bus, damage arithmetic, RNG calls, kill order, and native ownership do not read the ledger. The GDScript bridge drains it after each native step and before cancellation. The optional eight-second window is owned by `BattleGame` and is cleared on enable, disable, and wave spawn.

Large values follow the existing native numeric admission and handoff boundary. Native observations use the actual stored `double` state changes; the GDScript window sums them through `GrowthNumber`. Tests must cover values near that boundary and confirm the same handoff as the disabled run.
