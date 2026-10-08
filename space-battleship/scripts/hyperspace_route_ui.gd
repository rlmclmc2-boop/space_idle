extends RefCounted
## Route controls read domain views; they never infer progression or calculate crew rewards.
var panel
var current:Label
var record:Label
var idle_time:Label
var luck:Label
var hint:Label
var background_status:Label
var challenge_status:Label
var progress:ProgressBar
var idle_button:Button
var challenge_button:Button
var stop_button:Button
var exit_button:Button
var crew_button:Button
var claim_button:Button
var claim_background_button:Button
var claim_feedback:Label
var claim_failed_key=""
var crew_dialog:AcceptDialog
var crew_choice:OptionButton
var crew_info:Label
var crew_enable:Button
var crew_reason:Label
var elapsed=0.0
func setup(owner) -> void:panel=owner
func game():return panel.host.game
func t(key:String,params:Dictionary={}) -> String:return panel.t(key,params)
func view(crew_id:String="") -> Dictionary:
 if not game().has_method("hyperspace_route_view"):return {}
 return game().hyperspace_route_view(panel.route,crew_id)
func build(parent:Node) -> void:
 current=panel.label(parent,"",26)
 var summaries=panel.row(parent)
 var history=panel.surface(summaries)
 record=panel.label(history,"");idle_time=panel.label(history,"")
 luck=panel.label(history,"");luck.mouse_filter=Control.MOUSE_FILTER_STOP
 var tasks=panel.surface(summaries)
 background_status=panel.label(tasks,"")
 progress=ProgressBar.new();progress.show_percentage=false;progress.custom_minimum_size.y=26;tasks.add_child(progress)
 challenge_status=panel.label(tasks,"")
 claim_button=panel.button(tasks,"layer_claim_challenge",func():claim_receipt("challenge"));claim_button.visible=false
 claim_background_button=panel.button(tasks,"layer_claim_background",func():claim_receipt("background"));claim_background_button.visible=false
 claim_feedback=panel.label(tasks,"",20);claim_feedback.visible=false
 var actions=panel.row(parent)
 var initial_view=view()
 idle_button=panel.button(actions,"layer_idle_once",func():act("start_hyperspace_idle"),{"layer":str(int(initial_view.get("current_layer",0)))})
 challenge_button=panel.button(actions,"layer_challenge",func():act("start_hyperspace_challenge"),{"layer":str(int(initial_view.get("next_layer",1)))})
 var management=panel.row(parent)
 stop_button=panel.button(management,"layer_stop",func():act("stop_hyperspace_idle"))
 exit_button=panel.button(management,"layer_exit",func():act("exit_hyperspace_challenge",false))
 crew_button=panel.button(management,"crew",show_crew)
 hint=panel.label(parent,"",20)
func reason(code:String) -> String:
 if code.is_empty():return ""
 if code=="other_route":return t("layer_reason_other_route")
 if code=="max_layer":return t("layer_reason_max_layer")
 if code in ["no_record","record","no_best_time","not_cleared","no_cleared_layer","no_history","invalid_record"]:return t("layer_reason_record")
 if code in ["busy","active","challenge_active","idle_active","background_active","auto_enabled","background_busy","challenge_busy"]:return t("layer_reason_busy")
 if code in ["crew","crew_missing","crew_unavailable","crew_occupied","no_crew"]:return t("layer_reason_crew")
 if code in ["warehouse","warehouse_full","blocked","pending","completed_pending","inventory_full","pending_reward"]:return t("layer_reason_warehouse")
 return t("layer_reason_unavailable")
func availability(control:Button,reasons:Dictionary,key:String) -> void:
 var code=str(reasons.get(key,"unavailable"))
 panel.put(control,"disabled",not code.is_empty())
 panel.put(control,"tooltip_text",reason(code))
func tick(delta:float) -> void:
 elapsed+=delta
 if elapsed<0.2:return
 elapsed=0.0;refresh()
func refresh_route_markers() -> void:
 var background:Dictionary=game().profile.hyperspace.get("idle",{})
 var running_route=str(background.get("route",""))
 for index in panel.routes.size():
  var marker:Label=panel.route_markers[index]
  var visible=not background.is_empty() and str(panel.routes[index].get_meta("route",""))==running_route
  panel.put(marker,"visible",visible)
  if visible:panel.put(marker,"text",t("layer_route_pending") if background.get("status","")=="completed_pending" else t("layer_route_background"))
func refresh() -> void:
 if current==null:return
 refresh_route_markers()
 var v=view();var reasons:Dictionary=v.get("reasons",{})
 var layer=int(v.get("current_layer",0));var next_layer=int(v.get("next_layer",1))
 if panel.first_win!=null:panel.put(panel.first_win,"visible",layer==0 and not v.is_empty())
 panel.put(current,"text",t("layer_current",{"layer":str(layer)}) if layer>0 else t("layer_unstarted"))
 panel.put(idle_button,"text",t("layer_idle_once",{"layer":str(layer)}))
 panel.put(idle_button,"visible",layer>0)
 panel.put(crew_button,"visible",layer>0)
 panel.put(challenge_button,"text",t("layer_challenge",{"layer":str(next_layer)}))
 panel.put(record,"visible",layer>0)
 panel.put(record,"text",t("layer_record",{"time":"%.2f"%float(v.get("best_time",0.0))}))
 var duration=float(v.get("idle_duration",0.0))
 panel.put(idle_time,"visible",layer>0 and duration>0.0)
 panel.put(idle_time,"text",t("layer_idle_time",{"time":"%.2f"%duration}))
 var total=float(v.get("total_luck",0.0))
 panel.put(luck,"visible",total>0.0)
 panel.put(luck,"text",t("layer_luck",{"value":"%.0f"%total}))
 panel.put(luck,"tooltip_text",t("layer_luck_sources",{"crew":"%.0f"%float(v.get("crew_luck",0.0)),"permanent":"%.0f"%float(v.get("permanent_luck",0.0))})+"\n"+t("layer_luck_rules"))
 availability(idle_button,reasons,"idle_once");availability(challenge_button,reasons,"challenge")
 availability(stop_button,reasons,"stop");availability(exit_button,reasons,"exit")
 panel.put(stop_button,"visible",str(reasons.get("stop","unavailable")).is_empty())
 panel.put(exit_button,"visible",str(reasons.get("exit","unavailable")).is_empty())
 var background:Dictionary=v.get("background",{})
 var challenge:Dictionary=v.get("challenge",{})
 var mode=str(v.get("task_mode","none"))
 # The domain supplies both receipts, so a concurrent challenge never hides background work.
 if background.is_empty() and mode in ["manual_idle","crew_idle"]:background=v
 var work=float(background.get("work",0.0));var task_duration=float(background.get("duration",0.0))
 var pending=str(background.get("status",""))=="completed_pending"
 panel.put(claim_background_button,"visible",pending)
 panel.put(background_status,"text",t("layer_task_pending") if pending else (t("layer_idle_work",{"work":"%.1f"%work,"duration":"%.1f"%task_duration}) if not background.is_empty() else t("layer_idle_none")))
 panel.put(progress,"visible",not background.is_empty())
 panel.put(progress,"value",100.0 if pending else clampf(100.0*work/maxf(0.001,task_duration),0.0,100.0))
 var challenge_pending=str(challenge.get("status",""))=="completed_pending"
 panel.put(claim_button,"visible",challenge_pending)
 panel.put(claim_feedback,"visible",not claim_failed_key.is_empty() and ((pending and panel.reward_feedback.receipt_key(background)==claim_failed_key) or (challenge_pending and panel.reward_feedback.receipt_key(challenge)==claim_failed_key)))
 var challenging=not challenge.is_empty() or mode=="challenge"
 panel.put(challenge_status,"visible",challenging)
 panel.put(challenge_status,"text",t("layer_task_pending") if challenge_pending else t("layer_challenging",{"layer":str(int(challenge.get("level",next_layer)))}))
 panel.put(hint,"visible",layer>0 or v.is_empty())
 panel.put(hint,"text",t("layer_reason_unavailable") if v.is_empty() else t("layer_hint"))
 # Preview updates only while its own native dialog is visible. Preserve selection and focus.
 if crew_dialog!=null and crew_dialog.visible:refresh_crew()
func claim_receipt(slot:String) -> void:
 var receipt:Dictionary=view().get(slot,{})
 if receipt.get("status","")!="completed_pending" or not game().has_method("claim_hyperspace"):return
 var key=panel.reward_feedback.receipt_key(receipt)
 var claimed=bool(game().claim_hyperspace(int(receipt.round_id),int(receipt.run_id)))
 claim_failed_key="" if claimed else key
 panel.put(claim_feedback,"text",t("layer_claim_retry") if not claimed else "")
 panel.dirty=true;refresh()
func act(method:String,with_route=true) -> void:
 if not game().has_method(method):return
 var ok=game().call(method,panel.route) if with_route else game().call(method)
 if not ok:panel.put(hint,"text",t("command_failed"));panel.put(hint,"visible",true)
 else:panel.dirty=true;refresh()
func show_crew() -> void:
 if crew_dialog==null:
  crew_dialog=panel.commands.build_dialog("crew")
  var body=panel.commands.content(crew_dialog)
  crew_choice=panel.option(body);crew_info=panel.commands.dialog_label(body,"",21)
  crew_reason=panel.commands.dialog_label(body,"",20)
  panel.commands.dialog_label(body,t("layer_crew_hint"),20,body.custom_minimum_size.x)
  crew_enable=panel.button(body,"layer_crew_start",start_crew)
  crew_choice.item_selected.connect(func(_index):refresh_crew())
 crew_choice.clear()
 var reserved=str(game().profile.hyperspace.auto.get("crew_id",""))
 for member in game().profile.crew:
  var id=str(member.crewId)
  if not game().crew.unlocked(game(),id):continue
  var available=game().hyperspace.Permission.crew_available(game(),id)
  var name=str(game().crew.definitions(game())[id].name)
  var availability_text=t("crew_available") if available else t("crew_occupied")
  var caption=t("layer_crew_choice",{"name":name,"status":availability_text})
  if game().crew.levels_unlocked(game()):
   var level=game().hyperspace.Permission.crew_level(game(),id)
   caption=t("crew_choice",{"name":name,"level":str(level),"status":availability_text})
  crew_choice.add_item(caption)
  var index=crew_choice.item_count-1
  crew_choice.set_item_metadata(index,id);crew_choice.set_item_disabled(index,not available)
  if id==reserved:crew_choice.select(index)
 if crew_choice.item_count==0:
  crew_choice.add_item(t("no_crew"));crew_choice.set_item_metadata(0,"")
 refresh_crew();crew_dialog.popup_centered(Vector2i(720,390))
func selected_crew() -> String:
 return str(crew_choice.get_item_metadata(crew_choice.selected)) if crew_choice.selected>=0 else ""
func refresh_crew() -> void:
 var id=selected_crew();var v=view(id)
 var time="%.2f"%float(v.get("crew_duration",0.0))
 var configured=id==str(v.get("crew_id","")) and not id.is_empty()
 panel.put(crew_info,"text",t("layer_crew_detail",{"time":time,"luck":"%.0f"%float(v.get("total_luck",0.0))}) if configured else t("layer_crew_time",{"time":time}))
 panel.put(crew_info,"tooltip_text",(t("layer_luck_sources",{"crew":"%.0f"%float(v.get("crew_luck",0.0)),"permanent":"%.0f"%float(v.get("permanent_luck",0.0))})+"\n"+t("layer_luck_rules")) if configured else "")
 var code=str(v.get("reasons",{}).get("crew_idle","unavailable"))
 if id.is_empty():code="crew_missing"
 panel.put(crew_enable,"disabled",not code.is_empty())
 panel.put(crew_reason,"visible",not code.is_empty());panel.put(crew_reason,"text",reason(code))
func start_crew() -> void:
 if not game().has_method("set_hyperspace_auto"):return
 if game().set_hyperspace_auto(panel.route,selected_crew(),true):crew_dialog.hide();panel.dirty=true;refresh()
 else:panel.put(crew_reason,"visible",true);panel.put(crew_reason,"text",t("command_failed"))
