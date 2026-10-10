extends "res://checkpoint_scene_cost.gd"
# Exact authorized QA7 snapshot, isolated by whole_game_perf.py.
func run():
 Engine.set_meta("checkpoint_path","res://checkpoint.json")
 Engine.set_meta("checkpoint_stage",7)
 Engine.set_meta("checkpoint_group",4)
 Engine.set_meta("checkpoint_ship","Frigate")
 await super.run()
