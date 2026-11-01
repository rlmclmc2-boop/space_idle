# M7 current-object UI state check

Source: `wip/planet-thread-resume-20261101@fdb72e5aa7cba24bfea76ab64c96f03c8fe6e80d`.

The focused Godot 4.7.2 script instantiates the real `src/ui/planet_panel.gd` with deterministic Planet/Crew fact doubles. It checks that a worker remains withdrawable after a facility moves to ready even though the former construction assignment is no longer an available option; building progress and pause text; ready and built transitions; claim admission; switch-to-another-planet rebind of claim targets, counts, and feedback; and stop/cancel commands against the newly selected planet ID. `run.log` records all seven checks. The doubles isolate UI mapping and command routing; they do not claim to exercise progression or natural unlocks. The real Planet owner already contains the read-only fact and accepted-claim checks in `foundation/tests/_colony_readonly_facts_probe.gd`.
