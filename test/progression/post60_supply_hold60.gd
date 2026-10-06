extends "res://qa/stage_campaign.gd"
## Explicit QA player strategy: finish first galaxy while farming a won stage.
## No direct business mutation and no post-60 progression before full acceptance.
func action()->Dictionary:
 if not pending_picker.is_empty() or not player_input.modal_windows().is_empty() or not game.pending_unlocks.is_empty():
  return super.action()
 if game.profile.cleared.has(60) and not game.manual_hyperspace.active:
  if not space_policy.manual_pending.is_empty() or not game.manual_hyperspace.queued.is_empty():
   if game.profile.loop:
    return control_action("galaxy_hold60_release_for_manual",driver.scene.loop_button)
   return super.action()
  if game.stage!=60:
   var picker:OptionButton=driver.scene.loop_select
   return picker_action("galaxy_hold60_warp",picker,picker.get_item_index(60))
  if not game.profile.loop:
   return control_action("galaxy_hold60_guard",driver.scene.loop_button)
 var choice:Dictionary=super.action()
 if game.profile.cleared.has(60) and choice.get("kind","") in ["farm_guard_off","farm_warp_open"]:
  return {}
 return choice
func click_button(choice:Dictionary)->void:
 await super.click_button(choice)
 if not input_failure.is_empty():return
 if choice.kind=="galaxy_hold60_guard":
  if not game.profile.loop or int(game.profile.guardStage)!=60:
   input_failure={"kind":choice.kind,"reason":"Native hold60 guard did not engage actual cleared stage"}
   record("input_failure_stop",input_failure)
  else:
   record("galaxy_hold60_engaged",{"guard_stage":game.profile.guardStage,"guard_index":game.profile.guardIndex,"reason":"Post-60 push deferred until comprehensive tests finish; actual native guard action"})
