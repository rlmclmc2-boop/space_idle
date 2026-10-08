extends RefCounted
## Independent actions share existing domain quotes; selectors belong to their action.
const ACTIONS=["add_affix","replace_affix","add_hanging_slot","reroll_values","lock_affix","promote_affix","enable_omen","legendary","modernize","ultimate","restore_ultimate"]
const CONFIRM=["lock_affix","promote_affix","legendary","modernize","ultimate","restore_ultimate"]
var commands_ref:WeakRef
var commands:
 get:return commands_ref.get_ref()
var cells:Dictionary={}
var buttons:Dictionary={}
var selectors:Dictionary={}
var maximum:CheckBox
var confirmation:ConfirmationDialog
func setup(owner) -> void:commands_ref=weakref(owner)
func build(parent:Node) -> void:
 var grid=GridContainer.new();grid.columns=3;grid.add_theme_constant_override("h_separation",8);grid.add_theme_constant_override("v_separation",8);parent.add_child(grid)
 for op in ACTIONS:
  var cell=commands.panel.box(grid,3);cells[op]=cell
  var button=commands.panel.button(cell,"operation_"+op,func():act(op));button.custom_minimum_size=Vector2(210,80)
  button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;button.add_theme_font_size_override("font_size",18);buttons[op]=button
  if op in ["replace_affix","legendary"]:
   var selector=commands.panel.option(cell);selectors[op]=selector;selector.item_selected.connect(func(_i):refresh())
  if op=="reroll_values":
   maximum=CheckBox.new();maximum.text=commands.t("guaranteed_max");commands.panel.checkbox_skin(maximum);cell.add_child(maximum);maximum.toggled.connect(func(_value):refresh())
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
func refresh() -> void:
 if buttons.is_empty():return
 var d:Dictionary=commands.game().profile.hyperspace.inventory.drones.get(commands.panel.selected_id,{})
 for op in ACTIONS:
  var shown=visible_action(op,d);commands.panel.put(cells[op],"visible",shown)
  if not shown:continue
  if selectors.has(op):sync_selector(op,d)
  var effective="disable_omen" if op=="enable_omen" and bool(d.get("omen",false)) else op
  var req=request(effective);var deferred=not selected_target(op).is_empty()
  var forecast=req.duplicate(true)
  if deferred:forecast.args={}
  var result:Dictionary=commands.h().preview_forge(commands.game(),forecast) if not req.is_empty() else {"error":"unavailable_drone"}
  var reason=str(result.get("error",""));var costs:Dictionary=result.get("cost",{})
  var name=commands.t("omen_on_action") if effective=="disable_omen" else commands.t("operation_"+op)
  var cost_lines:Array[String]=[]
  for key in costs:cost_lines.append(commands.t(str(key))+" "+str(int(costs[key])))
  var status=commands.t("action_available") if reason.is_empty() else commands.error_text(reason)
  if deferred:status=commands.t("action_guaranteed_cost") if reason.is_empty() else status
  var caption=name+"\n"+(" · ".join(cost_lines) if not cost_lines.is_empty() else commands.t("no_cost") if reason.is_empty() else "—")+"\n"+status
  commands.panel.put(buttons[op],"text",caption);commands.panel.put(buttons[op],"disabled",not reason.is_empty())
func act(op:String) -> void:
 var d:Dictionary=commands.game().profile.hyperspace.inventory.drones.get(commands.panel.selected_id,{})
 var effective="disable_omen" if op=="enable_omen" and bool(d.get("omen",false)) else op
 commands.select_operation(effective)
 var req=request(effective)
 if req.is_empty():return
 var result:Dictionary=commands.h().preview_forge(commands.game(),req)
 if not str(result.error).is_empty():commands.feedback.text=commands.error_text(str(result.error));refresh();return
 commands.quoted_request=req
 if op in CONFIRM or not selected_target(op).is_empty():
  if confirmation==null:
   confirmation=ConfirmationDialog.new();commands.panel.add_child(confirmation);preload("res://scripts/dialog_presentation.gd").dialog(confirmation)
   confirmation.confirmed.connect(commands.execute_quote);confirmation.canceled.connect(func():commands.quoted_request={})
  confirmation.title=commands.t("operation_"+effective)
  var detail=commands.modernization_text(req)+"\n" if effective=="modernize" else ""
  if effective=="promote_affix":detail+=commands.t("promotion_risk_hint")+"\n"
  if effective=="restore_ultimate":detail+=commands.t("restore_modernize_hint")+"\n"
  confirmation.dialog_text=detail+commands.t("quote_result",{"cost":commands.cost_text(result.cost),"draws":str(int(result.get("draws",0)))})
  confirmation.popup_centered(Vector2i(700,370));return
 commands.execute_quote()
