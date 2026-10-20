# S04 durable completeness contract

This contract ranks committed disk candidates; it does not delete or reject an older sparse save merely because a newer writer emits more fields. The same shape and semantic validator is applied to the primary, `.import-prev`, and `.bak`. A higher-ranked committed candidate wins; ties keep that file order. Only a successfully applied load may finalize interrupted-import staging.

## Evidence for writer versions

| Version | Writer evidence | Completeness treatment | Allowed omission |
| --- | --- | --- | --- |
| 2 | Supported by the loader, but no v2 writer snapshot is established in this repository history. | `compatible_sparse` (rank 1). | Existing loader defaults remain available on disk. No invented v2 full-field contract. |
| 3 | First v3 writer in `4cac4e16759ba6050fa1f03c28d250f0dc45d15e`. | Historical core present: `historical_complete` (rank 2); otherwise rank 1. | Fields added in later versions, and conditional journey/guard state. |
| 4 | First v4 writer in `cc5e4b0e393b560f7dc7f4501ec1f89ca3891101`. | Same historically emitted core: rank 2; otherwise rank 1. | Fields added in later versions, and conditional journey/guard state. |
| 5, early | First v5 writer in `75d563fdcceab8e4ff11adbbf0f9a4d6cedbe8e3`; later v5 commits added persistent fields without a save sub-version. | Historical core present but current core incomplete: rank 2; otherwise rank 1. | Later v5 fields may be absent. Absence is indistinguishable from truncation, so a current complete backup takes precedence. |
| 5, current | `BattleGame.portable_save_data()` on runtime base `0d01530bdce168a55d0ce7c835f17072d66d6bc7`, verified against an isolated Godot 4.7.2 output. | All 47 unconditional fields below and `loadout.weapons/defence` present: `complete` (rank 3). | Conditional `journey`, guard fields and other conditional state only. |

The historical v3/v4 core is `version`, `resources`, `highestLevel`, `cleared`, `bossSeen`, `unlocked`, `loop`, `selectedShip`, `loadout`, `moduleVersion`, `hightechSavedAt`, `furnaceElapsed`, `furnaceIncomePeak`, `grantedUnlocks`, `jewels`, and `levels`, with both loadout slot categories. It follows the v3/v4 `fresh_profile()` and save composition code. Early v5 also wrote this core. Missing any historical-core field lowers the rank but does not erase the file or its eligibility as a compatible sparse candidate.

## Current v5 unconditional fields and owners

These are the exact 47 top-level keys in the fresh game's current `portable_save_data()` result. The audit test removes **each one** from a full v5 primary, then checks that an intact backup is selected and remains byte-identical through a subsequent save.

| Owner / boundary | Required fields for current completeness |
| --- | --- |
| Save identity, progression and selection | `version`, `resources`, `highestLevel`, `cleared`, `bossSeen`, `unlocked`, `loop`, `selectedShip`, `loadout`, `moduleVersion`, `levels`, `grantedUnlocks`, `saveIntervalMinutes` |
| Lifetime and notices | `lifetime_max_stage`, `seenUnlocks`, `readUnlocks`, `onboarding` |
| Equipment and enhancement | `enhancementVersion`, `enhancementLevel`, `enhancementOrder`, `enhancementBranches`, `enhancementAttacks`, `enhancementHits`, `equipmentSwitchUntil` |
| Economy and clocks | `hightechSavedAt`, `resourceSamples`, `productionElapsed`, `chronoSavedAt`, `chronoParticles`, `jewelFragments`, `jewelFurnaceElapsed`, `jewelFurnaceIncomePeak` |
| Reactor | `reactorLevel`, `reactorAllocation` |
| AI research | `aiTechLevels`, `aiTechProgress`, `aiTechActive`, `aiTechInput`, `aiIncomePeak`, `aiTechCompletionUnread` |
| Subsystems and compatibility projection | `hyperspace`, `hyperspaceReceipt`, `galaxies`, `planets`, `crew`, `crewEquipment`, `jewels` |

Within `loadout`, `weapons` and `defence` must exist for a rank-3 or rank-2 completeness claim. The existing schema continues to check types and nested semantic constraints. Conditional journey and guard state cannot be mandatory on a fresh save. A resource sample may have `production_time`; S03 preserves it when present, but an empty sample list cannot require a sample field. Retired and unknown fields do not establish completeness.

## Boundary-specific migration

- **Durable disk candidate:** `prepare_disk_data` copies the raw dictionary, then applies the old loader's missing `highestLevel=1` default. For a lower-ranked historical/sparse disk candidate only, a finite negative numeric resource is replaced on that copy by the corresponding fresh-profile starting value, matching the old loader's ignored-invalid behavior. Original bytes remain unchanged.
- **Portable import:** `prepare_data` retains its original strict requirement for `highestLevel` and both resource IDs. It rejects a negative balance and malformed known fields. No disk-only default is applied to an imported file.
- **Recovery result:** invalid shape/semantics remain rejected; rank 3 outranks rank 2 and rank 1. A lower-ranked primary cannot mask or rotate over a higher-ranked backup. With no higher-ranked copy, historical and sparse saves remain loadable. A failed post-load staging finalization surfaces `progress_recovery_pending`, retains selected live progress, and disables saves.

Because v5 has no sub-version for later fields, a preexisting sparse v5 file cannot be proven complete from its version number. This policy preserves its loadability and protects a more complete committed copy without claiming that a sparse file is fully intact.
