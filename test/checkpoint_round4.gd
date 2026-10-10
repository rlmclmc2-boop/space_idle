extends "res://checkpoint_scene_cost.gd"
# Exact authorized QA20 snapshot. Fixture health is opt-in and reported.
func run():
 Engine.set_meta("checkpoint_path","res://checkpoint.json")
 Engine.set_meta("checkpoint_stage",20)
 Engine.set_meta("checkpoint_group",2)
 Engine.set_meta("checkpoint_ship","Destroyer")
 await super.run()
