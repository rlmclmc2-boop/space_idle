extends Control
## Persistent section controls; commands remain owned by the hyperspace domain.
const Bag=preload("res://scripts/drone_inventory.gd")
const Codec=preload("res://scripts/hyperspace_filter.gd")
const PAGE_SIZE=8
const FAMILIES={"laser":"pulse","missile":"missile","cannon":"rail","longLaser":"beam"}
const QUALITIES=["white","blue","gold","legendary"]
const KINDS=["none","weapon","quality","minimum_level","affix","legendary_effect"]
const COUNT_AFFIXES=["chain_count","extra_chain_count"]
var host
var manual_adapter: Callable
var manual_ready_provider: Callable
var manual_projection: Dictionary={}
var manual_snapshot_reads=0
var exit_button: Button
var manual_reason: Label
var recent_result: Label
var resource_reference_hint: Label
var crew_adapter: Callable
var hull_capacity_provider: Callable
var preset_adapter: Callable
var affix_catalog_provider: Callable
var affix_display_provider: Callable
var effect_display_provider: Callable
var hanging_display_provider: Callable
var weapon_filter: OptionButton
var quality_filter: OptionButton
var sort_order: OptionButton
var filter_mode: OptionButton
var filter_kinds: Array[OptionButton]=[]
var condition_values: Array[OptionButton]=[]
var condition_levels: Array[SpinBox]=[]
var condition_tiers: Array[OptionButton]=[]
var bag: Dictionary={}
var generation=-1
var round_id=-1
var page=0
var selected_id=""
var list_refreshes=0
var route="alpha"
var section_index=0
var section_buttons: Array[Button]=[]
var sections: Array[Control]=[]
var root_box: VBoxContainer
var inventory_box: VBoxContainer
var scroll: ScrollContainer # Detail scroll only: card pagination and actions stay fixed.
var cards: Array[Button]=[]
var card_icons: Array[TextureRect]=[]
var card_titles: Array[Label]=[]
var card_subtitles: Array[Label]=[]
var card_flags: Array[Label]=[]
var level: SpinBox
var energy: Label
var energy_bar: ProgressBar
var best: Label
var status: Label
var progress: ProgressBar
var start_button: Button
var cancel_queue_button:Button
var queue_departure_hint:Label
var crew_button: Button
var claim_button: Button
var first_win: Label
var capacity: Label
var budgets: Label
var page_label: Label
var previous: Button
var next: Button
var details: Label
var detail_title: Label
var detail_icon: TextureRect
var equip: Button
var favorite: Button
var unseal: Button
var empty: Label
var drone_locked: Label
var totals_summary: Label
var preset_names: Array[LineEdit]=[]
var preset_apply: Array[Button]=[]
var filter_text: TextEdit
var filter_result: Label
var string_dialog: AcceptDialog
var string_button: Button
var forge_title: Label
var forge_details: Label
var forge_icon: TextureRect
var routes: Array[Button]=[]
var commands=preload("res://scripts/hyperspace_commands.gd").new()
var filter_enabled: CheckBox
var filter_action: OptionButton
var filter_save: Button
var dirty=true
var inventory_dirty=true

func t(key: String,params: Dictionary={}) -> String:return UIText.t("hyperspace."+key,params)
func put(control: Object,key: StringName,value: Variant) -> void:
 if control.get(key)!=value:control.set(key,value)
func label(parent: Node,text: String,font_size=22) -> Label:
 var n=Label.new();n.text=text;n.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 n.add_theme_font_size_override("font_size",font_size);n.add_theme_color_override("font_color",Color("243d50"));parent.add_child(n);return n
func button(parent: Node,key: String,action: Callable) -> Button:
 var n=Button.new();n.text=t(key);n.custom_minimum_size=Vector2(116,44)
 preload("res://scripts/dialog_presentation.gd").button_skin(n,false)
 parent.add_child(n);n.pressed.connect(action);return n
func row(parent: Node) -> HBoxContainer:
 var n=HBoxContainer.new();n.add_theme_constant_override("separation",12);parent.add_child(n);return n
func box(parent: Node,separation=12) -> VBoxContainer:
 var n=VBoxContainer.new();n.add_theme_constant_override("separation",separation);n.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(n);return n
func surface(parent: Node) -> VBoxContainer:
 var p=PanelContainer.new();p.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 p.add_theme_stylebox_override("panel",preload("res://scripts/dialog_presentation.gd").surface(Color("e4e8da"),Color("849e9c"),18));parent.add_child(p);return box(p)
func thumbnail(parent: Node,width: float) -> TextureRect:
 var n=TextureRect.new();n.custom_minimum_size=Vector2(width,width);n.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;n.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;n.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(n);return n
func option(parent: Node) -> OptionButton:
 var n=OptionButton.new();n.size_flags_horizontal=Control.SIZE_EXPAND_FILL;preload("res://scripts/dialog_presentation.gd").option(n);parent.add_child(n);return n
func setup(owner) -> void:
 host=owner;commands.setup(self)
 manual_adapter=func(selected_route,selected_level):
  if not host.game.request_hyperspace(selected_route,selected_level):status.text=t("command_failed")
 manual_ready_provider=func():return bool(manual_projection.get("manual_ready",false))
 refresh_manual_status()
 crew_adapter=commands.show_crew
 hull_capacity_provider=func():return host.game.hyperspace.Permission.hull_capacity(host.game,host.game.hyperspace.config)
 preset_adapter=func(index):host.game.hyperspace.apply_preset(host.game,index)
 affix_catalog_provider=func():return host.game.hyperspace.config.affixes.keys()
 theme=preload("res://scripts/dialog_presentation.gd").theme();add_theme_font_override("font",host.font)
 var panel=PanelContainer.new();panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 panel.offset_left=20;panel.offset_right=-20;panel.offset_top=20;panel.offset_bottom=-20
 panel.add_theme_stylebox_override("panel",preload("res://scripts/dialog_presentation.gd").surface());add_child(panel)
 root_box=box(panel,18)
 var heading=label(root_box,t("title"),32);heading.autowrap_mode=TextServer.AUTOWRAP_OFF
 var tabs=row(root_box)
 for key in ["section_explore","section_drones","section_forge","section_rules"]:
  var index=section_buttons.size();var b=button(tabs,key,func():select_section(index));b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;section_buttons.append(b)
 var stack=Control.new();stack.size_flags_vertical=Control.SIZE_EXPAND_FILL;root_box.add_child(stack)
 for i in 4:
  var content=VBoxContainer.new();content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);content.add_theme_constant_override("separation",14);stack.add_child(content);sections.append(content)
 build_exploration(sections[0]);build_inventory(sections[1]);build_forge(sections[2]);build_rules(sections[3])
 host.game.event.connect(on_event);visibility_changed.connect(func():
  if is_visible_in_tree():refresh())
 select_section(0);set_process(true);refresh()
func select_section(index: int) -> void:
 section_index=clampi(index,0,3)
 for i in 4:
  put(sections[i],"visible",i==section_index)
  skin_selection(section_buttons[i],i==section_index)
 if host!=null and not bag.is_empty():refresh()
func build_exploration(parent: Node) -> void:
 label(parent,t("routes"),26)
 var grid=GridContainer.new();grid.columns=2;grid.add_theme_constant_override("h_separation",14);grid.add_theme_constant_override("v_separation",14);parent.add_child(grid)
 for key in host.game.hyperspace.config.routes:
  var b=button(grid,str(key),func():route=str(key);refresh_status());b.text="";b.custom_minimum_size.y=140;b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  var margin=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  for edge in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+edge,14)
  margin.mouse_filter=Control.MOUSE_FILTER_IGNORE;b.add_child(margin)
  var content=row(margin);content.mouse_filter=Control.MOUSE_FILTER_IGNORE
  var config: Dictionary=host.game.hyperspace.config.routes[key];var icon=thumbnail(content,98);icon.texture=load("res://assets/hyperspace/icons/"+FAMILIES[config.weapon]+".png")
  var text=box(content,10);text.mouse_filter=Control.MOUSE_FILTER_IGNORE
  label(text,t(str(key)),25).mouse_filter=Control.MOUSE_FILTER_IGNORE
  label(text,t("route_reward",{"material":t(config.material)}),20).mouse_filter=Control.MOUSE_FILTER_IGNORE
  routes.append(b)
 var levels=row(parent);var title=label(levels,t("level"));title.custom_minimum_size.x=160;title.autowrap_mode=TextServer.AUTOWRAP_OFF
 level=SpinBox.new();level.min_value=5;level.max_value=5;level.step=1;level.custom_minimum_size.x=160;levels.add_child(level);input_skin(level.get_line_edit());level.value_changed.connect(func(_v):refresh_status())
 var summaries=row(parent);var reserve=surface(summaries);var mission=surface(summaries)
 label(reserve,t("energy_heading"),25);energy=label(reserve,"");energy_bar=ProgressBar.new();energy_bar.custom_minimum_size.y=26;energy_bar.show_percentage=false;reserve.add_child(energy_bar);best=label(reserve,"")
 label(mission,t("mission_heading"),25);status=label(mission,"");progress=ProgressBar.new();progress.custom_minimum_size.y=26;progress.show_percentage=false;mission.add_child(progress);claim_button=button(mission,"claim",claim)
 var commands=row(parent);start_button=button(commands,"queue_start",start_manual);cancel_queue_button=button(commands,"queue_cancel",func():host.game.cancel_hyperspace_request();refresh_progress());cancel_queue_button.visible=false;exit_button=button(commands,"exit_manual",func():host.game.begin_retreat();refresh());exit_button.visible=false;crew_button=button(commands,"crew",func():
  if crew_adapter.is_valid():crew_adapter.call())
 queue_departure_hint=label(parent,t("queue_departure_hint"),20);queue_departure_hint.visible=false
 manual_reason=label(parent,"",20)
 recent_result=label(parent,"",20);recent_result.visible=false
 resource_reference_hint=label(parent,"",20);label(parent,t("auto_hint"),20)
 first_win=label(parent,t("first_win"),22)
func build_inventory(parent: Node) -> void:
 capacity=label(parent,"");budgets=label(parent,"")
 drone_locked=label(parent,t("first_win"),24)
 inventory_box=box(parent);inventory_box.size_flags_vertical=Control.SIZE_EXPAND_FILL
 var split=row(inventory_box);split.size_flags_vertical=Control.SIZE_EXPAND_FILL
 var list=box(split);list.size_flags_stretch_ratio=1.55
 var selectors=row(list);weapon_filter=option(selectors);weapon_filter.add_item(t("all"))
 for key in FAMILIES:weapon_filter.add_item(t(key))
 quality_filter=option(selectors);quality_filter.add_item(t("all"))
 for key in QUALITIES:quality_filter.add_item(t(key))
 sort_order=option(selectors)
 for key in ["sort_acquired","sort_level","sort_quality"]:sort_order.add_item(t(key))
 for selector in [weapon_filter,quality_filter,sort_order]:selector.item_selected.connect(func(_i):page=0;refresh_list())
 var grid=GridContainer.new();grid.columns=2;grid.add_theme_constant_override("h_separation",10);grid.add_theme_constant_override("v_separation",10);list.add_child(grid)
 for i in PAGE_SIZE:
  var b=button(grid,"none_selected",func():pass);b.text="";b.custom_minimum_size=Vector2(250,136);b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  var margin=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  for edge in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+edge,10)
  margin.mouse_filter=Control.MOUSE_FILTER_IGNORE;b.add_child(margin)
  var content=row(margin);content.mouse_filter=Control.MOUSE_FILTER_IGNORE;card_icons.append(thumbnail(content,62))
  var text=box(content,3);text.mouse_filter=Control.MOUSE_FILTER_IGNORE
  var title=label(text,"",21);title.mouse_filter=Control.MOUSE_FILTER_IGNORE;card_titles.append(title)
  var quality=label(text,"",19);quality.mouse_filter=Control.MOUSE_FILTER_IGNORE;card_subtitles.append(quality)
  var flags_label=label(text,"",18);flags_label.max_lines_visible=2;flags_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;card_flags.append(flags_label)
  b.pressed.connect(func():selected_id=str(b.get_meta("drone_id",""));commands.configure_operation();refresh_details());cards.append(b)
 empty=label(list,t("no_items"),24)
 var paging=row(list);previous=button(paging,"previous",func():page=maxi(0,page-1);refresh_list());page_label=label(paging,"");page_label.custom_minimum_size.x=120;page_label.autowrap_mode=TextServer.AUTOWRAP_OFF;next=button(paging,"next",func():page+=1;refresh_list())
 var detail=surface(split);detail.custom_minimum_size.x=360;detail.size_flags_vertical=Control.SIZE_EXPAND_FILL
 label(detail,t("selected_heading"),25)
 var title_row=row(detail);detail_icon=thumbnail(title_row,90);detail_title=label(title_row,t("none_selected"),24);detail_title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 var actions=GridContainer.new();actions.columns=2;actions.add_theme_constant_override("h_separation",8);actions.add_theme_constant_override("v_separation",8);detail.add_child(actions)
 equip=button(actions,"equip",toggle_equipped);favorite=button(actions,"favorite_action",toggle_favorite);unseal=button(actions,"unseal",func():host.game.hyperspace.claim_sealed(host.game,selected_id));button(actions,"section_forge",func():select_section(2));button(actions,"module_manage",commands.show_modules)
 scroll=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;detail.add_child(scroll)
 details=label(scroll,t("choose"),21);details.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 totals_summary=label(detail,"",19);button(detail,"totals_manage",commands.show_totals)
func build_forge(parent: Node) -> void:
 var selected=surface(parent);label(selected,t("forge_selected"),25)
 var selected_row=row(selected);forge_icon=thumbnail(selected_row,110);var text=box(selected_row);forge_title=label(text,t("none_selected"),26);forge_details=label(text,t("choose"),21)
 button(selected,"go_warehouse",func():select_section(1))
 commands.build_forge(parent)
func build_rules(parent: Node) -> void:
 label(parent,t("presets"),25)
 for index in 3:
  var pr=row(parent);var name_field=LineEdit.new();name_field.placeholder_text=t("preset_name");name_field.max_length=96;input_skin(name_field);name_field.size_flags_horizontal=Control.SIZE_EXPAND_FILL;pr.add_child(name_field);preset_names.append(name_field)
  button(pr,"save_preset",func():host.game.hyperspace.set_preset(host.game,index,name_field.text,bag.equipped))
  var apply=button(pr,"apply_preset",func():
   if preset_adapter.is_valid():preset_adapter.call(index))
  preset_apply.append(apply);button(pr,"clear_preset",func():host.game.hyperspace.clear_preset(host.game,index))
 label(parent,t("filter"),25);label(parent,t("filter_domain_hint"),20)
 var modes=row(parent);filter_mode=option(modes);filter_mode.add_item(t("filter_and"));filter_mode.add_item(t("filter_or"));string_button=button(modes,"string_tools",show_strings)
 var policy=row(parent);filter_enabled=CheckBox.new();filter_enabled.text=t("filter_auto");policy.add_child(filter_enabled);checkbox_skin(filter_enabled);filter_action=option(policy)
 for action in ["keep_matches","clear_matches"]:filter_action.add_item(t("filter_action_"+action));filter_action.set_item_metadata(filter_action.item_count-1,action)
 for i in 5:
  var fr=row(parent);var kind=option(fr);kind.custom_minimum_size.x=175
  for key in KINDS:kind.add_item(t("condition_"+key));kind.set_item_metadata(kind.item_count-1,key)
  filter_kinds.append(kind)
  var value=option(fr);value.custom_minimum_size.x=230;condition_values.append(value)
  var lev=SpinBox.new();lev.min_value=0;lev.max_value=1000000;lev.allow_greater=true;lev.step=1;lev.custom_minimum_size.x=230;input_skin(lev.get_line_edit());fr.add_child(lev);condition_levels.append(lev)
  var tier=option(fr)
  for n in range(1,6):tier.add_item(t("condition_tier",{"tier":str(n)}))
  condition_tiers.append(tier)
  kind.item_selected.connect(func(_n):configure_condition(i));configure_condition(i)
 var rule_actions=row(parent);button(rule_actions,"filter_preview",build_filter_draft);filter_save=button(rule_actions,"filter_save",save_filter);filter_result=label(parent,t("rule_none"),22)
 string_dialog=AcceptDialog.new();string_dialog.title=t("string_title");string_dialog.min_size=Vector2i(750,480);string_dialog.size=Vector2i(860,520);add_child(string_dialog);preload("res://scripts/dialog_presentation.gd").dialog(string_dialog)
 var dialog_content=VBoxContainer.new();string_dialog.add_child(dialog_content);dialog_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);dialog_content.offset_left=20;dialog_content.offset_right=-20;dialog_content.offset_top=20;dialog_content.offset_bottom=-60
 filter_text=TextEdit.new();input_skin(filter_text);filter_text.size_flags_vertical=Control.SIZE_EXPAND_FILL;filter_text.text=Codec.export_string(host.game.profile.hyperspace.filter,host.game.hyperspace.config);dialog_content.add_child(filter_text)
 var actions=row(dialog_content);button(actions,"string_import",import_filter_draft);button(actions,"string_copy",func():
  var parsed=Codec.import_string(filter_text.text,host.game.hyperspace.config)
  if valid_draft(parsed):DisplayServer.clipboard_set(filter_text.text))
func affix_catalog() -> Array:
 return affix_catalog_provider.call() if affix_catalog_provider.is_valid() else []
func configure_condition(index: int) -> void:
 var kind=str(filter_kinds[index].get_item_metadata(filter_kinds[index].selected));var value=condition_values[index];value.clear();put(condition_levels[index],"visible",kind=="minimum_level");put(condition_tiers[index],"visible",kind=="affix");put(value,"visible",kind!="minimum_level")
 var keys: Array=[]
 if kind=="weapon":keys=FAMILIES.keys()
 elif kind=="quality":keys=QUALITIES+["ultimate"]
 elif kind=="legendary_effect":keys=host.game.hyperspace.config.legendary_effects.keys()
 elif kind=="affix":keys=affix_catalog()
 for key in keys:
  var name=t(str(key)) if kind in ["weapon","quality"] else effect_name(str(key)) if kind=="legendary_effect" else affix_name(str(key))
  value.add_item(name);value.set_item_metadata(value.item_count-1,key)
 if keys.is_empty():value.add_item(t("affix_catalog_wait") if kind=="affix" else t("condition_none"))
 value.disabled=keys.is_empty()
func show_strings() -> void:
 build_filter_draft()
 string_dialog.popup_centered(Vector2i(860,520))
func valid_draft(rule: Dictionary) -> bool:
 return not rule.is_empty() and rule.get("action","") in ["keep_matches","clear_matches"] and Codec.valid(rule,host.game.hyperspace.config)
func import_filter_draft() -> void:
 var rule=Codec.import_string(filter_text.text,host.game.hyperspace.config)
 if not valid_draft(rule):preview_filter();return
 filter_mode.select(0 if rule.mode=="all" else 1);filter_enabled.button_pressed=rule.enabled;filter_action.select(0 if rule.action=="keep_matches" else 1)
 for i in 5:
  var condition:Dictionary=rule.conditions[i] if i<rule.conditions.size() else {"field":"none"}
  filter_kinds[i].select(KINDS.find(condition.field));configure_condition(i)
  if condition.field=="minimum_level":condition_levels[i].value=condition.value
  elif condition.field!="none":
   var target=condition.key if condition.field=="affix" else condition.value
   for n in condition_values[i].item_count:
    if condition_values[i].get_item_metadata(n)==target:condition_values[i].select(n);break
   if condition.field=="affix":condition_tiers[i].select(int(condition.tier)-1)
 preview_filter();string_dialog.hide()
func save_filter() -> void:
 build_filter_draft()
 var rule=Codec.import_string(filter_text.text,host.game.hyperspace.config)
 if valid_draft(rule) and host.game.hyperspace.set_filter(host.game,rule):filter_result.text=t("filter_saved")
 else:filter_result.text=t("command_failed")
func on_event(kind: String,_payload: Dictionary) -> void:
 if kind in ["hyperspace_changed","hyperspace_queue","unlocks_changed","ship_changed","hyperspace_rebuild","state"]:
  dirty=true
  if commands.totals_dialog!=null and commands.totals_dialog.visible:commands.refresh_totals()
  host.refresh_hyperspace_badge()
func _process(_delta: float) -> void:
 if not is_visible_in_tree():return
 if dirty:refresh()
 if section_index==0:refresh_progress()
func refresh() -> void:
 if host==null or not is_visible_in_tree():return
 var s: Dictionary=host.game.profile.hyperspace
 if generation!=int(s.inventory.generation) or round_id!=int(s.round_id) or bag.is_empty():
  refresh_manual_status()
 elif dirty and bag.presets!=s.inventory.presets:
  bag.presets=s.inventory.presets.duplicate(true);inventory_dirty=true
 if section_index==0:
  put(first_win,"visible",not bool(s.unlocked_drones));refresh_status();refresh_progress()
 elif section_index==1:
  put(inventory_box,"visible",bool(s.unlocked_drones));put(drone_locked,"visible",not bool(s.unlocked_drones))
  if inventory_dirty:refresh_list()
  else:refresh_details()
 elif section_index==2:refresh_details()
 elif section_index==3:
  for i in 3:
   put(preset_apply[i],"disabled",not preset_adapter.is_valid() or i>=bag.presets.size())
   if i<bag.presets.size() and not preset_names[i].has_focus():put(preset_names[i],"text",str(bag.presets[i].name))
 dirty=false
func refresh_status() -> void:
 if host==null:return
 var g=host.game;var h=g.hyperspace;var s: Dictionary=g.profile.hyperspace
 put(level,"max_value",maxi(5,int(g.profile.highestLevel)))
 put(resource_reference_hint,"text",t("resource_reference_hint",{"level":str(int(level.value)),"cleared":str(preload("res://scripts/hyperspace_reward_binding.gd").latest_cleared_level(g))}))
 var ticket=display_ticket(s)
 put(energy,"text",t("energy",{"current":"%.0f"%float(s.energy),"cap":"%.0f"%float(h.online_config(g).energy_cap),"ticket":"%.0f"%ticket}))
 var best_time=float(h.best_x1(g,route,int(level.value)))
 put(best,"text",t("best",{"time":"%.2f s"%best_time if best_time>0 else t("none")}))
 refresh_start_reason()
 put(crew_button,"disabled",not crew_adapter.is_valid());put(crew_button,"tooltip_text","" if crew_adapter.is_valid() else t("adapter"))

 for i in routes.size():skin_selection(routes[i],str(h.config.routes.keys()[i])==route)
func refresh_start_reason() -> void:
 var reason=""
 var g=host.game;var h=g.hyperspace;var s:Dictionary=g.profile.hyperspace
 if not manual_ready():reason=manual_error_text()
 elif not g.manual_hyperspace.queued.is_empty():reason=t("queue_already")
 elif not s.active.is_empty():reason=t("manual_busy")
 elif not h.eligible_level(g,route,int(level.value)):reason=t("manual_level_unavailable")
 elif float(s.energy)<float(h.config.ticket):reason=t("manual_energy_needed",{"ticket":"%.0f"%float(h.config.ticket)})
 var explanation=reason
 if reason.is_empty() and g.manual_hyperspace.queue_error=="invalid_main_return":explanation=t("queue_failed_invalid_main_return")
 put(start_button,"disabled",not reason.is_empty());put(start_button,"tooltip_text",explanation)
 put(manual_reason,"visible",not explanation.is_empty());put(manual_reason,"text",explanation)
func display_ticket(s: Dictionary) -> float:
 if not s.active.is_empty():return float(s.active.ticket)
 var h=host.game.hyperspace
 if s.auto.enabled:return float(h.config.ticket)*20.0/(20.0+h.Permission.crew_level(host.game,str(s.auto.crew_id)))
 return float(h.config.ticket)
func refresh_progress() -> void:
 var s: Dictionary=host.game.profile.hyperspace;var a: Dictionary=s.active
 var text=t("auto_waiting") if s.auto.enabled else t("auto_stopped");var fill=0.0
 var effective=host.game.hyperspace.online_config(host.game)
 if s.auto.enabled and a.is_empty():
  if s.blocked:text=t("auto_waiting_warehouse")
  elif host.game.hyperspace.auto_eligible(host.game) and float(s.energy)<float(effective.energy_cap):text=t("auto_waiting_energy")
 var session=host.game.manual_hyperspace
 var result:Dictionary=session.last_result
 put(recent_result,"visible",not result.is_empty())
 if result.get("reason","")=="interrupted_reload":
  put(recent_result,"text",t("recent_interrupted_refund",{"weapon":t(host.game.hyperspace.config.routes[result.route].weapon),"level":str(result.level),"refund":"%.0f"%float(result.refund)}))
 elif not result.is_empty():
  put(recent_result,"text",t("recent_result",{"weapon":t(host.game.hyperspace.config.routes[result.route].weapon),"level":str(result.level),"reason":t("result_"+str(result.reason)),"elapsed":"%.1f"%float(result.elapsed),"point":str(result.end_point),"refund":"%.0f"%float(result.refund),"stage":str(result.return_stage),"main_point":str(result.return_point)}))
 put(cancel_queue_button,"visible",not session.queued.is_empty())
 put(queue_departure_hint,"visible",not session.queued.is_empty())
 if not session.queued.is_empty():
  var waiting=session.boundary_reason(host.game)
  text=t("queue_wait",{"weapon":t(host.game.hyperspace.config.routes[session.queued.route].weapon),"level":str(int(session.queued.level)),"reason":t("queue_wait_"+waiting) if waiting in ["battle","guard","unlock","projectiles"] else t("queue_wait_ready")})
 elif not session.queue_error.is_empty():text=t("queue_failed_"+session.queue_error) if session.queue_error in ["energy","busy","unavailable","round_changed","reload","invalid_main_return","setup_failed"] else t("command_failed")
 if not a.is_empty():
  if a.status=="completed_pending":text=t("blocked") if s.blocked else t("pending");fill=100.0
  elif a.mode=="auto":
   fill=100.0*float(a.work)/maxf(0.001,float(a.duration));text=t("progress",{"work":"%.1f"%float(a.work),"duration":"%.1f"%float(a.duration)})
  else:text=t("manual")
  if not session.queue_error.is_empty():text+="\n"+(t("queue_failed_"+session.queue_error) if session.queue_error in ["energy","busy","unavailable","round_changed","reload","invalid_main_return","setup_failed"] else t("command_failed"))
 put(status,"text",text);put(status,"modulate",Color("ff7979") if (s.blocked and s.auto.enabled) or (not a.is_empty() and a.status=="completed_pending") else Color("243d50"));put(progress,"value",fill)
 put(claim_button,"disabled",a.is_empty() or a.get("status")!="completed_pending")
 put(exit_button,"visible",host.game.manual_hyperspace.active)
 refresh_start_reason()
 # Energy is a scalar read: never duplicate the entire inventory in a frame update.
 put(energy_bar,"max_value",float(effective.energy_cap));put(energy_bar,"value",minf(float(s.energy),float(effective.energy_cap)))
 var ticket=display_ticket(s)
 put(energy,"text",t("energy",{"current":"%.0f"%float(s.energy),"cap":"%.0f"%float(effective.energy_cap),"ticket":"%.0f"%ticket}))
func refresh_list() -> void:
 list_refreshes+=1
 var ids: Array=bag.warehouse+bag.overflow
 if weapon_filter.selected>0:ids=ids.filter(func(id):return bag.drones[id].weapon==FAMILIES.keys()[weapon_filter.selected-1])
 if quality_filter.selected>0:ids=ids.filter(func(id):return bag.drones[id].origin_quality==["white","blue","gold","legendary"][quality_filter.selected-1])
 if sort_order.selected==1:ids.sort_custom(func(a,b):return int(bag.drones[a].level)>int(bag.drones[b].level))
 if sort_order.selected==2:ids.sort_custom(func(a,b):return ["white","blue","gold","legendary"].find(bag.drones[a].origin_quality)>["white","blue","gold","legendary"].find(bag.drones[b].origin_quality))
 var pages=maxi(1,ceili(float(ids.size())/PAGE_SIZE));page=clampi(page,0,pages-1)
 for i in PAGE_SIZE:
  var index=page*PAGE_SIZE+i;var b=cards[i];put(b,"visible",index<ids.size())
  if index>=ids.size():continue
  var id=str(ids[index]);var d: Dictionary=bag.drones[id];b.set_meta("drone_id",id)
  put(card_icons[i],"texture",load("res://assets/hyperspace/icons/"+FAMILIES[d.weapon]+".png"))
  put(card_titles[i],"text",t("card",{"weapon":t(d.weapon),"level":str(int(d.level)),"quality":"","flags":""}).split("\n")[0])
  put(card_subtitles[i],"text",t(d.origin_quality))
  put(card_flags[i],"text",flags(id,d) if not flags(id,d).is_empty() else t("no_flags"))
  skin_selection(b,id==selected_id)
 put(empty,"visible",ids.is_empty())
 inventory_dirty=false
 put(previous,"disabled",page==0);put(next,"disabled",page==pages-1);put(page_label,"text",t("page",{"page":str(page+1),"pages":str(pages)}))
 put(capacity,"text",t("capacity",{"used":str(bag.warehouse.size()),"cap":str(Bag.capacity(bag,host.game.hyperspace.config)),"overflow":str(bag.overflow.size()),"retention":str(Bag.retention_capacity(bag,host.game.hyperspace.config))}))
 var legendary=0;var ultimate=0
 for id in bag.equipped:
  legendary+=int(bag.drones[id].legendary);ultimate+=int(bag.drones[id].ultimate)
 var cap_text=str(hull_capacity_provider.call()) if hull_capacity_provider.is_valid() else "?"
 put(budgets,"text",t("budgets",{"equipped":str(bag.equipped.size()),"cap":cap_text,"legendary":str(legendary),"ultimate":str(ultimate)}));refresh_details()
func flags(id: String,d: Dictionary) -> String:
 var names: Array[String]=[]
 if d.legendary:names.append(t("legendary"))
 if d.ultimate:names.append(t("ultimate"))
 var protection=protection_flags(id)
 if not protection.is_empty():names.append(protection)
 return " · ".join(names)
func protection_flags(id: String) -> String:
 var names: Array[String]=[]
 if bag.equipped.has(id):names.append(t("equipped"))
 if bag.favorites.has(id):names.append(t("favorite"))
 if bag.sealed.has(id):names.append(t("sealed"))
 for p in bag.presets:
  if p.drone_ids.has(id):names.append(t("preset"));break
 return " · ".join(names)
func refresh_details() -> void:
 if bag.is_empty():return
 var valid=bag.drones.has(selected_id)
 if section_index==2:
  put(forge_title,"text",t("none_selected") if not valid else t("card",{"weapon":t(bag.drones[selected_id].weapon),"level":str(int(bag.drones[selected_id].level)),"quality":t(bag.drones[selected_id].origin_quality),"flags":flags(selected_id,bag.drones[selected_id])}))
  put(forge_details,"text",t("choose") if not valid else t("forge_summary",{"affixes":str(bag.drones[selected_id].affixes.size()),"slots":str(int(bag.drones[selected_id].hanging_slots)),"revision":str(int(bag.drones[selected_id].forge_revision))}))
  put(forge_icon,"texture",load("res://assets/hyperspace/icons/"+FAMILIES[bag.drones[selected_id].weapon]+".png") if valid else null)
  return
 if section_index!=1:return
 put(equip,"disabled",not valid or not hull_capacity_provider.is_valid() or bag.sealed.has(selected_id) or bag.overflow.has(selected_id))
 put(favorite,"disabled",not valid)
 var gate=int(bag.sealed.get(selected_id,0))
 put(unseal,"disabled",not valid or gate<1 or int(host.game.profile.highestLevel)<gate)
 put(unseal,"tooltip_text",t("sealed_gate",{"level":str(gate)}) if gate>0 else "")
 var totals:Dictionary=host.game.hyperspace_totals()
 put(totals_summary,"text",t("totals_summary",{"affixes":str(totals.affixes.size()),"hangings":str(totals.hangings.size()),"damage":"%.1f"%((float(totals.damage)-1.0)*100.0)}))
 put(details,"text",t("choose") if not valid else drone_description(bag.drones[selected_id]))
 put(detail_title,"text",t("none_selected") if not valid else t("card",{"weapon":t(bag.drones[selected_id].weapon),"level":str(int(bag.drones[selected_id].level)),"quality":t(bag.drones[selected_id].origin_quality),"flags":""}))
 put(detail_icon,"texture",load("res://assets/hyperspace/icons/"+FAMILIES[bag.drones[selected_id].weapon]+".png") if valid else null)
 for b in cards:skin_selection(b,b.get_meta("drone_id","")==selected_id)
func drone_description(d: Dictionary) -> String:
 var protection=protection_flags(str(d.id))
 var lines: Array[String]=[t("protect",{"flags":protection if not protection.is_empty() else t("unprotected")})]
 if bag.sealed.has(str(d.id)):lines.append(t("sealed_gate",{"level":str(int(bag.sealed[str(d.id)]))}))
 for a in d.affixes+([d.ultimate_affix] if not d.ultimate_affix.is_empty() else []):
  var key=str(a.key);var name_text=affix_name(key);var value_text=t("times",{"value":str(int(a.value))}) if key in COUNT_AFFIXES else t("percent",{"value":"%.1f"%(float(a.value)*100.0)})
  if affix_display_provider.is_valid():
   var projection=affix_display_provider.call(a.duplicate(true),d.duplicate(true))
   if projection is Dictionary:
    value_text=str(projection.get("value_text",value_text));name_text=str(projection.get("name",name_text))
  lines.append(t("affix",{"key":name_text,"tier":str(int(a.tier)),"value":value_text,"locked":t("locked") if a.locked else ""}))
 if d.legendary:
  var effect:Dictionary=d.legendary_effect
  lines.append(effect_name(str(effect.get("effect_id",""))))
  for parameter in effect.get("parameters",{}):lines.append(t("effect_parameter_"+str(parameter))+": "+t("percent",{"value":"%.1f"%(float(effect.parameters[parameter])*100.0)}))
 var hangings: Array[String]=[]
 for key in d.hangings:hangings.append(hanging_name(str(key)))
 lines.append(t("hanging",{"items":" · ".join(hangings) if not hangings.is_empty() else t("no_hangings")}))
 return "\n".join(lines)
func catalog_name(group: String,key: String,fallback: String) -> String:
 if not UIText.loaded:UIText.reload_catalog()
 var bindings:Dictionary=UIText.bindings.get(group,{})
 if bindings.has(key):return UIText.t(str(bindings[key].get("name","")))
 for binding in bindings.values():
  if key==UIText.t(str(binding.get("name",""))):return key
 return t(fallback)
func affix_name(key: String) -> String:
 return catalog_name("hyperspace_affixes",key,"unknown_affix")
func effect_name(key: String) -> String:
 if effect_display_provider.is_valid():return str(effect_display_provider.call(key))
 return catalog_name("hyperspace_legendary_effects",key,"unknown_effect")
func hanging_name(key: String) -> String:
 if hanging_display_provider.is_valid():return str(hanging_display_provider.call(key))
 return catalog_name("hyperspace_hangings",key,"unknown_hanging")
func toggle_equipped() -> void:
 if not hull_capacity_provider.is_valid():return
 var ids: Array=bag.equipped.duplicate()
 if ids.has(selected_id):ids.erase(selected_id)
 else:ids.append(selected_id)
 host.game.hyperspace.set_equipped(host.game,ids,int(hull_capacity_provider.call()))
func toggle_favorite() -> void:
 var ids: Array=bag.favorites.duplicate()
 if ids.has(selected_id):ids.erase(selected_id)
 else:ids.append(selected_id)
 host.game.hyperspace.set_favorites(host.game,ids)
func claim() -> void:
 var a: Dictionary=host.game.profile.hyperspace.active
 if not a.is_empty():host.game.hyperspace.claim(host.game,int(a.round_id),int(a.run_id))
func refresh_manual_status() -> void:
 # A route load/reload or inventory generation boundary may refresh this snapshot; progress never does.
 var projection:Dictionary=host.game.hyperspace.snapshot(host.game);manual_snapshot_reads+=1
 manual_projection={"manual_ready":projection.manual_ready,"manual_error":projection.manual_error}
 if generation!=int(projection.inventory.generation) or round_id!=int(projection.round_id) or bag.is_empty():
  bag=projection.inventory;generation=int(bag.generation);round_id=int(projection.round_id);inventory_dirty=true
 dirty=true
func manual_error_text() -> String:
 return t("manual_review_wait") if manual_projection.get("manual_error")=="space_data_not_accepted" else t("manual_not_ready")
func manual_ready() -> bool:
 return manual_adapter.is_valid() and manual_ready_provider.is_valid() and manual_ready_provider.call()
func start_manual() -> void:
 # The formal session validates route groups before it charges a ticket.
 if manual_ready():manual_adapter.call(route,int(level.value))
func preview_filter() -> void:
 var rule=Codec.import_string(filter_text.text,host.game.hyperspace.config)
 put(filter_result,"text",t("filter_valid",{"count":str(rule.conditions.size()),"mode":t("filter_and") if rule.mode=="all" else t("filter_or")}) if valid_draft(rule) else t("filter_string_invalid"))
func build_filter_draft() -> void:
 var conditions: Array=[]
 for i in 5:
  var kind=str(filter_kinds[i].get_item_metadata(filter_kinds[i].selected))
  if kind=="none":continue
  if kind=="affix":conditions.append({"field":kind,"key":condition_values[i].get_item_metadata(condition_values[i].selected),"tier":condition_tiers[i].selected+1})
  else:conditions.append({"field":kind,"value":int(condition_levels[i].value) if kind=="minimum_level" else condition_values[i].get_item_metadata(condition_values[i].selected)})
 var rule={"version":host.game.profile.hyperspace.filter.version,"enabled":filter_enabled.button_pressed,"mode":"all" if filter_mode.selected==0 else "any","action":filter_action.get_item_metadata(filter_action.selected),"conditions":conditions}
 filter_text.text=Codec.export_string(rule,host.game.hyperspace.config);preview_filter()
func input_skin(field: Control) -> void:
 field.add_theme_color_override("font_color",Color("243d50"))
 field.add_theme_color_override("font_placeholder_color",Color("637782"))
 for state in ["normal","focus","read_only"]:field.add_theme_stylebox_override(state,preload("res://scripts/dialog_presentation.gd").surface(Color("ecebdc"),Color("243d50"),6))

func skin_selection(control: Button,selected: bool) -> void:
 if not control.has_meta("hyperspace_selected") or bool(control.get_meta("hyperspace_selected"))!=selected:
  control.set_meta("hyperspace_selected",selected)
  preload("res://scripts/dialog_presentation.gd").button_skin(control,selected)

func checkbox_skin(control: CheckBox) -> void:
 for key in ["font_color","font_pressed_color","font_hover_color","font_hover_pressed_color","font_focus_color"]:control.add_theme_color_override(key,Color("243d50"))
 control.add_theme_color_override("font_disabled_color",Color("637782"))
