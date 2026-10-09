extends RefCounted
## Independent actions share existing domain quotes; selectors belong to their action.
const ACTIONS=["add_affix","replace_affix","add_hanging_slot","reroll_values","lock_affix","promote_affix","enable_omen","legendary","modernize","ultimate","restore_ultimate"]
const BASIC=["add_affix","replace_affix","add_hanging_slot","reroll_values","modernize"]
const CONFIRM=["lock_affix","promote_affix","legendary","modernize","ultimate","restore_ultimate"]
var commands_ref:WeakRef
var commands:
 get:return commands_ref.get_ref()
var cells:Dictionary={}
var buttons:Dictionary={}
var info_buttons:Dictionary={}
var selectors:Dictionary={}
var promotion_count:OptionButton
var maximum:CheckBox
var promotion_details_button:Button
var confirmation:ConfirmationDialog
var advanced_toggle:Button
var available_grid:GridContainer
var unavailable_grid:GridContainer
var advanced_expanded:=false
func setup(owner) -> void:commands_ref=weakref(owner)
func build(parent:Node) -> void:
 available_grid=GridContainer.new();available_grid.columns=3;available_grid.add_theme_constant_override("h_separation",8);available_grid.add_theme_constant_override("v_separation",8);parent.add_child(available_grid)
 advanced_toggle=commands.panel.button(parent,"forge_expand_unavailable",func():advanced_expanded=not advanced_expanded;refresh(),{"count":"0"})
 unavailable_grid=GridContainer.new();unavailable_grid.columns=3;unavailable_grid.add_theme_constant_override("h_separation",8);unavailable_grid.add_theme_constant_override("v_separation",8);parent.add_child(unavailable_grid)
 for op in ACTIONS:
  var cell=commands.panel.box(available_grid,3);cells[op]=cell
  var action_row=commands.panel.row(cell);action_row.add_theme_constant_override("separation",4)
  var button=commands.panel.button(action_row,"operation_"+op,func():act(op));button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button.custom_minimum_size=Vector2(145,74)
  button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;button.add_theme_font_size_override("font_size",16);buttons[op]=button
  var info=commands.panel.button(action_row,"forge_action_info",func():show_help(op));info.custom_minimum_size=Vector2(28,28);info.size_flags_vertical=Control.SIZE_SHRINK_CENTER;info_buttons[op]=info
  if op in ["replace_affix","legendary"]:
   var selector=commands.panel.option(cell);selectors[op]=selector;selector.item_selected.connect(func(_i):refresh())
  if op=="promote_affix":
   promotion_count=commands.panel.option(cell)
   for count in [1,10,100]:
    promotion_count.add_item(commands.t("promotion_attempts",{"count":str(count)}));promotion_count.set_item_metadata(promotion_count.item_count-1,count)
   promotion_count.item_selected.connect(func(_i):refresh())
  if op=="reroll_values":
   maximum=CheckBox.new();maximum.text=commands.t("guaranteed_max");commands.panel.checkbox_skin(maximum);cell.add_child(maximum);maximum.toggled.connect(func(_value):refresh())
func show_help(op:String) -> void:
 var d:Dictionary=commands.game().profile.hyperspace.inventory.drones.get(commands.panel.selected_id,{})
 commands.show_guide("disable_omen" if op=="enable_omen" and bool(d.get("omen",false)) else op)
func selected_target(op:String) -> String:
 if not selectors.has(op):return ""
 var selector:OptionButton=selectors[op]
 return str(selector.get_item_metadata(selector.selected)) if selector.selected>=0 else ""
func sync_selector(op:String,d:Dictionary) -> void:
 var selector:OptionButton=selectors[op];var wanted=selected_target(op)
 var keys:Array=commands.h().config.affixes.keys() if op=="replace_affix" else commands.game().profile.hyperspace.legendary_collection
 var available:Array=[]
 for key in keys:
  var definition:Dictionary=commands.h().config.affixes[key] if op=="replace_affix" else commands.h().config.legendary_effects[key]
  if definition.weapon.is_empty() or definition.weapon==str(d.get("weapon","")):available.append(key)
 if selector.get_meta("choices",[])==available and selector.item_count>0:return
 selector.set_meta("choices",available.duplicate());selector.clear();selector.add_item(commands.t("random_choice"));selector.set_item_metadata(0,"")
 for key in available:
  selector.add_item(commands.panel.affix_name(str(key)) if op=="replace_affix" else commands.panel.effect_name(str(key)));selector.set_item_metadata(selector.item_count-1,key)
  if str(key)==wanted:selector.select(selector.item_count-1)
func request(op:String) -> Dictionary:
 var req:Dictionary=commands.request(op)
 if req.is_empty():return req
 if op in ["replace_affix","legendary"]:
  req.args={};var target=selected_target(op)
  if not target.is_empty():req.args["guaranteed_key" if op=="replace_affix" else "guaranteed_effect"]=target
 if op=="promote_affix":req.args={"attempts":int(promotion_count.get_item_metadata(promotion_count.selected))}
 if op=="reroll_values":req.args={"guaranteed_max":maximum.button_pressed}
 return req
func visible_action(op:String,d:Dictionary) -> bool:
 if d.is_empty():return op in ["add_affix","add_hanging_slot","modernize"]
 if bool(d.get("ultimate",false)):return op=="restore_ultimate"
 if op=="restore_ultimate":return false
 if op in ["replace_affix","lock_affix","promote_affix","enable_omen"]:return not d.affixes.is_empty() or bool(d.get("omen",false))
 if op=="reroll_values":return not d.affixes.is_empty() or not d.legendary_effect.is_empty()
 if op=="legendary":return bool(d.legendary) or int(commands.game().profile.hyperspace.materials.get("zero_point_energy",0))>0 or not commands.game().profile.hyperspace.legendary_seen.is_empty()
 if op=="ultimate":return int(commands.game().profile.hyperspace.ultimate_cores)>0
 return true
func exchange_shortage(_op:String,result:Dictionary) -> Dictionary:
 if str(result.get("error",""))!="insufficient_materials":return {}
 var costs:Dictionary=result.get("cost",{})
 var materials:Array=commands.h().config.routes.values().map(func(route):return str(route.material))
 if costs.size()!=1 or str(costs.keys()[0]) not in materials:return {}
 var target:String=str(costs.keys()[0]);var balances:Dictionary=commands.game().profile.hyperspace.materials
 var amount:int=maxi(0,int(costs[target])-int(balances.get(target,0)))
 if amount<=0:return {}
 var source:String="zero_point_energy" if target=="degenerate_matter" else "degenerate_matter"
 var sources:Array=[source]+materials.filter(func(key):return key!=target and key!=source)
 for candidate in sources:
  if str(commands.h().material_exchange_quote(commands.game(),candidate,target,amount).error).is_empty():source=str(candidate);break
 var quote:Dictionary=commands.h().material_exchange_quote(commands.game(),source,target,amount)
 return {"source":source,"target":target,"amount":amount,"quote":quote}
func refresh() -> void:
 if buttons.is_empty():return
 var d:Dictionary=commands.game().profile.hyperspace.inventory.drones.get(commands.panel.selected_id,{})
 var later:=0
 var available_index:=0
 for op in ACTIONS:
  var offered=visible_action(op,d) or (not d.is_empty() and not bool(d.get("ultimate",false)) and op!="restore_ultimate")
  if not offered:commands.panel.put(cells[op],"visible",false);continue
  if selectors.has(op):sync_selector(op,d)
  var effective="disable_omen" if op=="enable_omen" and bool(d.get("omen",false)) else op
  var req=request(effective);var guaranteed=not selected_target(op).is_empty()
  var result:Dictionary=commands.h().preview_forge(commands.game(),req) if not req.is_empty() else {"error":"unavailable_drone"}
  var reason=str(result.get("error",""));var costs:Dictionary=result.get("cost",{})
  var current=reason.is_empty() or ((op in BASIC or guaranteed or (op=="legendary" and not bool(d.get("legendary",false)))) and reason=="insufficient_materials")
  var destination:GridContainer=available_grid if current else unavailable_grid
  if cells[op].get_parent()!=destination:cells[op].reparent(destination,false)
  var position:int=available_index if current else later
  if cells[op].get_index()!=position:destination.move_child(cells[op],position)
  if current:available_index+=1
  if not current:later+=1
  commands.panel.put(cells[op],"visible",current or advanced_expanded)
  var shortage=exchange_shortage(op,result)
  var name=commands.t("omen_on_action") if effective=="disable_omen" else commands.t("operation_"+op)
  var cost_lines:Array[String]=[]
  for key in costs:cost_lines.append(commands.t(str(key))+" "+commands.material_number(int(costs[key])))
  var status=commands.t("action_available") if reason.is_empty() else commands.error_text(reason)
  if reason=="insufficient_materials":
   var missing:Array[String]=[]
   for key in costs:
    var owned=int(commands.game().profile.hyperspace.ultimate_cores) if key=="ultimate_cores" else int(commands.game().profile.hyperspace.materials.get(key,0))
    if int(costs[key])>owned:missing.append(commands.t(str(key))+" "+commands.material_number(int(costs[key])-owned))
   status=commands.t("action_missing",{"materials":" · ".join(missing)})
  elif reason=="affix_limit":status=commands.t("action_no_affix_slots") if commands.panel.Bag.affix_limit(d,commands.h().config)==0 else commands.t("action_affix_full_count",{"count":str(d.affixes.size()),"capacity":str(commands.panel.Bag.affix_limit(d,commands.h().config))})
  elif reason=="no_new_record":status=commands.t("action_no_new_record")
  if op=="modernize" and reason.is_empty():status=commands.modernization_scope(d)
  if op=="promote_affix" and reason.is_empty():status=commands.promotion_summary(d)
  if op=="add_affix" and reason.is_empty():status=commands.t("add_affix_random_short")
  if guaranteed:status=commands.t("action_guaranteed_cost") if reason.is_empty() else status
  if not shortage.is_empty():
   status=commands.t("forge_exchange_material_shortage",{"source":commands.t(shortage.source),"target":commands.t(shortage.target),"cost":commands.material_number(int(shortage.quote.cost.get(shortage.source,0))),"amount":commands.material_number(int(shortage.amount))})
  if op=="add_hanging_slot":status+="\n"+commands.hanging_slot_scope(d)
  if op=="legendary" and not bool(d.get("legendary",false)):status+="\n"+commands.t("legendary_cultivation_short")
  if op=="enable_omen":status=commands.t("omen_scope_short") if reason.is_empty() else status+"\n"+commands.t("omen_scope_short")
  if op=="enable_omen" and d.affixes.is_empty():status+="\n"+commands.t("omen_empty_short")
  var caption=name+"\n"+(" · ".join(cost_lines) if not cost_lines.is_empty() else commands.t("no_cost") if reason.is_empty() else "—")+"\n"+status
  commands.panel.put(buttons[op],"tooltip_text",name+"\n"+commands.cost_text(costs,true)+"\n"+status)
  commands.panel.put(buttons[op],"text",caption);commands.panel.put(buttons[op],"disabled",not reason.is_empty() and shortage.is_empty())
 commands.panel.put(advanced_toggle,"visible",later>0)
 commands.panel.put(unavailable_grid,"visible",later>0 and advanced_expanded)
 commands.panel.put(advanced_toggle,"text",commands.t("forge_collapse_unavailable") if advanced_expanded else commands.t("forge_expand_unavailable",{"count":str(later)}))
func act(op:String) -> void:
 var d:Dictionary=commands.game().profile.hyperspace.inventory.drones.get(commands.panel.selected_id,{})
 var effective="disable_omen" if op=="enable_omen" and bool(d.get("omen",false)) else op
 commands.select_operation(effective)
 var req=request(effective)
 if req.is_empty():return
 var result:Dictionary=commands.h().preview_forge(commands.game(),req)
 var shortage=exchange_shortage(op,result)
 if not shortage.is_empty():
  commands.exchange_ui.show_prefilled(shortage.source,shortage.target,int(shortage.amount));return
 if not str(result.error).is_empty():commands.feedback.text=commands.error_text(str(result.error));refresh();return
 commands.quoted_request=req
 if op in CONFIRM or not selected_target(op).is_empty():
  if confirmation==null:
   confirmation=ConfirmationDialog.new();commands.panel.add_child(confirmation);preload("res://scripts/dialog_presentation.gd").dialog(confirmation)
   confirmation.confirmed.connect(commands.execute_quote);confirmation.canceled.connect(func():commands.quoted_request={})
   promotion_details_button=confirmation.add_button(commands.t("promotion_details_action"),false,"promotion_details")
   confirmation.custom_action.connect(func(action):
    if action=="promotion_details":confirmation.hide();commands.quoted_request={};commands.show_guide("promote_affix"))
  promotion_details_button.visible=effective=="promote_affix"
  confirmation.title=commands.t("operation_"+effective)
  var detail=commands.modernization_text(req)+"\n" if effective=="modernize" else ""
  if effective=="legendary" and not bool(d.get("legendary",false)):detail+=commands.t("legendary_slots_confirmation",{"slots":str(int(d.hanging_slots)),"capacity":str(commands.panel.Bag.hanging_limit(d,commands.h().config))})+"\n\n"
  if effective=="promote_affix":detail+=commands.promotion_summary(d)+"\n"+commands.t("promotion_scope",{"count":str(int(commands.promotion_forecast(d).get("count",0)))})+"\n"+commands.t("promotion_risk_hint")+"\n"+commands.t("promotion_batch_hint")+"\n"
  if effective=="ultimate":detail+=commands.t("ultimate_effect_summary",{"levels":str(int(commands.h().config.ultimate_weapon_bonus))})+"\n\n"+commands.t("ultimate_confirmation_consequence",{"cores":str(int(commands.h().config.forge_costs.restore_ultimate.get("ultimate_cores",0)))})+"\n\n"
  if effective=="restore_ultimate":detail+=commands.t("restore_confirmation_consequence")+"\n\n"
  confirmation.dialog_text=detail+commands.t("quote_result",{"cost":commands.cost_text(result.cost,true),"draws":str(int(result.get("draws",0)))})
  confirmation.popup_centered(Vector2i(700,370));return
 commands.execute_quote()
