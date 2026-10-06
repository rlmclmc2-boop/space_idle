extends "res://qa/stage_campaign.gd"
var four_saved:=false
var start_saved:=false
var result_saved:=false
const MainReturn=preload("res://scripts/hyperspace_main_return.gd")
func diagnostic_condition()->Dictionary:
 return {"state":int(game.state),"stage":game.stage,"group":game.group_index,"pending_unlocks":game.pending_unlocks.duplicate(),"guard":game.profile.loop,"production_boundary":game.manual_hyperspace.boundary_reason(game),"qa_safe":space_policy.safe_main_boundary(game),"manual_pending":space_policy.manual_pending.duplicate(true),"projectiles":game.projectiles.size(),"missile_queue":game.missile_queue.size(),"jewel_repeats":game.jewel_repeats.size(),"drone_delayed":game.drone_combat.delayed.size(),"energy":game.profile.hyperspace.energy,"materials":game.profile.hyperspace.materials.duplicate(),"resources":game.profile.resources.duplicate(true),"active":game.profile.hyperspace.active.duplicate(true),"drones":game.profile.hyperspace.inventory.drones.size(),"live":game.enemies.filter(func(e):return game.N.compare(e.hp,0)>0).size(),"last_error":game.manual_hyperspace.last_error}
func frozen(name:String):
 FileAccess.open(output+"/"+name+".bin",FileAccess.WRITE).store_buffer(var_to_bytes({"state":Meter.signature(game),"payload":Checkpoint.capture(self,manifest),"conditions":diagnostic_condition()}))
func step_controller()->void:
 if not four_saved and not space_policy.manual_pending.is_empty() and not game.manual_hyperspace.active and game.projectiles.size()==4 and game.enemies.all(func(e):return game.N.compare(e.hp,0)<=0):
  four_saved=true;record("actual_four_tail_wait",diagnostic_condition());frozen("actual-four-tail-wait")
 await super.step_controller()
 if game.manual_hyperspace.active and not start_saved:
  start_saved=true;record("actual_first_manual_active",diagnostic_condition());frozen("actual-first-manual-active")
 if not space_runs.is_empty() and not result_saved:
  result_saved=true;record("actual_first_manual_result_state",diagnostic_condition());frozen("actual-first-manual-result")
func click_button(choice:Dictionary)->void:
 var before=diagnostic_condition();var bad_before=rejected_inputs
 if choice.get("kind")=="space_manual":
  var raw_timer:float=game.clear_timer;var state=MainReturn.capture(game);var point=MainReturn.journey(game)
  record("actual_return_validation",{"raw_clear_timer":raw_timer,"captured_clear_timer":state.clear_timer,"valid":MainReturn.valid(state,point,game.db.levels.size()),"journey":point,"runtime_unchanged":game.clear_timer==raw_timer})
 await super.click_button(choice)
 if choice.get("kind") in ["space_manual","space_claim"]:
  record("actual_short_domain",{"choice":choice,"before":before,"after":diagnostic_condition(),"refused":rejected_inputs>bad_before})
  if choice.kind=="space_claim" and rejected_inputs==bad_before:
   frozen("actual-first-claimed-reward");options.duration=game.simulated_time+STEP
