extends "res://qa/stage_campaign.gd"
func observe(kind:String,payload:Dictionary)->void:
 super.observe(kind,payload)
 if kind=="upgrades_completed":record("observed_paid_crew_batch",{"slots":payload.slots,"loadout_after":game.profile.loadout.duplicate(true),"resources_after":game.profile.resources.duplicate(true),"crew":game.profile.crew.duplicate(true),"scope":"Observer only; production successful paid equipment batch event, no additional input/tick"})
