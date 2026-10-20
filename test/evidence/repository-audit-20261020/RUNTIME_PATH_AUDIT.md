# Runtime path and overlapping implementation audit

This is a source-path review of the current branch, not a rendering acceptance result. The movement defect in the retained enemy display is owned by the separate animation thread; this cleanup branch does not change its implementation.

## Published scene and enemy draw dispatch

| Step | Source evidence | Consequence |
|---|---|---|
| Published entry | `space-battleship/project.godot` sets `run/main_scene` to `res://main.tscn`; `main.tscn` attaches `scripts/battlefield.gd`. | An instance of `scripts/main.gd` alone is a base-class fixture, not the published scene. |
| Inheritance | `battlefield.gd` extends `main.gd`; its `draw_battle` calls `super.draw_battle()` when effects are enabled. | The base draw loop executes with battlefield overrides. |
| Default contacts | `main.gd::draw_battle` asks `draw_retained_enemy_contacts` first. `battlefield.gd` initializes `retained_contacts_enabled` to `true`, constructs `retained_enemy_contacts.gd` in `create_draw_layers`, and its hook calls `retained_contacts.sync`. | In the normal published scene, supported enemies use retained parts. New behavior placed only in `battlefield.gd::draw_enemy_hull_and_status` is absent from this path. |
| Unsupported contacts | `retained_enemy_contacts.gd::compile_record` sets `supported=false` for bosses, leaders, and components outside its physical-gun/energy classes. Its `paint("fallback")` calls `paint_owner.draw_enemy_hull_and_status`. | The battlefield painter remains a live fallback. It must be kept or deliberately replaced along with those cases. |
| Explicit direct path | If `retained_contacts_enabled=false` or the retained owner is invalid, `battlefield.gd::draw_retained_enemy_contacts` returns false; the inherited draw loop calls `draw_enemy_hull_and_status` per living enemy. | The battlefield painter also remains the direct fallback. `test_retained_native_display.gd` toggles this switch, but its switch checks only verify visibility. |
| Base painter | `main.gd` also defines `draw_enemy_hull_and_status`, shadowed by the battlefield override in the published scene. Several test fixtures instantiate `main.gd` directly. | It is a candidate for consolidation after base-fixture users are reviewed, not proven removable by published-scene reachability alone. |

## Coverage relationship and confirmed gap

`test/test_enemy_entry_batch.gd` compares `enemy_render_position` with an independent formula and verifies cache invalidation. `test/progression/pulse_animated_contact.gd` checks logical contact motion and projectile hit behavior using `enemy_render_position`. Neither asserts that the retained record and drawn hull follow those changing positions. `test/test_retained_native_display.gd` checks a retained record's position against the numeric geometry at one captured state, then pauses the simulation; it verifies command reuse and toggles the direct painter, but does not assert visible motion across frames. Therefore these checks can pass while a motion change in the fallback painter is bypassed by normal retained rendering. The separate animation thread is repairing that concrete defect.

The top-level test inventory has 45 `test_*.gd` files with a textual reference to `res://scripts/main.gd` and 42 with one to `res://scripts/battlefield.gd`. These are overlapping fixtures, not a classification of 87 tests as valid or invalid. Base-class UI tests can still check shared panels or logic; they cannot alone accept battlefield-specific rendering. Every visual acceptance claim needs the published scene and whichever retained/fallback branch its feature uses.

## Candidate decisions

| Candidate | Current decision | Reason and next check |
|---|---|---|
| `battlefield.gd::draw_enemy_hull_and_status` | Keep. | Live fallback from `retained_enemy_contacts.gd` and direct path when retained is disabled or unavailable. Any movement change must reach the retained path too. |
| `main.gd::draw_enemy_hull_and_status` | Keep pending base-fixture review. | Shadowed in the published scene, but `main.gd` is instantiated directly by tests. Review those consumers and any standalone base use before merging/removing. |
| `main.gd` retained hooks returning false | Keep. | These hooks implement the base-class direct draw fallback; `battlefield.gd` overrides both. Removing them changes base fixtures and the inherited draw contract. |
| `retained_enemy_contacts.gd` fallback `Part` | Keep. | Boss/leader and unsupported component rendering currently reaches it. |
| `retained_contacts_enabled` switch | Keep pending design review. | The default is on; a test exercises off/on and the off branch gives a direct renderer if retained setup fails. A text search found no published UI switch, but this alone does not make the fallback redundant. |
| Duplicate `record.corners` assignment in `retained_enemy_contacts.gd::compile_record` | Safe local simplification candidate. | The same packed-array expression is assigned twice consecutively. Leave implementation changes to the animation owner while that file is in flight; this cleanup audit records it without touching shared code. |

## Retired hightech presentation chain

`main.gd::build_hightech_tab` instantiates `ai_tech_factory_page.gd` as the current hightech UI. A source and resource search across current `.gd`, `.tscn`, `.tres`, `.py`, and `.godot` files found no caller of `hightech_hall.gd`, `hightech_scroll.gd`, `hightech_workshop_room.gd`, `hightech_workshop_construction.gd`, or its parent `hightech_construction.gd`; the assembly shader was loaded only by that parent. Their six UID values likewise have no current scene/resource/script references. These files implement visual controls and shader effects, not game profile or save migration. They and their UID files were removed. Old `hightech_construction` entries in the optional saved-game performance and diagnosis module tables were removed so those tools do not try to instrument a deleted script. Frozen historical receipts that mention the old files remain evidence; current AI factory art and shared assets remain in place.

A second basename-reference sweep after removal covered the remaining 156 top-level `scripts/*.gd` files against current product `.gd`, `.tscn`, `.tres`, `.py`, `.godot`, and `.gdshader` sources, excluding frozen docs/test evidence. Every file had at least one other product-source filename reference. This only closes the simple orphan-file screen: a filename reference in a build tool or optional path is not proof of published runtime use, and dynamically selected paths need their own call-chain review.

## Remaining review

Trace other published subsystems from `main.tscn` and runtime configuration through their active owner before removing duplicate or old implementations. Distinguish tests of the base `main.gd` fixture from published `battlefield.gd` behavior, and distinguish numeric/model assertions from displayed output. Current headless pass counts in `test-status-current.csv` do not close GUI, native, Windows, or actual draw-path acceptance.
