extends RefCounted
## UI command controller. Domain previews own all prices and randomness.
const OPERATIONS=["add_affix","replace_affix","add_hanging_slot","lock_affix","promote_affix","reroll_values","enable_omen","disable_omen","legendary","modernize","ultimate","restore_ultimate","dismantle"]
var panel
var operation: OptionButton
var guarantee: OptionButton
var maximum: CheckBox
var quote_label: Label
var commit_button: Button
var feedback: Label
var promotion_hint: Label
var quoted_request: Dictionary={}
var crew_dialog: AcceptDialog
var crew_choice: OptionButton
var crew_info: Label
var crew_enable: Button
var module_dialog: AcceptDialog
var module_choices: Array[CheckBox]=[]
var module_id=""
var collection_dialog: AcceptDialog
var collection_choices: Array[CheckBox]=[]
var totals_dialog: AcceptDialog
var totals_label: Label
var dismantle_dialog: ConfirmationDialog
func setup(p) -> void:
 panel=p
func t(key: String,params: Dictionary={}) -> String:return panel.t(key,params)
func game():return panel.host.game
func h():return game().hyperspace
func build_forge(parent: Node) -> void:
 var controls=panel.row(parent);operation=panel.option(controls)
 for key in OPERATIONS:operation.add_item(t("operation_"+key));operation.set_item_metadata(operation.item_count-1,key)
 guarantee=panel.option(controls);maximum=CheckBox.new();maximum.text=t("guaranteed_max");controls.add_child(maximum);panel.checkbox_skin(maximum)
 operation.item_selected.connect(func(_n):configure_operation());guarantee.item_selected.connect(func(_n):invalidate());maximum.toggled.connect(func(_v):invalidate())
 var actions=panel.row(parent);panel.button(actions,"quote",preview);panel.button(actions,"collection_manage",show_collection);commit_button=panel.button(actions,"commit_forge",commit);commit_button.disabled=true
 promotion_hint=panel.label(parent,t("promotion_risk_hint"),21)
 quote_label=panel.label(parent,t("quote_first"),21);feedback=panel.label(parent,"",21)
 configure_operation()
func invalidate() -> void:
 quoted_request={};commit_button.disabled=true;quote_label.text=t("quote_first");feedback.text=""
func configure_operation() -> void:
 invalidate();guarantee.clear();guarantee.add_item(t("random_choice"));guarantee.set_item_metadata(0,"")
 var op=str(operation.get_item_metadata(operation.selected));guarantee.visible=op in ["replace_affix","legendary"];maximum.visible=op=="reroll_values"
 promotion_hint.visible=op=="promote_affix"
 var d: Dictionary=panel.bag.get("drones",{}).get(panel.selected_id,{})
 if d.is_empty():return
 var keys: Array=h().config.affixes.keys() if op=="replace_affix" else game().profile.hyperspace.legendary_collection
 for key in keys:
  var entry: Dictionary=h().config.affixes[key] if op=="replace_affix" else h().config.legendary_effects[key]
  if not entry.weapon.is_empty() and entry.weapon!=d.weapon:continue
  guarantee.add_item(panel.affix_name(key) if op=="replace_affix" else panel.effect_name(key));guarantee.set_item_metadata(guarantee.item_count-1,key)
func request() -> Dictionary:
 var s: Dictionary=game().profile.hyperspace;var d: Dictionary=s.inventory.drones.get(panel.selected_id,{})
 if d.is_empty():return {}
 var op=str(operation.get_item_metadata(operation.selected));var args: Dictionary={}
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
func preview() -> void:
 quoted_request=request()
 if quoted_request.is_empty():feedback.text=t("choose");return
 var result: Dictionary=h().preview_forge(game(),quoted_request)
 quote_label.text=t("quote_execution_result",{"cost":cost_text(result.get("cost",{})),"count":str(int(result.get("draws",0)))}) if quoted_request.operation=="modernize" else t("quote_result",{"cost":cost_text(result.get("cost",{})),"draws":str(int(result.get("draws",0)))})
 if quoted_request.operation=="modernize":quote_label.text=modernization_text(quoted_request)+"\n"+quote_label.text
 feedback.text=error_text(result.error) if not str(result.error).is_empty() else t("quote_ready")
 commit_button.disabled=not str(result.error).is_empty()
func commit() -> void:
 if quoted_request.is_empty():return
 if quoted_request.operation=="dismantle":
  if dismantle_dialog==null:
   dismantle_dialog=ConfirmationDialog.new();dismantle_dialog.dialog_text=t("dismantle_confirm");panel.add_child(dismantle_dialog);preload("res://scripts/dialog_presentation.gd").dialog(dismantle_dialog);dismantle_dialog.confirmed.connect(execute_quote)
  dismantle_dialog.popup_centered();return
 execute_quote()
func execute_quote() -> void:
 if quoted_request.is_empty():return
 # Keep the preview receipt unchanged. Never refresh command sequence under a stale quote.
 var result: Dictionary=h().forge(game(),quoted_request)
 commit_button.disabled=true;quoted_request={};quote_label.text=t("quote_first")
 if str(result.error).is_empty() and result.get("applied",false):quote_label.text=t("forge_paid_summary",{"cost":cost_text(result.get("cost",{}))})
 feedback.text=error_text(result.error) if not str(result.error).is_empty() else t("forge_done") if result.get("outcome",true) else t("forge_attempt_failed")
 panel.dirty=true;panel.refresh()
func build_dialog(title: String) -> AcceptDialog:
 var dialog=AcceptDialog.new();dialog.title=t(title);dialog.min_size=Vector2i(660,370);dialog.size=Vector2i(740,470);panel.add_child(dialog);preload("res://scripts/dialog_presentation.gd").dialog(dialog)
 return dialog
func content(dialog: AcceptDialog) -> VBoxContainer:
 var box=panel.box(dialog);box.custom_minimum_size=Vector2(680,250);return box
# Set wrap mode before attaching: a transient zero-width label can enlarge a native popup.
func dialog_label(parent: Node,text: String,font_size: int) -> Label:
 var result=Label.new();result.text=text;result.autowrap_mode=TextServer.AUTOWRAP_OFF;result.add_theme_font_size_override("font_size",font_size);result.add_theme_color_override("font_color",Color("243d50"));parent.add_child(result);return result
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
 var ticket=float(h().config.ticket)*20.0/(20.0+lv);var duration=maxf(float(h().config.minimum_duration),best*100.0/(100.0+lv))
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
 dialog_label(body,t("module_slots",{"used":str(d.hangings.size()),"cap":str(d.hanging_slots)}),22)
 for key in h().config.hanging_modules:
  var progress: Dictionary=game().profile.hyperspace.hanging_modules[key];var choice=CheckBox.new();choice.text=t("module_choice",{"name":panel.hanging_name(key),"level":str(progress.level),"exp":"%.0f"%float(progress.exp)});choice.set_meta("module_key",key);choice.button_pressed=d.hangings.has(key);choice.disabled=not progress.unlocked or int(game().profile.highestLevel)<int(h().config.hanging_modules[key].unlock_stage);body.add_child(choice);panel.checkbox_skin(choice);module_choices.append(choice)
 panel.button(body,"module_apply",func():
  var keys: Array=[]
  for choice in module_choices:
   if choice.button_pressed:keys.append(choice.get_meta("module_key"))
  if h().attach_hangings(game(),module_id,keys):module_dialog.hide()
  else:module_dialog.title=t("module_rejected"))
 dialog_label(body,t("reforge_module_reset"),18)
 module_dialog.popup_centered(Vector2i(740,510))

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
  totals_dialog=build_dialog("totals_manage");var body=content(totals_dialog);var sc=ScrollContainer.new();sc.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_child(sc);totals_label=dialog_label(sc,"",21)
 refresh_totals();totals_dialog.popup_centered(Vector2i(740,510))
func refresh_totals() -> void:
 if totals_label==null:return
 var totals:Dictionary=game().hyperspace_totals();var lines:Array[String]=[t("totals_authority")]
 for key in ["damage","critical_chance","critical_damage","repeat_chance","attack_speed","defence","armour","shield"]:
  var value=float(totals[key]);var additive=value if key in ["critical_chance","repeat_chance"] else value-1.0
  lines.append(t("total_"+key)+": "+t("percent",{"value":"%.1f"%(additive*100.0)}))
 lines.append(t("total_chain_count")+": "+t("times",{"value":str(int(totals.chain_count))}))
 for weapon in totals.weapon_damage:lines.append(t("total_weapon",{"weapon":t(weapon)})+": "+t("percent",{"value":"%.1f"%((float(totals.weapon_damage[weapon])-1.0)*100.0)}))
 lines.append(t("total_hangings"))
 for key in totals.hangings:lines.append(panel.hanging_name(key)+": "+t("percent",{"value":"%.1f"%(float(totals.hangings[key])*100.0)}))
 if totals.hangings.is_empty():lines.append(t("no_hangings"))
 lines.append(t("total_legendary"))
 for key in totals.legendary:
  lines.append(panel.effect_name(key))
  for parameter in totals.legendary[key].parameters:lines.append("  "+t("effect_parameter_"+str(parameter))+": "+t("percent",{"value":"%.1f"%(float(totals.legendary[key].parameters[parameter])*100.0)}))
 if totals.legendary.is_empty():lines.append(t("no_active_legendary"))
 totals_label.text="\n".join(lines)
