extends "res://qa/stage_campaign.gd"
## Original diagnostic event observer; inherited game/input policy is unchanged.
func observe(kind:String,payload:Dictionary)->void:
 super.observe(kind,payload)
 if float(options.get("qa34_entry_x1",-1.0))>=0.0:return
 if game.manual_hyperspace.active or game.stage!=34 or game.state!=BattleGame.State.COMBAT:return
 options.qa34_entry_x1=game.simulated_time
 options.duration=game.simulated_time+43200.0
 checkpoint_due=true
 record("actual34_gate_clock_armed",{"entry_x1":game.simulated_time,"end_x1":options.duration,"scope":"Actual first main34 combat; endpoint stored in checkpoint options. No resource/gear/rate/input mutation."})
