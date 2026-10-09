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
var reward_feedback=preload("res://scripts/hyperspace_reward_feedback.gd").new()
var route_ui=preload("res://scripts/hyperspace_route_ui.gd").new()
var equipment_ui=preload("res://scripts/hyperspace_equipment_ui.gd").new()
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
var card_style_cache: Dictionary={}
var generation=-1
var round_id=-1
var page=0
var selected_id=""
var list_refreshes=0
var route="alpha"
var section_index=0
var section_buttons: Array[Button]=[]
var sections: Array[Control]=[]
var exploration_scroll: ScrollContainer
var forge_scroll: ScrollContainer
var forge_content: VBoxContainer
var challenge_result_area: VBoxContainer
var exploration_receipt_area: VBoxContainer
var root_box: VBoxContainer
var inventory_box: VBoxContainer
var scroll: ScrollContainer # Detail scroll only: card pagination and actions stay fixed.
var cards: Array[Button]=[]
var module_manage: Button
var card_icons: Array[TextureRect]=[]
var card_titles: Array[Label]=[]
var card_subtitles: Array[Label]=[]
var card_flags: Array[Label]=[]
var disabled_snapshot:Array=[]
var level: SpinBox
var level_choice_hint: Label
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
var legendary_help=preload("res://scripts/hyperspace_legendary_help.gd").new()
var legendary_group: VBoxContainer
var legendary_button: Button
var legendary_summary: Label
var forge_legendary_button: Button
var dismantle_button: Button
var inventory_feedback: Label
var forge_pick_cancel: Button
var forge_pick_state: Dictionary={}
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
var route_markers:Array[Label]=[]
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
func button(parent: Node,key: String,action: Callable,params:Dictionary={}) -> Button:
 var n=Button.new();n.text=t(key,params);n.custom_minimum_size=Vector2(116,44)
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
 var n=preload("res://scripts/hyperspace_icon.gd").new();n.custom_minimum_size=Vector2(width,width);n.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;n.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;n.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(n);return n
func option(parent: Node) -> OptionButton:
 var n=OptionButton.new();n.size_flags_horizontal=Control.SIZE_EXPAND_FILL;preload("res://scripts/dialog_presentation.gd").option(n);parent.add_child(n);return n
func setup(owner) -> void:
 host=owner;commands.setup(self);route_ui.setup(self);legendary_help.setup(self)
 reward_feedback.setup(self)
 equipment_ui.setup(self)
 manual_adapter=func(selected_route,_selected_level):
  if host.game.has_method("start_hyperspace_challenge"):return host.game.start_hyperspace_challenge(selected_route)
  return false
 manual_ready_provider=func():return str(route_ui.view().get("reasons",{}).get("challenge","unavailable")).is_empty()
 refresh_manual_status()
 crew_adapter=route_ui.show_crew
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
 challenge_result_area=box(root_box,4);challenge_result_area.visible=false
 recent_result=label(challenge_result_area,"",21)
 exploration_receipt_area=box(root_box,4);exploration_receipt_area.visible=false
 var stack=Control.new();stack.size_flags_vertical=Control.SIZE_EXPAND_FILL;root_box.add_child(stack)
 for i in 4:
  var content=VBoxContainer.new();content.add_theme_constant_override("separation",14)
  if i in [0,2]:
   var page_scroll=ScrollContainer.new();page_scroll.name="ExplorationScroll" if i==0 else "ForgeScroll"
   page_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
   page_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
   page_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
   page_scroll.follow_focus=true;stack.add_child(page_scroll)
   content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;page_scroll.add_child(content)
   sections.append(page_scroll)
   if i==0:exploration_scroll=page_scroll;build_exploration(content)
   else:forge_scroll=page_scroll;forge_content=content
  else:
   content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);stack.add_child(content);sections.append(content)
 build_inventory(sections[1]);build_forge(forge_content);build_rules(sections[3])
 host.game.event.connect(on_event);visibility_changed.connect(func():
  if is_visible_in_tree():refresh())
 select_section(0);set_process(true);refresh()
func select_section(index: int) -> void:
 if index!=1 and not forge_pick_state.is_empty():finish_forge_pick("",true);return
 section_index=clampi(index,0,3)
 if section_index>1 and host!=null and not bool(host.game.profile.hyperspace.unlocked_drones):section_index=0
 for i in 4:
  put(sections[i],"visible",i==section_index)
  skin_selection(section_buttons[i],i==section_index)
 if host!=null and not bag.is_empty():refresh()
 reward_feedback.sync_receipt_area();refresh_challenge_result()
 if section_index==2 and commands!=null:commands.configure_operation()
func refresh_challenge_result() -> void:
 if recent_result==null or host==null:return
 # Session result belongs to manual challenge, independent of the reward receipt.
 var result:Dictionary=host.game.manual_hyperspace.last_result
 put(challenge_result_area,"visible",section_index==0 and not result.is_empty())
 if result.is_empty() or section_index!=0:return
 var reason=str(result.get("reason",""));var key="challenge_result_failed"
 if reason=="success":key="challenge_result_success"
 elif reason=="defeat":key="challenge_result_defeat"
 elif reason=="user_exit":key="challenge_result_exit"
 elif reason=="interrupted_reload":key="challenge_result_interrupted"
 put(recent_result,"text",t("challenge_recent_result",{"route":t(str(result.get("route",""))),"layer":str(int(result.get("level",0))),"result":t(key)}))
func build_exploration(parent: Node) -> void:
 label(parent,t("routes"),26)
 var grid=GridContainer.new();grid.columns=2;grid.add_theme_constant_override("h_separation",14);grid.add_theme_constant_override("v_separation",14);parent.add_child(grid)
 for key in host.game.hyperspace.config.routes:
  var b=button(grid,str(key),func():route=str(key);refresh_status());b.set_meta("route",str(key));b.text="";b.custom_minimum_size.y=140;b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  var margin=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  for edge in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+edge,14)
  margin.mouse_filter=Control.MOUSE_FILTER_IGNORE;b.add_child(margin)
  var content=row(margin);content.mouse_filter=Control.MOUSE_FILTER_IGNORE
  var config: Dictionary=host.game.hyperspace.config.routes[key];var icon=thumbnail(content,98);icon.texture=load("res://assets/hyperspace/icons/"+FAMILIES[config.weapon]+".png")
  var text=box(content,10);text.mouse_filter=Control.MOUSE_FILTER_IGNORE
  label(text,t(str(key)),25).mouse_filter=Control.MOUSE_FILTER_IGNORE
  label(text,t("route_reward",{"material":t(config.material)}),20).mouse_filter=Control.MOUSE_FILTER_IGNORE
  var marker=label(text,"",18);marker.mouse_filter=Control.MOUSE_FILTER_IGNORE;marker.visible=false;route_markers.append(marker)
  routes.append(b)
 route_ui.build(parent)
 first_win=label(parent,t("layer_first_win"),22)
 reward_feedback.build(exploration_receipt_area)
func build_inventory(parent: Node) -> void:
 capacity=label(parent,"");budgets=label(parent,"")
 drone_locked=label(parent,t("layer_drone_locked"),24)
 inventory_box=box(parent);inventory_box.size_flags_vertical=Control.SIZE_EXPAND_FILL
 var picking=row(inventory_box);forge_pick_cancel=button(picking,"forge_pick_cancel",func():finish_forge_pick("",true));forge_pick_cancel.visible=false
 equipment_ui.build(inventory_box)
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
  b.pressed.connect(func():choose_drone(str(b.get_meta("drone_id",""))));cards.append(b)
 empty=label(list,t("no_items"),24)
 var paging=row(list);previous=button(paging,"previous",func():page=maxi(0,page-1);refresh_list());page_label=label(paging,"");page_label.custom_minimum_size.x=120;page_label.autowrap_mode=TextServer.AUTOWRAP_OFF;next=button(paging,"next",func():page+=1;refresh_list())
 var detail=surface(split);detail.custom_minimum_size.x=360;detail.size_flags_vertical=Control.SIZE_EXPAND_FILL
 label(detail,t("selected_heading"),25)
 var title_row=row(detail);detail_icon=thumbnail(title_row,90);detail_title=label(title_row,t("none_selected"),24);detail_title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 var actions=GridContainer.new();actions.columns=2;actions.add_theme_constant_override("h_separation",8);actions.add_theme_constant_override("v_separation",8);detail.add_child(actions)
 dismantle_button=button(actions,"operation_dismantle",commands.show_inventory_dismantle)
 inventory_feedback=label(detail,"",19);inventory_feedback.visible=false
 equip=button(actions,"equip",toggle_equipped);favorite=button(actions,"favorite_action",toggle_favorite);unseal=button(actions,"unseal",func():host.game.hyperspace.claim_sealed(host.game,selected_id));button(actions,"section_forge",func():select_section(2));module_manage=button(actions,"module_manage",commands.show_modules);module_manage.disabled=true
 legendary_group=box(detail,4);legendary_group.visible=false
 legendary_button=button(legendary_group,"legendary_info",show_selected_legendary,{"name":""})
 legendary_summary=label(legendary_group,"",20)
 scroll=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;detail.add_child(scroll)
 var detail_body=box(scroll,6);inventory_feedback.reparent(detail_body)
 details=label(detail_body,t("choose"),21);details.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 totals_summary=label(detail,"",19);button(detail,"totals_manage",commands.show_totals)
func build_forge(parent: Node) -> void:
 var selected=surface(parent);label(selected,t("forge_selected"),25)
 var selected_row=row(selected);forge_icon=thumbnail(selected_row,70);var text=box(selected_row);forge_title=label(text,t("none_selected"),22);forge_details=label(text,t("choose"),21)
 forge_legendary_button=button(selected,"legendary_info",show_selected_legendary,{"name":""});forge_legendary_button.visible=false
 button(selected,"go_warehouse",begin_forge_pick)
 commands.build_forge(parent)
 commands.feedback.reparent(selected)
 commands.result_scroll.reparent(selected)
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
 if valid_draft(rule) and host.game.hyperspace.set_filter(host.game,rule):filter_result.text=t("filter_saved")+"\n"+filter_policy_summary(rule)
 else:filter_result.text=t("command_failed")
func on_event(kind: String,_payload: Dictionary) -> void:
 # Ordinary proficiency/adaptation counters do not change drone base details,
 # equipment slots, inventory, or hyperspace totals. Other consumers still receive them.
 if kind=="equipment_stats" and bool(_payload.get("counter_only",false)):return
 reward_feedback.on_event(kind,_payload)
 commands.exchange_ui.on_event(kind,_payload)
 if kind in ["hyperspace_changed","hyperspace_queue","unlocks_changed","ship_changed","hyperspace_rebuild","hyperspace_drone_restored","state","upgrade","upgrades_completed","equipment_stats","equipment_changed"]:
  dirty=true
  if kind=="hyperspace_changed" and (str(_payload.get("reason",""))=="claimed" or str(_payload.get("reason","")).begins_with("forge_")):
   if commands.materials_box!=null and commands.materials_box.is_visible_in_tree():
    commands.refresh_materials.call_deferred()
  if commands.totals_dialog!=null and commands.totals_dialog.visible:commands.refresh_totals()
  host.refresh_hyperspace_badge()
func _process(_delta: float) -> void:
 if not is_visible_in_tree():return
 if dirty:refresh()
 reward_feedback.mark_viewed()
 if section_index==0:route_ui.tick(_delta)
func refresh() -> void:
 if host==null or not is_visible_in_tree():return
 var s: Dictionary=host.game.profile.hyperspace
 if disabled_snapshot!=host.game.drone_combat.disabled:
  disabled_snapshot=host.game.drone_combat.disabled.duplicate();inventory_dirty=true
 for i in [2,3]:put(section_buttons[i],"visible",bool(s.unlocked_drones))
 if section_index>1 and not bool(s.unlocked_drones):select_section(0);return
 if generation!=int(s.inventory.generation) or round_id!=int(s.round_id) or bag.is_empty():
  refresh_manual_status(section_index!=0 or bag.is_empty())
 elif dirty and bag.presets!=s.inventory.presets:
  bag.presets=s.inventory.presets.duplicate(true);inventory_dirty=true
 if section_index==0:
  put(first_win,"visible",not bool(s.unlocked_drones));refresh_status();refresh_progress()
 elif section_index==1:
  put(capacity,"visible",bool(s.unlocked_drones));put(budgets,"visible",bool(s.unlocked_drones))
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
 route_ui.refresh()
 for i in routes.size():skin_selection(routes[i],str(host.game.hyperspace.config.routes.keys()[i])==route)
func refresh_start_reason() -> void:
 route_ui.refresh()
func refresh_progress() -> void:
 route_ui.refresh()
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
  var appearance=preload("res://scripts/hyperspace_appearance.gd").project(d)
  card_icons[i].apply(d)
  put(card_titles[i],"text",t("card",{"weapon":t(d.weapon),"level":str(int(d.level)),"quality":"","flags":""}).split("\n")[0])
  put(card_subtitles[i],"text",quality_caption(d)+(t("visual_tier",{"tier":str(int(appearance.tier))}) if not appearance.category.is_empty() else ""))
  var caption_color:Color=appearance.color.darkened(0.4)
  if card_subtitles[i].get_theme_color("font_color")!=caption_color:card_subtitles[i].add_theme_color_override("font_color",caption_color)
  put(card_flags[i],"text",flags(id,d) if not flags(id,d).is_empty() else t("no_flags"))
  skin_selection(b,id==selected_id)
 put(empty,"visible",ids.is_empty())
 inventory_dirty=false
 put(previous,"disabled",page==0);put(next,"disabled",page==pages-1);put(page_label,"text",t("page",{"page":str(page+1),"pages":str(pages)}))
 put(capacity,"text",t("capacity",{"used":str(bag.warehouse.size()),"cap":str(Bag.capacity(bag,host.game.hyperspace.config)),"overflow":str(bag.overflow.size()),"retention":str(Bag.retention_capacity(bag,host.game.hyperspace.config))}))
 refresh_details()
func flags(id: String,d: Dictionary) -> String:
 var names: Array[String]=[]
 if d.legendary:names.append(t("legendary"))
 if d.ultimate:names.append(t("ultimate"))
 var protection=protection_flags(id)
 if not protection.is_empty():names.append(protection)
 return " · ".join(names)
func protection_flags(id: String) -> String:
 var names: Array[String]=[]
 if bag.equipped.has(id):
  names.append(t("equipped"))
  if host.game.drone_combat.disabled.has(id):names.append(t("rebuild_disabled_short"))
 if bag.favorites.has(id):names.append(t("favorite"))
 if bag.sealed.has(id):names.append(t("sealed"))
 for p in bag.presets:
  if p.drone_ids.has(id):names.append(t("preset"));break
 return " · ".join(names)
func refresh_details() -> void:
 put(module_manage,"disabled",not bag.get("drones",{}).has(selected_id))
 if bag.is_empty():return
 var valid=bag.drones.has(selected_id)
 if valid:put(inventory_feedback,"visible",false)
 put(dismantle_button,"disabled",not valid or not forge_pick_state.is_empty())
 var has_effect=valid and bool(bag.drones[selected_id].get("legendary",false))
 var effect:Dictionary=bag.drones[selected_id].get("legendary_effect",{}) if has_effect else {}
 var effect_id=str(effect.get("effect_id",""))
 put(legendary_group,"visible",has_effect);put(forge_legendary_button,"visible",has_effect)
 if has_effect:
  var caption=t("legendary_info",{"name":effect_name(effect_id)})
  put(legendary_button,"text",caption);put(forge_legendary_button,"text",caption)
  put(legendary_summary,"text",legendary_help.summary(effect_id))
 if section_index==2:
  put(forge_title,"text",t("none_selected") if not valid else t("card",{"weapon":t(bag.drones[selected_id].weapon),"level":str(int(bag.drones[selected_id].level)),"quality":quality_caption(bag.drones[selected_id]),"flags":flags(selected_id,bag.drones[selected_id])}))
  put(forge_details,"text",t("choose") if not valid else t("forge_capacity_summary",{"affixes":str(bag.drones[selected_id].affixes.size()),"affix_cap":str(Bag.affix_limit(bag.drones[selected_id],host.game.hyperspace.config)),"slots":str(int(bag.drones[selected_id].hanging_slots)),"slot_cap":str(Bag.hanging_limit(bag.drones[selected_id],host.game.hyperspace.config))}))
  forge_icon.call("apply",bag.drones[selected_id]) if valid else forge_icon.call("clear")
  commands.refresh_result(bag.drones[selected_id] if valid else {})
  return
 if section_index!=1:return
 equipment_ui.refresh()
 var g=host.game;var rare:Array[String]=[];var legendary=0;var ultimate=0;var has_legendary=false;var has_ultimate=false
 for id in bag.drones:
  has_legendary=has_legendary or bool(bag.drones[id].legendary);has_ultimate=has_ultimate or bool(bag.drones[id].ultimate)
 for id in bag.equipped:
  legendary+=int(bag.drones[id].legendary);ultimate+=int(bag.drones[id].ultimate)
 if has_legendary:rare.append(t("rare_legendary_budget",{"used":str(legendary),"capacity":str(int(g.hyperspace.config.maximum_legendary))}))
 if has_ultimate:rare.append(t("rare_ultimate_budget",{"used":str(ultimate),"capacity":str(int(g.hyperspace.config.maximum_ultimate))}))
 put(budgets,"visible",not rare.is_empty());put(budgets,"text"," · ".join(rare))
 put(equip,"disabled",not valid or not hull_capacity_provider.is_valid() or bag.sealed.has(selected_id) or bag.overflow.has(selected_id))
 put(favorite,"disabled",not valid)
 var gate=int(bag.sealed.get(selected_id,0))
 put(unseal,"disabled",not valid or gate<1 or int(host.game.profile.highestLevel)<gate)
 put(unseal,"tooltip_text",t("sealed_gate",{"level":str(gate)}) if gate>0 else "")
 var totals:Dictionary=host.game.hyperspace_totals()
 var active_effects:Array[String]=[]
 for key in totals.affixes:
  if float(totals.affixes[key])!=0.0:active_effects.append(affix_name(str(key)))
 for key in totals.hangings:
  if float(totals.hangings[key])!=0.0:active_effects.append(hanging_name(str(key)))
 for key in totals.legendary:active_effects.append(effect_name(str(key)))
 put(totals_summary,"visible",not active_effects.is_empty())
 put(totals_summary,"text",t("active_effects_summary",{"items":" · ".join(active_effects)}))
 put(details,"text",t("choose") if not valid else drone_description(bag.drones[selected_id],false))
 put(detail_title,"text",t("none_selected") if not valid else t("card",{"weapon":t(bag.drones[selected_id].weapon),"level":str(int(bag.drones[selected_id].level)),"quality":quality_caption(bag.drones[selected_id]),"flags":t("ultimate") if bag.drones[selected_id].ultimate else ""}))
 detail_icon.call("apply",bag.drones[selected_id]) if valid else detail_icon.call("clear")
 for b in cards:skin_selection(b,b.get_meta("drone_id","")==selected_id)
func quality_caption(drone: Dictionary) -> String:
 var origin=t(str(drone.origin_quality))
 return t("legendary")+(" · "+origin if drone.origin_quality!="legendary" else "") if drone.legendary else origin
func choose_drone(id:String) -> void:
 if not forge_pick_state.is_empty():finish_forge_pick(id);return
 selected_id=id;commands.configure_operation();refresh_details()
func begin_forge_pick() -> void:
 forge_pick_state={"id":selected_id,"operation":str(commands.operation.get_item_metadata(commands.operation.selected)),"advanced":commands.show_advanced,"guarantee":str(commands.guarantee.get_item_metadata(commands.guarantee.selected)) if commands.guarantee.selected>=0 else "","maximum":commands.maximum.button_pressed}
 put(forge_pick_cancel,"visible",true);select_section(1)
func finish_forge_pick(id:String,cancelled:=false) -> void:
 if forge_pick_state.is_empty():return
 var state=forge_pick_state;forge_pick_state={}
 selected_id=str(state.id) if cancelled else id
 put(forge_pick_cancel,"visible",false)
 commands.select_operation(str(state.operation))
 if cancelled:
  commands.show_advanced=bool(state.advanced)
  commands.rebuild_choices(str(state.operation))
 select_section(2)
 for i in commands.guarantee.item_count:
  if str(commands.guarantee.get_item_metadata(i))==str(state.guarantee):commands.guarantee.select(i);break
 commands.maximum.button_pressed=bool(state.maximum)
func show_selected_legendary() -> void:
 if bag.get("drones",{}).has(selected_id) and bool(bag.drones[selected_id].get("legendary",false)):
  legendary_help.show(bag.drones[selected_id].legendary_effect)
func drone_description(d: Dictionary,include_legendary:=true) -> String:
 var protection=protection_flags(str(d.id))
 var g=host.game;var entry:Dictionary=g.drone_weapon_entry(d);var row:Dictionary=g.player_weapon_row(entry)
 var fire_params={"interval":"%.2f"%float(row.cd)}
 if str(d.weapon)=="missile":fire_params.count=str(int(row.get("para1",1)))
 var lines: Array[String]=[t("drone_independent_weapon",{"weapon":t(str(d.weapon)),"level":str(int(entry.level))}),t("drone_base_damage",{"damage":host.number(g.equipment_stat(str(entry.key),int(entry.level)))}),t("drone_fire_"+str(d.weapon),fire_params)]
 lines.insert(1,t("drone_dynamic_weapon_hint"))
 if bag.equipped.has(str(d.id)) and g.drone_combat.disabled.has(str(d.id)):lines.insert(0,t("rebuild_disabled"))
 lines.append(t("protect",{"flags":protection if not protection.is_empty() else t("unprotected")}))
 if bag.sealed.has(str(d.id)):lines.append(t("sealed_gate",{"level":str(int(bag.sealed[str(d.id)]))}))
 for a in d.affixes+([d.ultimate_affix] if not d.ultimate_affix.is_empty() else []):
  lines.append(affix_summary(a,d))
 if d.legendary and include_legendary:
  var effect:Dictionary=d.legendary_effect
  lines.append(effect_name(str(effect.get("effect_id",""))))
  var trigger:=legendary_trigger(str(effect.get("effect_id","")))
  if not trigger.is_empty():lines.append(trigger)
 var hangings: Array[String]=[]
 for key in d.hangings:hangings.append(hanging_name(str(key)))
 lines.append(t("hanging",{"items":" · ".join(hangings) if not hangings.is_empty() else t("no_hangings")}))
 if int(d.hanging_slots)==0:lines.append(t("module_no_slots" if Bag.hanging_limit(d,host.game.hyperspace.config)>0 else "module_no_capacity"))
 return "\n".join(lines)
func affix_display(a:Dictionary,d:Dictionary) -> Dictionary:
 var value:float=preload("res://scripts/drone_effect_aggregator.gd").affix_value(a,d,host.game.hyperspace.config)
 var result:Dictionary={"name":affix_name(str(a.key)),"value_text":t("times",{"value":str(int(value))}) if str(a.key) in COUNT_AFFIXES else t("percent",{"value":"%.1f"%(value*100.0)})}
 if affix_display_provider.is_valid():
  var projection=affix_display_provider.call(a.duplicate(true),d.duplicate(true))
  if projection is Dictionary:
   for key in ["name","value_text"]:
    if projection.has(key):result[key]=str(projection[key])
 return result
func affix_summary(a:Dictionary,d:Dictionary) -> String:
 var projection:=affix_display(a,d)
 return t("affix",{"key":projection.name,"tier":str(int(a.tier)),"value":projection.value_text,"locked":t("locked") if a.locked else ""})
func legendary_trigger(id:String) -> String:
 return legendary_help.summary(id)
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
 equipment_ui.activate()
func toggle_favorite() -> void:
 var ids: Array=bag.favorites.duplicate()
 if ids.has(selected_id):ids.erase(selected_id)
 else:ids.append(selected_id)
 host.game.hyperspace.set_favorites(host.game,ids)
func claim() -> void:
 if host.game.has_method("claim_hyperspace"):
  host.game.claim_hyperspace();dirty=true;route_ui.refresh()
func refresh_manual_status(include_inventory:=true) -> void:
 # A route load/reload or inventory generation boundary may refresh this snapshot; progress never does.
 var g=host.game;var s:Dictionary=g.profile.hyperspace
 manual_projection={"manual_ready":g.manual_hyperspace.production_accepted,"manual_error":g.manual_hyperspace.last_error}
 if include_inventory and (generation!=int(s.inventory.generation) or round_id!=int(s.round_id) or bag.is_empty()):
  bag=s.inventory.duplicate(true);manual_snapshot_reads+=1
  generation=int(bag.generation);round_id=int(s.round_id);inventory_dirty=true
 dirty=true
func manual_error_text() -> String:
 return t("manual_review_wait") if manual_projection.get("manual_error")=="space_data_not_accepted" else t("manual_not_ready")
func manual_ready() -> bool:
 return manual_adapter.is_valid() and manual_ready_provider.is_valid() and manual_ready_provider.call()
func start_manual() -> void:
 route_ui.act("start_hyperspace_challenge")
func filter_policy_summary(rule:Dictionary) -> String:
 var action=t("filter_action_"+str(rule.action))
 return action if bool(rule.enabled) else t("filter_disabled")+" · "+action
func preview_filter() -> void:
 var rule=Codec.import_string(filter_text.text,host.game.hyperspace.config)
 put(filter_result,"text",t("filter_valid",{"count":str(rule.conditions.size()),"mode":t("filter_and") if rule.mode=="all" else t("filter_or")})+"\n"+filter_policy_summary(rule) if valid_draft(rule) else t("filter_string_invalid"))
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
 var id=str(control.get_meta("drone_id",""))
 var quality="legendary" if bag.get("drones",{}).get(id,{}).get("legendary",false) else str(bag.get("drones",{}).get(id,{}).get("origin_quality","white"))
 var key=quality+str(selected)
 if control.get_meta("hyperspace_skin","")==key:return
 control.set_meta("hyperspace_skin",key);control.set_meta("hyperspace_selected",selected)
 if not card_style_cache.has(key):
  var accent=Color(str(preload("res://scripts/hyperspace_appearance.gd").settings().get("quality",{}).get(quality,{}).get("color","b8c7d0"))).darkened(0.25)
  var style=preload("res://scripts/dialog_presentation.gd").surface(Color("c5e7e3") if selected else Color("ecebdc"),accent,6)
  style.border_width_left=4;style.border_width_right=2;style.border_width_top=2;style.border_width_bottom=2
  card_style_cache[key]=style
 for state in ["normal","hover","pressed","hover_pressed"]:control.add_theme_stylebox_override(state,card_style_cache[key])
 if not card_style_cache.has("focus"):card_style_cache.focus=preload("res://scripts/dialog_presentation.gd").surface(Color(0,0,0,0),Color("288c96"),6)
 control.add_theme_stylebox_override("focus",card_style_cache.focus)

func checkbox_skin(control: CheckBox) -> void:
 for key in ["font_color","font_pressed_color","font_hover_color","font_hover_pressed_color","font_focus_color"]:control.add_theme_color_override(key,Color("243d50"))
 control.add_theme_color_override("font_disabled_color",Color("637782"))
