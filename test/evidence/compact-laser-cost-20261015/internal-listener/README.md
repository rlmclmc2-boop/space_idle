# Internal no-business hot listener probe

The existing pulse laser QA fixture has 480 sample steps and 1,057 displayed frames with 55,395 `fire`, `projectile_impact`, `hit`, `enhancement_chain`, and `enhancement_secondary` events. This follow-up measures the six production listener classes that do no business for those event names: `Game._compiled_configuration_event`, `Crew.on_event`, `HightechWorkshop.on_game_event`, `HyperspacePanel.on_event` (including its two child callbacks), `PlanetPanel._on_log_event`, and `ReactorPanel.on_game_event`. `HyperspacePanel` and `PlanetPanel` each have two live registrations in this isolated fixture, so the measured signal has **eight actual Callables**. `Battlefield` and QA/external observers are excluded because their hot-event work must remain.

The QA-only `run_internal_listener_probe.py` creates a separate dummy signal after the real UI is constructed. It emits the exact event-name counts above into either zero subscribers or those eight *real connected objects*, alternating off/on/off/on/off. A single clock pair surrounds each 55,395-event batch; there is no per-event clock, new gameplay event, production edit, or altered battle step. Both on arms call `HyperspacePanel.on_event`, which forwards to `reward_feedback.on_event` and `exchange_ui.on_event`; those child callbacks return without work for the tested names. Raw times and the actual connection list are in `raw.json`; file hashes are in `receipt.json`. One preliminary attempt stopped at a wrong expectation of six registrations; its log and driver are preserved separately.

| Arm | Batch duration ms | Difference from adjacent empty-signal controls ms | Equivalent per 1,057 displayed frames ms |
|---|---:|---:|---:|
| Empty 1 | 9.948 | — | — |
| Eight callbacks 1 | 434.946 | 424.038 | 0.401 |
| Empty 2 | 11.868 | — | — |
| Eight callbacks 2 | 421.055 | 409.104 | 0.387 |
| Empty 3 | 12.035 | — | — |

The gross avoidable cost is about **0.39–0.40 ms per displayed frame** in this probe, before any interest router, callback wrapper, or maintenance cost. The same total divided by 480 steps is 0.85–0.88 ms per logical step, but uncapped rendering displays about 2.2 frames per step here. The production full busy-frame target is a different measure; this synthetic batch does not prove a whole-frame gain. It excludes the public signal's required Battlefield and external callbacks, and it does not measure call-site dictionary construction. Optional Reforge listener is absent in this fixture. This is an upper-bound direction check, not an A/B implementation result.

`Game.event` remains a public ordered signal. Internal listeners connect at different times; `Game` and `Crew` are early, `Battlefield` is connected before several UI panels, and external listeners may connect later. Disconnecting them and invoking a single private router would alter callback order relative to `Battlefield` and external observers. Keeping one filtering wrapper at each original signal position preserves order but still dispatches eight Callables on every hot event; a native proxy would add a new compatibility layer. With the measured gross cost below the required 0.5 ms mean whole-frame gain, no implementation is recommended.
