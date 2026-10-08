extends RefCounted
## UI command controller. Domain previews own all prices and randomness.
const OPERATIONS=["add_affix","replace_affix","add_hanging_slot","lock_affix","promote_affix","reroll_values","enable_omen","disable_omen","legendary","modernize","ultimate","restore_ultimate"]
var panel
var forge_actions=preload("res://scripts/hyperspace_forge_actions.gd").new()
var exchange_ui=preload("res://scripts/hyperspace_material_exchange_ui.gd").new()
var operation: OptionButton
var guarantee: OptionButton
var maximum: CheckBox
var quote_label: Label
var commit_button: Button
var feedback: Label
var promotion_hint: Label
var dismantle_hint: Label
var restore_hint: Label
var quoted_request: Dictionary={}
var crew_dialog: AcceptDialog
var crew_choice: OptionButton
var crew_info: Label
var crew_enable: Button
var module_dialog: AcceptDialog
var module_choices: Array[CheckBox]=[]
var module_apply: Button
var module_id=""
var collection_dialog: AcceptDialog
var collection_choices: Array[CheckBox]=[]
var totals_dialog: AcceptDialog
var totals_label: Label
var guide_dialog: AcceptDialog
var guide_label: Label
var guide_choice: OptionButton
var guide_scroll: ScrollContainer
var result_scroll: ScrollContainer
var result_details: Label
var materials_box: VBoxContainer
var material_rows: Dictionary={}
var material_stock: Label
var material_basis: Label
var material_route_button: Button
var missing_material=""
var material_reads=0
var show_advanced=false
var configured_drone=""
var operation_hint: Label
var more_operations: Button
var dismantle_request: Dictionary={}
var dismantle_dialog: ConfirmationDialog
func setup(p) -> void:
 panel=p;exchange_ui.setup(p);forge_actions.setup(self)
func t(key: String,params: Dictionary={}) -> String:return panel.t(key,params)
func game():return panel.host.game
func h():return game().hyperspace
func build_forge(parent: Node) -> void:
 var controls=panel.row(parent);controls.visible=false;operation=panel.option(controls)
 operation.add_item(t("choose"));operation.set_item_metadata(0,"none")
 guarantee=panel.option(controls);maximum=CheckBox.new();maximum.text=t("guaranteed_max");controls.add_child(maximum);panel.checkbox_skin(maximum)
 operation.item_selected.connect(func(_n):configure_operation());guarantee.item_selected.connect(func(_n):invalidate());maximum.toggled.connect(func(_v):invalidate())
 var help_row=panel.row(parent);panel.button(help_row,"forge_guide",show_guide)
 more_operations=panel.button(help_row,"more_operations",func():show_advanced=not show_advanced;rebuild_choices();configure_operation())
 more_operations.visible=false
 operation_hint=panel.label(parent,"",20);operation_hint.visible=false
 forge_actions.build(parent)
 materials_box=panel.box(parent,4)
 var hidden_costs=panel.box(materials_box);hidden_costs.visible=false
 material_basis=panel.label(hidden_costs,t("material_heading"),21)
 for key in ["degenerate_matter","glueball","antiproton","zero_point_energy","ultimate_cores"]:
  material_rows[key]=panel.label(hidden_costs,"",21)
 material_stock=panel.label(materials_box,"",18)
 var material_actions=panel.row(materials_box)
 material_route_button=panel.button(material_actions,"material_explore",explore_missing_material)
 panel.button(material_actions,"exchange_title",exchange_ui.show)
 var actions=panel.row(parent);var legacy_preview=panel.button(actions,"quote",preview);legacy_preview.visible=false;panel.button(actions,"collection_manage",show_collection);commit_button=panel.button(actions,"commit_forge",commit);commit_button.disabled=true;commit_button.visible=false
 promotion_hint=panel.label(parent,t("promotion_risk_hint"),21)
 dismantle_hint=panel.label(parent,t("dismantle_source_hint"),21)
 restore_hint=panel.label(parent,t("restore_modernize_hint"),21)
 feedback=panel.label(parent,"",21);quote_label=panel.label(parent,t("quote_first"),21)
 result_scroll=ScrollContainer.new();result_scroll.custom_minimum_size.y=180;result_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;result_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;parent.add_child(result_scroll)
 result_details=panel.label(result_scroll,"",21);result_details.size_flags_horizontal=Control.SIZE_EXPAND_FILL;result_scroll.visible=false
 promotion_hint.visible=false;dismantle_hint.visible=false;restore_hint.visible=false;quote_label.visible=false
 configure_operation()
func invalidate() -> void:
 quoted_request={};commit_button.disabled=true;quote_label.text=t("quote_first");feedback.text=""
 result_scroll.visible=false
 refresh_materials.call_deferred()
func refresh_materials(quoted: Dictionary={}) -> void:
 if materials_box==null:return
 var req=request()
 var result=quoted
 var deferred_forecast=false
 if result.is_empty() and not req.is_empty():
  # A guaranteed target can require many random draws. Only the explicit preview
  # runs that forecast; selecting a target never introduces a hidden long task.
  deferred_forecast=not str(req.args.get("guaranteed_key",req.args.get("guaranteed_effect",""))).is_empty()
  if not deferred_forecast:
   result=h().preview_forge(game(),req);material_reads+=1
 var costs:Dictionary=result.get("cost",{})
 var op=str(operation.get_item_metadata(operation.selected))
 var keys:Dictionary=costs if not costs.is_empty() else h().config.forge_costs.get(op,{})
 var stocks:Array[String]=[];missing_material=""
 for key in material_rows:
  var available=int(game().profile.hyperspace.ultimate_cores) if key=="ultimate_cores" else int(game().profile.hyperspace.materials.get(key,0))
  if key!="ultimate_cores" or available>0 or keys.has(key):stocks.append(t("material_owned",{"material":t(key),"owned":str(available)}))
  panel.put(material_rows[key],"visible",keys.has(key))
  if not keys.has(key):continue
  var exact=costs.has(key)
  var need=int(costs.get(key,0));var shortage=maxi(0,need-available)
  panel.put(material_rows[key],"text",t("material_requirement",{"material":t(key),"need":str(need) if exact else "—","owned":str(available),"missing":str(shortage) if exact else "—"}))
  var color=Color("b32929") if shortage>0 else Color("243d50")
  if material_rows[key].get_theme_color("font_color")!=color:material_rows[key].add_theme_color_override("font_color",color)
  if shortage>0 and missing_material.is_empty():missing_material=key
 panel.put(material_stock,"text"," · ".join(stocks))
 var message=t("material_heading")
 if req.is_empty():message=t("choose")
 elif deferred_forecast:message=t("material_forecast_needed")
 elif not str(result.get("error","")).is_empty() and costs.is_empty():message=error_text(str(result.error))
 if not req.is_empty() and str(result.get("error",""))=="affix_limit":
  var d:Dictionary=game().profile.hyperspace.inventory.drones.get(req.drone_id,{})
  if str(d.get("origin_quality",""))=="white":message=t("material_white_condition")
 panel.put(material_basis,"text",message)
 panel.put(material_route_button,"visible",not missing_material.is_empty() and missing_material!="ultimate_cores")
 if panel.section_index==2:forge_actions.refresh()
func explore_missing_material() -> void:
 for key in h().config.routes:
  if str(h().config.routes[key].material)==missing_material:
   panel.route=str(key);panel.select_section(0);return
func basic_available(op:String,d:Dictionary) -> bool:
 if d.is_empty() or game().profile.hyperspace.inventory.sealed.has(str(d.id)):return false
 if op=="dismantle":return not panel.Bag.protected(game().profile.hyperspace.inventory,str(d.id))
 if d.ultimate:return op=="restore_ultimate"
 var unlocked=d.affixes.any(func(a):return not a.locked)
 match op:
  "add_affix":return d.affixes.size()<panel.Bag.affix_limit(d,h().config)
  "replace_affix":return unlocked
  "add_hanging_slot":return int(d.hanging_slots)<panel.Bag.hanging_limit(d,h().config)
  "reroll_values":return unlocked or not d.legendary_effect.is_empty()
  "modernize":return int(request("modernize").args.target_level)>int(d.level)
 return false
func rebuild_choices(wanted:String="") -> void:
 if wanted.is_empty() and operation.selected>=0:wanted=str(operation.get_item_metadata(operation.selected))
 var d:Dictionary=game().profile.hyperspace.inventory.drones.get(panel.selected_id,{})
 var choices:Array=OPERATIONS if show_advanced else ["add_affix","replace_affix","add_hanging_slot","reroll_values","modernize","restore_ultimate"].filter(func(op):return basic_available(op,d))
 operation.clear()
 if choices.is_empty():operation.add_item(t("no_basic_operation"));operation.set_item_metadata(0,"none")
 for op in choices:
  operation.add_item(t("operation_"+op));operation.set_item_metadata(operation.item_count-1,op)
  if op==wanted:operation.select(operation.item_count-1)
 panel.put(more_operations,"text",t("basic_operations" if show_advanced else "more_operations"))
 panel.put(operation_hint,"text",t("advanced_operations_hint") if show_advanced else t("basic_operations_hint"))
func select_operation(op:String) -> void:
 # Semantic selection also supports explicit inspection of a blocked operation.
 configured_drone=panel.selected_id;show_advanced=true;rebuild_choices(op);configure_operation()
func configure_operation() -> void:
 if configured_drone!=panel.selected_id:
  configured_drone=panel.selected_id;show_advanced=false;rebuild_choices()
 elif not show_advanced:
  rebuild_choices()
 invalidate();guarantee.clear();guarantee.add_item(t("random_choice"));guarantee.set_item_metadata(0,"")
 var op=str(operation.get_item_metadata(operation.selected));guarantee.visible=op in ["replace_affix","legendary"];maximum.visible=op=="reroll_values"
 promotion_hint.visible=false
 dismantle_hint.visible=false
 restore_hint.visible=false
 var d: Dictionary=panel.bag.get("drones",{}).get(panel.selected_id,{})
 if d.is_empty():return
 var keys: Array=h().config.affixes.keys() if op=="replace_affix" else game().profile.hyperspace.legendary_collection
 for key in keys:
  var entry: Dictionary=h().config.affixes[key] if op=="replace_affix" else h().config.legendary_effects[key]
  if not entry.weapon.is_empty() and entry.weapon!=d.weapon:continue
  guarantee.add_item(panel.affix_name(key) if op=="replace_affix" else panel.effect_name(key));guarantee.set_item_metadata(guarantee.item_count-1,key)
func request(requested_operation:String="") -> Dictionary:
 var s: Dictionary=game().profile.hyperspace;var d: Dictionary=s.inventory.drones.get(panel.selected_id,{})
 if d.is_empty():return {}
 var op=requested_operation if not requested_operation.is_empty() else str(operation.get_item_metadata(operation.selected));var args: Dictionary={}
 if op=="none":return {}
 if op in ["replace_affix","legendary"] and guarantee.selected>=0:
  var key=str(guarantee.get_item_metadata(guarantee.selected))
  if not key.is_empty():args["guaranteed_key" if op=="replace_affix" else "guaranteed_effect"]=key
 if op=="reroll_values":args.guaranteed_max=maximum.button_pressed
 if op=="modernize":
  var route: String=h().config.routes.keys().filter(func(key):return h().config.routes[key].weapon==d.weapon)[0];var target=0
  for key in s.history.get(route,{}):
   if int(key)<=int(game().profile.highestLevel):target=maxi(target,int(key))
  args.target_level=target
 return {"round_id":s.round_id,"command_seq":s.command_seq,"drone_id":panel.selected_id,"operation":op,"args":args,"expected_revision":d.forge_revision}
func cost_text(cost: Dictionary) -> String:
 var values: Array[String]=[]
 for key in cost:
  var available=int(game().profile.hyperspace.ultimate_cores) if key=="ultimate_cores" else int(game().profile.hyperspace.materials.get(key,0))
  values.append(t("cost_item",{"material":t(str(key)),"cost":str(int(cost[key])),"available":str(available)}))
 return " · ".join(values) if not values.is_empty() else t("no_cost")
func error_text(error: String) -> String:
 return t("command_error_"+error) if UIText.entries.has("hyperspace.command_error_"+error) else t("command_failed")
func modernization_text(request_data: Dictionary) -> String:
 var d: Dictionary=game().profile.hyperspace.inventory.drones.get(request_data.drone_id,{})
 if d.is_empty():return ""
 var target: int=int(request_data.args.get("target_level",d.level))
 var projected: Dictionary=d.duplicate(true);projected.level=target
 var effects: Array[String]=[]
 for a in d.affixes+([d.ultimate_affix] if d.ultimate and not d.ultimate_affix.is_empty() else []):
  var before: float=preload("res://scripts/drone_effect_aggregator.gd").affix_value(a,d,h().config)
  var after: float=preload("res://scripts/drone_effect_aggregator.gd").affix_value(a,projected,h().config)
  var before_text: String=t("times",{"value":str(int(before))}) if str(a.key) in panel.COUNT_AFFIXES else t("percent",{"value":"%.1f"%(before*100.0)})
  var after_text: String=t("times",{"value":str(int(after))}) if str(a.key) in panel.COUNT_AFFIXES else t("percent",{"value":"%.1f"%(after*100.0)})
  effects.append(t("modernize_effect",{"name":panel.affix_name(str(a.key)),"before":before_text,"after":after_text}))
 return t("modernize_preview",{"before":str(int(d.level)),"after":str(target),"effects":"\n".join(effects) if not effects.is_empty() else t("modernize_no_affixes")})
func received_materials_text(materials: Dictionary) -> String:
 var values: Array[String]=[]
 for key in materials:values.append(t("reward_material_item",{"material":t(str(key)),"count":str(int(materials[key]))}))
 return " · ".join(values)
func dismantle_preview_text(request_data: Dictionary) -> String:
 var d: Dictionary=game().profile.hyperspace.inventory.drones.get(request_data.drone_id,{})
 if d.is_empty():return ""
 var quality: String="legendary" if d.legendary else str(d.origin_quality)
 var copies: int=int(h().config.dismantle_amounts[quality])
 # Match Rewards.dismantle's material units; module copies retain their authored count.
 var material_count: int=copies*int(h().config.get("material_unit_scale",10))
 var route: String=h().config.routes.keys().filter(func(key):return h().config.routes[key].weapon==d.weapon)[0]
 return t("dismantle_preview",{"materials":received_materials_text({str(h().config.routes[route].material):material_count}),"count":str(copies)})
func received_rewards_text(rewards: Dictionary) -> String:
 var lines: Array[String]=[t("dismantle_received_materials",{"materials":received_materials_text(rewards.get("materials",{}))})]
 for key in rewards.get("modules",{}):
  var outcome: Dictionary=rewards.modules[key]
  lines.append(t("dismantle_received_module",{"name":panel.hanging_name(str(key)),"count":str(int(outcome.copies)),"state":t("module_first_unlock") if outcome.newly_unlocked else t("module_duplicate"),"level":str(int(outcome.level)),"exp":"%.0f"%float(outcome.experience_added)}))
 return "\n".join(lines)
func preview() -> void:
 quoted_request=request()
 if quoted_request.is_empty():feedback.text=t("choose");return
 var result: Dictionary=h().preview_forge(game(),quoted_request)
 refresh_materials(result)
 var has_quote= str(result.error).is_empty() or not result.get("cost",{}).is_empty()
 quote_label.text=(t("quote_execution_result",{"cost":cost_text(result.get("cost",{})),"count":str(int(result.get("draws",0)))}) if quoted_request.operation=="modernize" else t("quote_result",{"cost":cost_text(result.get("cost",{})),"draws":str(int(result.get("draws",0)))})) if has_quote else ""
 if quoted_request.operation=="modernize" and has_quote:quote_label.text=modernization_text(quoted_request)+"\n"+quote_label.text
 if quoted_request.operation=="dismantle" and str(result.error).is_empty():quote_label.text=dismantle_preview_text(quoted_request)+"\n"+quote_label.text
 feedback.text=error_text(result.error) if not str(result.error).is_empty() else t("quote_ready")
 commit_button.disabled=not str(result.error).is_empty()
func commit() -> void:
 if quoted_request.is_empty():return
 execute_quote()
func show_inventory_dismantle() -> void:
 dismantle_request=request("dismantle")
 if dismantle_request.is_empty():return
 var result:Dictionary=h().preview_forge(game(),dismantle_request)
 var reason=str(result.get("error",""))
 if dismantle_dialog==null:
  dismantle_dialog=ConfirmationDialog.new();dismantle_dialog.title=t("operation_dismantle")
  panel.add_child(dismantle_dialog);preload("res://scripts/dialog_presentation.gd").dialog(dismantle_dialog)
  dismantle_dialog.confirmed.connect(execute_inventory_dismantle)
  dismantle_dialog.canceled.connect(func():dismantle_request={})
 var d:Dictionary=game().profile.hyperspace.inventory.drones.get(dismantle_request.drone_id,{})
 var title=t("card",{"weapon":t(str(d.weapon)),"level":str(int(d.level)),"quality":panel.quality_caption(d),"flags":""})
 var text=title+"\n\n"+dismantle_preview_text(dismantle_request)
 if not reason.is_empty():
  var flags=panel.protection_flags(str(d.id))
  text+="\n\n"+error_text(reason)+(": "+flags if not flags.is_empty() else "")
 else:text+="\n\n"+t("dismantle_confirm")
 dismantle_dialog.dialog_text=text;dismantle_dialog.get_ok_button().disabled=not reason.is_empty()
 dismantle_dialog.popup_centered(Vector2i(700,370))
func execute_inventory_dismantle() -> void:
 if dismantle_request.is_empty():return
 var req=dismantle_request;dismantle_request={}
 var result:Dictionary=h().forge(game(),req)
 panel.put(panel.inventory_feedback,"visible",true)
 panel.put(panel.inventory_feedback,"text",error_text(str(result.error)) if not str(result.error).is_empty() else received_rewards_text(result.get("rewards",{})))
 if str(result.error).is_empty() and bool(result.get("applied",false)):
  if panel.selected_id==str(req.drone_id):panel.selected_id=""
 panel.refresh_manual_status();panel.inventory_dirty=true;panel.refresh()
func execute_quote() -> void:
 if quoted_request.is_empty():return
 # Keep the preview receipt unchanged. Never refresh command sequence under a stale quote.
 var drone_id=str(quoted_request.drone_id)
 var operation_id=str(quoted_request.operation)
 var result: Dictionary=h().forge(game(),quoted_request)
 commit_button.disabled=true;quoted_request={};quote_label.text=t("quote_first")
 if str(result.error).is_empty() and result.get("applied",false):
  quote_label.text=received_rewards_text(result.rewards) if result.has("rewards") else t("forge_paid_summary",{"cost":cost_text(result.get("cost",{}))})
 feedback.text=error_text(result.error) if not str(result.error).is_empty() else t("forge_done") if result.get("outcome",true) else t("forge_attempt_failed")
 var current:Dictionary=game().profile.hyperspace.inventory.drones.get(drone_id,{})
 if str(result.error).is_empty() and bool(result.get("applied",false)) and bool(result.get("outcome",true)) and not current.is_empty():
  if operation_id=="add_affix" and not current.affixes.is_empty():feedback.text=t("forge_added_affix",{"affix":panel.affix_summary(current.affixes.back(),current)})
  elif operation_id=="add_hanging_slot":feedback.text=t("forge_added_slot",{"count":str(int(current.hanging_slots))})
 result_scroll.visible=str(result.error).is_empty() and result.get("applied",false) and not current.is_empty()
 if result_scroll.visible:
  panel.put(result_details,"text",t("forge_result_current")+"\n"+panel.drone_description(current))
  result_scroll.scroll_vertical=0
 panel.dirty=true;panel.refresh()
 refresh_materials()
func build_dialog(title: String) -> AcceptDialog:
 var dialog=AcceptDialog.new();dialog.title=t(title);dialog.min_size=Vector2i(660,370);dialog.size=Vector2i(740,470);panel.add_child(dialog);preload("res://scripts/dialog_presentation.gd").dialog(dialog)
 return dialog
func content(dialog: AcceptDialog) -> VBoxContainer:
 var box=panel.box(dialog);box.custom_minimum_size=Vector2(680,250);return box
# Long dialog text needs a known width before wrapping or attachment to the native window.
func dialog_label(parent: Node,text: String,font_size: int,wrap_width:float=0.0) -> Label:
 var result=Label.new();result.autowrap_mode=TextServer.AUTOWRAP_OFF
 result.add_theme_font_size_override("font_size",font_size);result.add_theme_color_override("font_color",Color("243d50"))
 if wrap_width>0.0:
  result.custom_minimum_size.x=wrap_width;result.size=Vector2(wrap_width,0.0)
  result.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 result.text=text;parent.add_child(result);return result
func show_crew() -> void:
 if crew_dialog==null:
  crew_dialog=build_dialog("crew");var body=content(crew_dialog);crew_choice=panel.option(body);crew_info=dialog_label(body,"",21);var actions=panel.row(body)
  crew_enable=panel.button(actions,"auto_enable",func():set_auto(true));panel.button(actions,"auto_disable",func():set_auto(false));crew_choice.item_selected.connect(func(_n):refresh_crew())
 crew_choice.clear()
 var reserved=str(game().profile.hyperspace.auto.crew_id)
 for member in game().profile.crew:
  if not game().crew.unlocked(game(),str(member.crewId)):continue
  var name=str(game().crew.definitions(game())[member.crewId].name)
  var available= h().Permission.crew_available(game(),str(member.crewId))
  crew_choice.add_item(t("crew_choice",{"name":name,"level":str(h().Permission.crew_level(game(),str(member.crewId))),"status":t("crew_available") if available else t("crew_occupied")}));crew_choice.set_item_metadata(crew_choice.item_count-1,str(member.crewId))
  crew_choice.set_item_disabled(crew_choice.item_count-1,not available)
  if str(member.crewId)==reserved:crew_choice.select(crew_choice.item_count-1)
 if crew_choice.item_count==0:crew_choice.add_item(t("no_crew"));crew_choice.set_item_metadata(0,"")
 refresh_crew();crew_dialog.popup_centered(Vector2i(720,390))
func refresh_crew() -> void:
 var id=str(crew_choice.get_item_metadata(crew_choice.selected));var lv=h().Permission.crew_level(game(),id);var best=h().best_x1(game(),panel.route,int(panel.level.value))
 var quote=h().auto_quote(best,lv);var ticket=float(quote.ticket);var duration=float(quote.duration)
 crew_info.text=t("auto_projection",{"ticket":"%.1f"%ticket,"duration":"%.1f"%duration,"status":t("auto_enabled") if game().profile.hyperspace.auto.enabled else t("auto_disabled")})
 crew_enable.disabled=id.is_empty() or not h().Permission.crew_available(game(),id) or best<=0
func set_auto(enabled: bool) -> void:
 var id=str(crew_choice.get_item_metadata(crew_choice.selected))
 if h().set_auto(game(),enabled,panel.route,int(panel.level.value),id):crew_dialog.hide();panel.dirty=true;panel.refresh()
 else:crew_info.text=t("command_failed")
func show_modules() -> void:
 module_id=panel.selected_id
 if not panel.bag.get("drones",{}).has(module_id):return
 if module_dialog==null:module_dialog=build_dialog("module_manage")
 for child in module_dialog.get_children():
  if child is VBoxContainer:child.free()
 module_choices.clear();var body=content(module_dialog);var d: Dictionary=panel.bag.drones[module_id]
 dialog_label(body,t("module_slots",{"used":str(d.hangings.size()),"cap":str(int(d.hanging_slots))}),22)
 if int(d.hanging_slots)==0:dialog_label(body,t("module_no_slots"),21)
 var module_scroll=ScrollContainer.new();module_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;module_scroll.custom_minimum_size.y=120;module_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;body.add_child(module_scroll)
 var choices=panel.box(module_scroll);choices.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 var unlocked=0;var available=0;var has_zero_level=false
 for key in h().config.hanging_modules:
  var progress:Dictionary=game().profile.hyperspace.hanging_modules[key]
  var known:bool=progress.unlocked or int(progress.level)>0 or float(progress.exp)>0 or game().profile.hyperspace.inventory.drones.values().any(func(drone):return drone.hangings.has(key))
  if not known:continue
  unlocked+=int(progress.unlocked)
  var usable=bool(progress.unlocked) and int(game().profile.highestLevel)>=int(h().config.hanging_modules[key].unlock_stage)
  available+=int(usable);has_zero_level=has_zero_level or (usable and int(progress.level)==0)
  var choice=CheckBox.new();choice.text=t("module_choice",{"name":panel.hanging_name(key),"level":str(int(progress.level)),"exp":"%.0f"%float(progress.exp)});choice.set_meta("module_key",key);choice.button_pressed=d.hangings.has(key)
  choice.visible=known;choice.disabled=not usable or int(d.hanging_slots)==0 or d.ultimate or panel.bag.sealed.has(module_id)
  choices.add_child(choice);panel.checkbox_skin(choice);module_choices.append(choice)
  if choice.visible:
   var description=dialog_label(choices,module_effect_text(str(key),int(progress.level)),18)
   description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;description.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  choice.toggled.connect(func(_pressed):refresh_module_apply())
 if unlocked==0:dialog_label(body,t("module_none_unlocked"),21)
 elif available==0:dialog_label(body,t("module_none_available"),21)
 if has_zero_level:dialog_label(body,t("module_zero_level"),19)
 if d.ultimate:dialog_label(body,t("module_ultimate_locked"),21)
 elif panel.bag.sealed.has(module_id):dialog_label(body,t("module_sealed_locked"),21)
 module_apply=panel.button(body,"module_apply",func():
  var keys: Array=[]
  for choice in module_choices:
   if choice.button_pressed:keys.append(choice.get_meta("module_key"))
  if h().attach_hangings(game(),module_id,keys):module_dialog.hide()
  else:module_dialog.title=t("module_rejected"))
 if available>0:dialog_label(body,t("module_source_hint"),18)
 if int(panel.bag.get("reforge_count",0))>0:dialog_label(body,t("reforge_module_reset"),18)
 refresh_module_apply()
 module_dialog.popup_centered(Vector2i(740,510))
func module_effect_text(key:String,level:int) -> String:
 var config:Dictionary=h().config.hanging_modules[key];var effects:Array[String]=[]
 for effect in config.effects:effects.append(t("module_effect."+str(effect)))
 return t("module_effect_preview",{"effects":"、".join(effects),"current":"%.1f"%((pow(1.0+float(config.effect_growth),level)-1.0)*100.0),"next_level":str(level+1),"next":"%.1f"%((pow(1.0+float(config.effect_growth),level+1)-1.0)*100.0)})
func refresh_module_apply() -> void:
 if not is_instance_valid(module_apply):return
 var d:Dictionary=game().profile.hyperspace.inventory.drones.get(module_id,{})
 if d.is_empty():module_apply.disabled=true;return
 var selected=module_choices.filter(func(choice):return choice.button_pressed).size()
 var available=module_choices.any(func(choice):return choice.visible and not choice.disabled)
 module_apply.disabled=not available or int(d.hanging_slots)==0 or selected>int(d.hanging_slots) or (selected==0 and d.hangings.is_empty()) or d.ultimate or game().profile.hyperspace.inventory.sealed.has(module_id)

func show_collection() -> void:
 if collection_dialog==null:collection_dialog=build_dialog("collection_manage")
 for child in collection_dialog.get_children():
  if child is VBoxContainer:child.free()
 collection_choices.clear();var body=content(collection_dialog);dialog_label(body,t("collection_hint"),21)
 var sc=ScrollContainer.new();sc.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_child(sc);var choices=panel.box(sc)
 for key in game().profile.hyperspace.legendary_seen:
  var choice=CheckBox.new();choice.text=panel.effect_name(key);choice.button_pressed=game().profile.hyperspace.legendary_collection.has(key);choice.set_meta("effect_id",key);choices.add_child(choice);panel.checkbox_skin(choice);collection_choices.append(choice)
 if collection_choices.is_empty():dialog_label(choices,t("collection_empty"),21)
 panel.button(body,"collection_apply",func():
  var ids: Array=[]
  for choice in collection_choices:
   if choice.button_pressed:ids.append(choice.get_meta("effect_id"))
  if h().set_legendary_collection(game(),ids):collection_dialog.hide();configure_operation())
 collection_dialog.popup_centered(Vector2i(740,490))

func show_totals() -> void:
 if totals_dialog==null:
  totals_dialog=build_dialog("totals_manage");var body=content(totals_dialog);var sc=ScrollContainer.new();sc.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_child(sc);sc.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;totals_label=dialog_label(sc,"",21,body.custom_minimum_size.x)
 refresh_totals();totals_dialog.popup_centered(Vector2i(740,510))
func refresh_totals() -> void:
 if totals_label==null:return
 var totals:Dictionary=game().hyperspace_totals();var lines:Array[String]=[]
 for key in ["damage","critical_chance","critical_damage","repeat_chance","attack_speed","defence","armour","shield"]:
  var value=float(totals[key]);var additive=value if key in ["critical_chance","repeat_chance"] else value-1.0
  if additive==0.0:continue
  lines.append(t("total_"+key)+": "+t("percent",{"value":"%+.1f"%(additive*100.0)}))
 if int(totals.chain_count)!=0:lines.append(t("total_chain_count")+": "+t("times",{"value":"%+d"%int(totals.chain_count)}))
 for weapon in totals.weapon_damage:
  var bonus=float(totals.weapon_damage[weapon])-1.0
  if bonus!=0.0:lines.append(t("total_weapon",{"weapon":t(weapon)})+": "+t("percent",{"value":"%+.1f"%(bonus*100.0)}))
 for key in totals.hangings:
  var bonus=float(totals.hangings[key])
  if bonus==0.0:continue
  var effects:Array[String]=[]
  for effect in h().config.hanging_modules[key].effects:effects.append(t("module_effect."+str(effect)))
  lines.append(t("total_module_bonus",{"module":panel.hanging_name(str(key)),"effects":"、".join(effects),"bonus":t("percent",{"value":"%+.1f"%(bonus*100.0)})}))
 for key in totals.legendary:
  # An active legendary effect can work through constants even without nonzero random parameters.
  lines.append(panel.effect_name(key))
  var trigger=panel.legendary_trigger(key)
  if not trigger.is_empty():lines.append(trigger)
  for parameter in totals.legendary[key].parameters:
   var value=float(totals.legendary[key].parameters[parameter])
   if value!=0.0:lines.append("  "+t("effect_parameter_"+str(parameter))+": "+t("percent",{"value":"%.1f"%(value*100.0)}))
 panel.put(totals_label,"text","\n".join(lines) if not lines.is_empty() else t("totals_empty"))

func show_guide(topic:String="overview") -> void:
 if not bool(game().profile.hyperspace.unlocked_drones):return
 if guide_dialog==null:
  guide_dialog=build_dialog("forge_guide");guide_dialog.size=Vector2i(740,540)
  var body=content(guide_dialog)
  guide_choice=panel.option(body);guide_choice.item_selected.connect(func(index):render_guide(str(guide_choice.get_item_metadata(index))))
  guide_scroll=ScrollContainer.new();guide_scroll.custom_minimum_size=Vector2(680,350);guide_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;guide_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;body.add_child(guide_scroll)
  guide_label=dialog_label(guide_scroll,"",21,660)
 guide_choice.clear();guide_choice.add_item(t("forge_guide"));guide_choice.set_item_metadata(0,"overview")
 var d:Dictionary=game().profile.hyperspace.inventory.drones.get(panel.selected_id,{})
 var topics:Array[String]=[]
 for op in forge_actions.ACTIONS:
  if forge_actions.visible_action(op,d):topics.append("disable_omen" if op=="enable_omen" and bool(d.get("omen",false)) else op)
 topics.append("dismantle")
 if topic!="overview" and not topics.has(topic):topics.append(topic)
 for op in topics:
  guide_choice.add_item(t("operation_"+op));guide_choice.set_item_metadata(guide_choice.item_count-1,op)
  if op==topic:guide_choice.select(guide_choice.item_count-1)
 render_guide(topic);guide_dialog.popup_centered()
func render_guide(topic:String) -> void:
 guide_dialog.title=t("forge_guide") if topic=="overview" else t("operation_"+topic)
 panel.put(guide_label,"text",t("forge_guide_body") if topic=="overview" else t("forge_guide_"+topic))
 if topic=="ultimate":guide_label.text=t("ultimate_effect_summary",{"levels":str(int(h().config.ultimate_weapon_bonus))})+"\n\n"+guide_label.text
 guide_scroll.scroll_vertical=0
