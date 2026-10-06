extends "res://qa/stage_campaign.gd"
## Explicit QA player strategy: finish first galaxy while farming a won stage.
## No direct business mutation and no post-60 progression before full acceptance.
func action()->Dictionary:
 if not pending_picker.is_empty() or not player_input.modal_windows().is_empty() or not game.pending_unlocks.is_empty():
  return super.action()
 if game.profile.cleared.has(60) and not game.manual_hyperspace.active:
  if not game.manual_hyperspace.queued.is_empty():
   if game.profile.loop:
    return control_action("galaxy_hold60_release_for_manual",driver.scene.loop_button)
   return super.action()
  if game.stage!=60:
   var picker:OptionButton=driver.scene.loop_select
   return picker_action("galaxy_hold60_warp",picker,picker.get_item_index(60))
  if not game.profile.loop:
   return control_action("galaxy_hold60_guard",driver.scene.loop_button)
  # Planning/cooldown/page visits keep guard engaged. Request the real
  # production queue on the visible page before releasing the main guard.
  if page==9 and not space_policy.manual_pending.is_empty():
   if game.profile.hyperspace.auto.enabled:return {"domain":true,"kind":"space_auto_pause","reason":"Hold60 planned manual: stop future auto recurrence without discarding the current paid receipt"}
   var queued_choice:Dictionary=space_policy.pending_manual_action(game,game.simulated_time,false)
   if not queued_choice.is_empty():
    queued_choice.kind="space_manual_queue"
    return queued_choice
 var choice:Dictionary=super.action()
 if game.profile.cleared.has(60) and choice.get("kind","") in ["farm_guard_off","farm_warp_open"]:
  return {}
 return choice
func step_controller()->void:
 # A manual result restores the actual main journey. Reengage the native
 # hold promptly rather than waiting for the ordinary 300-second tour.
 if game.profile.cleared.has(60) and not game.manual_hyperspace.active and game.manual_hyperspace.queued.is_empty() and (game.stage!=60 or not game.profile.loop) and pending_picker.is_empty() and player_input.modal_windows().is_empty() and game.pending_unlocks.is_empty() and not busy:
  busy=true;burst_start=game.simulated_time;next_button=game.simulated_time+BUTTON_TIME
  record("galaxy_hold60_reengage_scheduled",{"reason":"No real queued manual; preserve earned stages while restoring actual hold60"})
 await super.step_controller()
func click_button(choice:Dictionary)->void:
 # The 0.3s input delay may have cancelled a formerly accepted queue.
 if choice.kind=="galaxy_hold60_release_for_manual" and game.manual_hyperspace.queued.is_empty():
  record("galaxy_hold60_release_cancelled",{"reason":"Production queue disappeared before native guard-off input"});return
 await super.click_button(choice)
 if not input_failure.is_empty():return
 if choice.kind=="space_manual_queue":
  record("galaxy_hold60_manual_queued",{"queued":game.manual_hyperspace.queued.duplicate(true),"guard_still_on":game.profile.loop,"reason":"Accepted production request before any guard release"})
 if choice.kind=="galaxy_hold60_guard":
  if not game.profile.loop or int(game.profile.guardStage)!=60:
   input_failure={"kind":choice.kind,"reason":"Native hold60 guard did not engage actual cleared stage"}
   record("input_failure_stop",input_failure)
  else:
   record("galaxy_hold60_engaged",{"guard_stage":game.profile.guardStage,"guard_index":game.profile.guardIndex,"reason":"Post-60 push deferred until comprehensive tests finish; actual native guard action"})
