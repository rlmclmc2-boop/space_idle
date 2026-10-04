extends Control
## Owns selection and bounded controls only; all durable commands go through hyperspace.
const Bag=preload("res://scripts/drone_inventory.gd")
const Codec=preload("res://scripts/drone_filter_preview.gd")
const PAGE_SIZE=8
const FAMILIES={"laser":"pulse","missile":"missile","cannon":"rail","longLaser":"beam"}
var host
var manual_adapter: Callable
var crew_adapter: Callable
var hull_capacity_provider: Callable
var preset_adapter: Callable
var affix_catalog_provider: Callable
var weapon_filter: OptionButton
var quality_filter: OptionButton
var sort_order: OptionButton
var filter_mode: OptionButton
var filter_kinds: Array[OptionButton]=[]
var filter_values: Array[LineEdit]=[]
var bag: Dictionary={}
var generation=-1
var round_id=-1
var page=0
var selected_id=""
var list_refreshes=0
var route="alpha"
var scroll: ScrollContainer
var root_box: VBoxContainer
var inventory_box: VBoxContainer
var cards: Array[Button]=[]
var card_icons: Array[TextureRect]=[]
var level: SpinBox
var energy: Label
var best: Label
var status: Label
var progress: ProgressBar
var start_button: Button
var crew_button: Button
var claim_button: Button
var first_win: Label
var capacity: Label
var budgets: Label
var page_label: Label
var previous: Button
var next: Button
var details: Label
var equip: Button
var favorite: Button
var unseal: Button
var preset_names: Array[LineEdit]=[]
var preset_apply: Array[Button]=[]
var filter_text: TextEdit
var filter_result: Label
var routes: Array[Button]=[]
var dirty=true

func t(key: String,params: Dictionary={}) -> String:return UIText.t("hyperspace."+key,params)
func put(control: Object,key: StringName,value: Variant) -> void:
 if control.get(key)!=value:control.set(key,value)
func label(parent: Node,text: String,font_size=22) -> Label:
 var n=Label.new();n.text=text;n.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 n.add_theme_font_size_override("font_size",font_size);n.add_theme_color_override("font_color",Color("243d50"));parent.add_child(n);return n
func button(parent: Node,key: String,action: Callable) -> Button:
 var n=Button.new();n.text=t(key);n.custom_minimum_size=Vector2(130,44)
 preload("res://scripts/dialog_presentation.gd").button_skin(n,false)
 parent.add_child(n);n.pressed.connect(action);return n
func row(parent: Node) -> HBoxContainer:
 var n=HBoxContainer.new();n.add_theme_constant_override("separation",12);parent.add_child(n);return n
func setup(owner) -> void:
 host=owner
 theme=preload("res://scripts/dialog_presentation.gd").theme()
 add_theme_font_override("font",host.font)
 var panel=PanelContainer.new();panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 panel.offset_left=24;panel.offset_right=-24;panel.offset_top=24;panel.offset_bottom=-24
 panel.add_theme_stylebox_override("panel",preload("res://scripts/dialog_presentation.gd").surface());add_child(panel)
 var margin=MarginContainer.new()
 for edge in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+edge,24)
 panel.add_child(margin)
 scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;margin.add_child(scroll)
 root_box=VBoxContainer.new();root_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;root_box.add_theme_constant_override("separation",16);scroll.add_child(root_box)
 label(root_box,t("title"),34);label(root_box,t("routes"))
 var route_row=row(root_box)
 for key in host.game.hyperspace.config.routes:
  var b=button(route_row,str(key),func():route=str(key);refresh_status());b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;routes.append(b)
 var levels=row(root_box);var level_label=label(levels,t("level"));level_label.custom_minimum_size.x=160;level_label.autowrap_mode=TextServer.AUTOWRAP_OFF;level=SpinBox.new();level.min_value=5;level.max_value=5;level.step=1;level.custom_minimum_size.x=170;levels.add_child(level);level.get_line_edit().add_theme_color_override("font_color",Color("243d50"));level.get_line_edit().add_theme_stylebox_override("normal",preload("res://scripts/dialog_presentation.gd").surface());level.value_changed.connect(func(_v):refresh_status())
 energy=label(root_box,"");best=label(root_box,"")
 var commands=row(root_box)
 start_button=button(commands,"start",start_manual);crew_button=button(commands,"crew",func():
  if crew_adapter.is_valid():crew_adapter.call())
 claim_button=button(commands,"claim",claim)
 label(root_box,t("auto_hint"),18)
 status=label(root_box,"");progress=ProgressBar.new();progress.custom_minimum_size.y=26;progress.show_percentage=false;root_box.add_child(progress)
 first_win=label(root_box,t("first_win"),20)
 inventory_box=VBoxContainer.new();inventory_box.add_theme_constant_override("separation",12);root_box.add_child(inventory_box)
 label(inventory_box,t("warehouse"),28);capacity=label(inventory_box,"");budgets=label(inventory_box,"")
 var selectors=row(inventory_box)
 weapon_filter=OptionButton.new();weapon_filter.add_item(t("all"))
 for key in FAMILIES:weapon_filter.add_item(t(key))
 quality_filter=OptionButton.new();quality_filter.add_item(t("all"))
 for key in ["white","blue","gold","legendary"]:quality_filter.add_item(t(key))
 sort_order=OptionButton.new()
 for key in ["sort_acquired","sort_level","sort_quality"]:sort_order.add_item(t(key))
 for selector in [weapon_filter,quality_filter,sort_order]:
  preload("res://scripts/dialog_presentation.gd").option(selector);selector.size_flags_horizontal=Control.SIZE_EXPAND_FILL;selectors.add_child(selector);selector.item_selected.connect(func(_i):page=0;refresh_list())
 var grid=GridContainer.new();grid.columns=2;grid.add_theme_constant_override("h_separation",12);grid.add_theme_constant_override("v_separation",12);inventory_box.add_child(grid)
 for i in PAGE_SIZE:
  var b=Button.new();b.custom_minimum_size=Vector2(270,104);b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;b.alignment=HORIZONTAL_ALIGNMENT_LEFT;b.add_theme_constant_override("outline_size",0)
  b.add_theme_font_size_override("font_size",19);b.add_theme_color_override("font_color",Color("243d50"));b.add_theme_color_override("font_hover_color",Color("243d50"));grid.add_child(b)
  var icon=TextureRect.new();icon.position=Vector2(8,8);icon.size=Vector2(76,88);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;b.add_child(icon)
  b.add_theme_stylebox_override("normal",preload("res://scripts/dialog_presentation.gd").surface());b.pressed.connect(func():selected_id=str(b.get_meta("drone_id",""));refresh_details());cards.append(b);card_icons.append(icon)
 var paging=row(inventory_box);previous=button(paging,"previous",func():page=maxi(0,page-1);refresh_list());page_label=label(paging,"");page_label.custom_minimum_size.x=130;page_label.autowrap_mode=TextServer.AUTOWRAP_OFF;next=button(paging,"next",func():page+=1;refresh_list())
 details=label(inventory_box,t("choose"),20)
 var actions=row(inventory_box);equip=button(actions,"equip",toggle_equipped);favorite=button(actions,"favorite_action",toggle_favorite);unseal=button(actions,"unseal",func():host.game.hyperspace.claim_sealed(host.game,selected_id))
 label(inventory_box,t("summary"),18)
 label(inventory_box,t("presets"),26)
 for index in 3:
  var pr=row(inventory_box);var name_field=LineEdit.new();name_field.placeholder_text=t("preset_name");name_field.max_length=96;input_skin(name_field);name_field.size_flags_horizontal=Control.SIZE_EXPAND_FILL;pr.add_child(name_field);preset_names.append(name_field)
  button(pr,"save_preset",func():host.game.hyperspace.set_preset(host.game,index,name_field.text,bag.equipped))
  var apply=button(pr,"apply_preset",func():
   if preset_adapter.is_valid():preset_adapter.call(index))
  preset_apply.append(apply)
  button(pr,"clear_preset",func():host.game.hyperspace.clear_preset(host.game,index))
 label(inventory_box,t("filter"),26);label(inventory_box,t("filter_hint"),18)
 filter_mode=OptionButton.new();filter_mode.add_item("AND");filter_mode.add_item("OR");preload("res://scripts/dialog_presentation.gd").option(filter_mode);inventory_box.add_child(filter_mode)
 for i in 5:
  var fr=row(inventory_box);var kind=OptionButton.new()
  for key in ["none","weapon","quality","min_level","affix","legendary","ultimate"]:
   kind.add_item(t("condition_"+key));kind.set_item_metadata(kind.item_count-1,key)
  kind.custom_minimum_size.x=160;preload("res://scripts/dialog_presentation.gd").option(kind);fr.add_child(kind);filter_kinds.append(kind)
  var value=LineEdit.new();input_skin(value);value.size_flags_horizontal=Control.SIZE_EXPAND_FILL;fr.add_child(value);filter_values.append(value)
 button(inventory_box,"preview",build_filter_draft)
 filter_text=TextEdit.new();filter_text.custom_minimum_size.y=110;input_skin(filter_text);filter_text.text='{"version":1,"mode":"and","conditions":[]}';inventory_box.add_child(filter_text)
 var filters=row(inventory_box);button(filters,"preview",preview_filter);button(filters,"export",func():
  var parsed=Codec.parse(filter_text.text,affix_catalog_provider.call() if affix_catalog_provider.is_valid() else [])
  if parsed.ok:DisplayServer.clipboard_set(JSON.stringify(parsed.rule)))
 filter_result=label(inventory_box,"")
 label(inventory_box,t("forge"),26);label(inventory_box,t("forge_hint"),18)
 var forge=GridContainer.new();forge.columns=3;inventory_box.add_child(forge)
 for operation in ["upgrade","reroll","hanging","lock","tier","reset","future","legend","modern","ultimate"]:
  var b=button(forge,"forge_"+operation,func():pass);b.disabled=true;b.tooltip_text=t("adapter")
 host.game.event.connect(on_event);visibility_changed.connect(func():
  if is_visible_in_tree():refresh())
 set_process(true);refresh()
func on_event(kind: String,_payload: Dictionary) -> void:
 if kind in ["hyperspace_changed","unlocks_changed","ship_changed"]:
  dirty=true
  host.refresh_hyperspace_badge()
func _process(_delta: float) -> void:
 if not is_visible_in_tree():return
 if dirty:refresh()
 refresh_progress()
func refresh() -> void:
 if host==null or not is_visible_in_tree():return
 var s: Dictionary=host.game.profile.hyperspace
 if generation!=int(s.inventory.generation) or round_id!=int(s.round_id) or bag.is_empty():
  bag=s.inventory.duplicate(true);generation=int(bag.generation);round_id=int(s.round_id);refresh_list()
 elif dirty:
  # Preset commands in stage1 do not increment inventory generation.
  var changed=bag.presets!=s.inventory.presets
  bag.presets=s.inventory.presets.duplicate(true)
  if changed:
   for b in cards:
    var id=str(b.get_meta("drone_id",""))
    if bag.drones.has(id):
     var d:Dictionary=bag.drones[id]
     put(b,"text","                  "+t("card",{"weapon":t(d.weapon),"level":str(d.level),"quality":t(d.origin_quality),"flags":flags(id,d)}).replace("\n","\n                  "))
  refresh_details()
 put(inventory_box,"visible",bool(s.unlocked_drones))
 put(first_win,"visible",not bool(s.unlocked_drones))
 for i in 3:
  put(preset_apply[i],"disabled",not preset_adapter.is_valid() or i>=bag.presets.size())
  if i<bag.presets.size() and not preset_names[i].has_focus():put(preset_names[i],"text",str(bag.presets[i].name))
 refresh_status();refresh_progress();dirty=false
func refresh_status() -> void:
 if host==null:return
 var g=host.game;var h=g.hyperspace;var s: Dictionary=g.profile.hyperspace
 put(level,"max_value",maxi(5,int(g.profile.highestLevel)))
 var ticket=float(h.config.ticket)
 if not s.active.is_empty():ticket=float(s.active.ticket)
 put(energy,"text",t("energy",{"current":"%.0f"%float(s.energy),"cap":"%.0f"%float(h.config.energy_cap),"ticket":"%.0f"%ticket}))
 var best_time=float(h.best_x1(g,route,int(level.value)))
 put(best,"text",t("best",{"time":"%.2f s"%best_time if best_time>0 else t("none")}))
 put(start_button,"disabled",not manual_adapter.is_valid() or not h.eligible_level(g,route,int(level.value)) or not s.active.is_empty() or float(s.energy)<float(h.config.ticket))
 put(start_button,"tooltip_text","" if manual_adapter.is_valid() else t("adapter"))
 put(crew_button,"disabled",not crew_adapter.is_valid());put(crew_button,"tooltip_text","" if crew_adapter.is_valid() else t("adapter"))
 for i in routes.size():put(routes[i],"modulate",Color("80edfa") if str(h.config.routes.keys()[i])==route else Color.WHITE)
func refresh_progress() -> void:
 var s: Dictionary=host.game.profile.hyperspace;var a: Dictionary=s.active
 var text=t("idle");var fill=0.0
 if not a.is_empty():
  if a.status=="completed_pending":text=t("blocked") if s.blocked else t("pending");fill=100.0
  elif a.mode=="auto":
   fill=100.0*float(a.work)/maxf(0.001,float(a.duration));text=t("progress",{"work":"%.1f"%float(a.work),"duration":"%.1f"%float(a.duration)})
  else:text=t("manual")
 put(status,"text",text);put(status,"modulate",Color("ff7979") if s.blocked or (not a.is_empty() and a.status=="completed_pending") else Color("243d50"));put(progress,"value",fill)
 put(claim_button,"disabled",a.is_empty() or a.get("status")!="completed_pending")
 put(start_button,"disabled",not manual_adapter.is_valid() or not host.game.hyperspace.eligible_level(host.game,route,int(level.value)) or not a.is_empty() or float(s.energy)<float(host.game.hyperspace.config.ticket))
 # Energy is a scalar read: never duplicate the entire inventory in a frame update.
 var ticket=float(host.game.hyperspace.config.ticket) if a.is_empty() else float(a.ticket)
 put(energy,"text",t("energy",{"current":"%.0f"%float(s.energy),"cap":"%.0f"%float(host.game.hyperspace.config.energy_cap),"ticket":"%.0f"%ticket}))
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
  put(b,"text","                  "+t("card",{"weapon":t(d.weapon),"level":str(d.level),"quality":t(d.origin_quality),"flags":flags(id,d)}).replace("\n","\n                  "))
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
 if bag.equipped.has(id):names.append(t("equipped"))
 if bag.favorites.has(id):names.append(t("favorite"))
 if bag.sealed.has(id):names.append(t("sealed"))
 for p in bag.presets:
  if p.drone_ids.has(id):names.append(t("preset"));break
 return " · ".join(names)
func refresh_details() -> void:
 var valid=bag.drones.has(selected_id)
 put(equip,"disabled",not valid or not hull_capacity_provider.is_valid() or bag.sealed.has(selected_id) or bag.overflow.has(selected_id));put(favorite,"disabled",not valid);put(unseal,"disabled",not valid or not bag.sealed.has(selected_id) or int(host.game.profile.highestLevel)<int(bag.sealed.get(selected_id,0)))
 if not valid:put(details,"text",t("choose"));return
 var d: Dictionary=bag.drones[selected_id];var lines: Array[String]=[t("card",{"weapon":t(d.weapon),"level":str(d.level),"quality":t(d.origin_quality),"flags":flags(selected_id,d)}),t("protect",{"flags":flags(selected_id,d)})]
 for a in d.affixes+([d.ultimate_affix] if not d.ultimate_affix.is_empty() else []):lines.append(t("affix",{"key":str(a.key),"tier":str(a.tier),"value":"%.1f"%float(a.value),"locked":t("locked") if a.locked else ""}))
 if d.legendary:lines.append(t("legend_effect",{"effect":str(d.legendary_effect.get("effect_id","")),"value":str(d.legendary_effect.get("value",""))}))
 lines.append(t("hanging",{"items":" · ".join(d.hangings)}));put(details,"text","\n".join(lines))
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
func start_manual() -> void:
 # Adapter owns start+encounter setup atomically; no paid receipt without a battlefield.
 if manual_adapter.is_valid():manual_adapter.call(route,int(level.value))
func preview_filter() -> void:
 var parsed=Codec.parse(filter_text.text,affix_catalog_provider.call() if affix_catalog_provider.is_valid() else [])
 put(filter_result,"text",t("filter_valid",{"count":str(parsed.rule.conditions.size()),"mode":parsed.rule.mode}) if parsed.ok else t("filter_invalid",{"reason":parsed.reason}))

func build_filter_draft() -> void:
 var conditions: Array=[]
 for i in 5:
  var kind=filter_kinds[i].get_item_metadata(filter_kinds[i].selected)
  if kind=="none":continue
  var raw=filter_values[i].text.strip_edges();var value: Variant=raw
  if kind in ["min_level","legendary","ultimate","affix"]:value=JSON.parse_string(raw)
  conditions.append({"kind":kind,"value":value})
 filter_text.text=JSON.stringify({"version":1,"mode":"and" if filter_mode.selected==0 else "or","conditions":conditions})
 preview_filter()

func input_skin(field: Control) -> void:
 field.add_theme_color_override("font_color",Color("243d50"))
 field.add_theme_color_override("font_placeholder_color",Color("637782"))
 for state in ["normal","focus","read_only"]:field.add_theme_stylebox_override(state,preload("res://scripts/dialog_presentation.gd").surface(Color("ecebdc"),Color("243d50"),6))
