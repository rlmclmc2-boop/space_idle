extends ConfirmationDialog
## A display-only retention draft; the game prepares and commits the reforge.
const Text=preload("res://scripts/ui_text.gd")
const Bag=preload("res://scripts/drone_inventory.gd")
const Permission=preload("res://scripts/hyperspace_permissions.gd")
var game
var planet_id:=""
var round_id:=0
var generation:=0
var capacity:=0
var candidates:Array=[]
var selected:Array=[]
var choices:Dictionary={}
var summary:Label
var feedback:Label
var stale:=false
var show_hyperspace:=false
var show_drones:=false
var zero_confirmation:ConfirmationDialog
func setup(g,id:String,rewards:String)->void:
 game=g;planet_id=id;round_id=int(g.profile.hyperspace.round_id)
 var bag:Dictionary=g.profile.hyperspace.inventory
 show_drones=bool(g.profile.hyperspace.unlocked_drones) or not bag.drones.is_empty()
 show_hyperspace=g.hyperspace.is_unlocked(g) or show_drones or has_hyperspace_progress(g.profile.hyperspace)
 generation=int(bag.generation)
 capacity=Bag.retention_capacity(bag,g.hyperspace.config)+int(g.hyperspace.config.retention_capacity_gain)
 title=Text.t("planet.reforge");dialog_text="";min_size=Vector2i(650,370);size=Vector2i(740,500);dialog_hide_on_ok=false;wrap_controls=false
 var body=Control.new();body.custom_minimum_size=Vector2(600,290);body.size=body.custom_minimum_size;add_child(body)
 summary=make_label(body,"")
 feedback=make_label(body,"")
 var sc=ScrollContainer.new();sc.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO;body.add_child(sc)
 var layout=func():
  summary.position=Vector2.ZERO;summary.size=Vector2(body.size.x,46)
  feedback.position=Vector2(0,46);feedback.size=Vector2(body.size.x,52)
  sc.position=Vector2(0,98);sc.size=Vector2(body.size.x,maxf(1,body.size.y-98))
 body.resized.connect(layout);layout.call()
 var content=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;sc.add_child(content)
 if show_drones:make_label(content,Text.t("planet.reforge_selection_hint"))
 for drone_id in bag.warehouse+bag.overflow:
  if bag.drones.has(drone_id):candidates.append(drone_id)
 # Preserve the original inventory order within each favorite/non-favorite group.
 var favorites:Array=candidates.filter(func(key):return bag.favorites.has(key))
 var others:Array=candidates.filter(func(key):return not bag.favorites.has(key))
 candidates=favorites+others
 for drone_id in candidates:
  var d:Dictionary=bag.drones[drone_id]
  var choice=CheckBox.new();choice.set_meta("drone_id",drone_id);choice.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  choice.text=Text.t("planet.reforge_drone",{"weapon":Text.t("hyperspace."+str(d.weapon)),"level":str(int(d.level)),"quality":Text.t("hyperspace."+str(d.origin_quality)),"favorite":Text.t("hyperspace.favorite") if bag.favorites.has(drone_id) else "","gate":str(Permission.planet_stage(g.db.data,str(d.planet_id)))})
  var chrome=preload("res://scripts/dialog_presentation.gd")
  chrome.button_skin(choice)
  choice.add_theme_color_override("font_hover_pressed_color",chrome.NAVY)
  choice.add_theme_stylebox_override("hover_pressed",choice.get_theme_stylebox("pressed"))
  content.add_child(choice);choices[drone_id]=choice;choice.toggled.connect(on_choice.bind(drone_id))
  if bag.equipped.has(drone_id):choice.text+=" · "+Text.t("hyperspace.equipped")
  var lines:Array[String]=[]
  for affix in d.affixes+([d.ultimate_affix] if not d.ultimate_affix.is_empty() else []):
   var key:String=str(affix.key)
   var value:String=Text.t("hyperspace.times",{"value":str(int(affix.value))}) if key in ["chain_count","extra_chain_count"] else Text.t("hyperspace.percent",{"value":"%.1f"%(float(affix.value)*100.0)})
   lines.append(Text.t("hyperspace.affix",{"key":Text.data_text("hyperspace_affixes",key,"name",Text.t("hyperspace.unknown_affix")),"tier":str(int(affix.tier)),"value":value,"locked":Text.t("hyperspace.locked") if affix.locked else ""}))
  if d.legendary:lines.append(Text.data_text("hyperspace_legendary_effects",str(d.legendary_effect.get("effect_id","")),"name",Text.t("hyperspace.unknown_effect")))
  if not lines.is_empty():make_label(content,"\n".join(lines))
 if show_drones and candidates.is_empty():make_label(content,Text.t("planet.reforge_no_drones"))
 make_label(content,Text.t("planet.reforge_confirm_basic",{"level":g.planet_reforge_start(id)}))
 if show_hyperspace:make_label(content,Text.t("planet.reforge_hyperspace"))
 if show_drones:make_label(content,Text.t("planet.reforge_drones"))
 make_label(content,Text.t("planet.reforge_rewards",{"rewards":rewards}))
 confirmed.connect(commit);canceled.connect(queue_free)
 game.event.connect(on_game_event)
 refresh_summary()
func has_hyperspace_progress(s:Dictionary)->bool:
 if not s.history.is_empty() or not s.active.is_empty() or bool(s.auto.enabled) or int(s.ultimate_cores)>0:return true
 if s.materials.values().any(func(value):return int(value)>0):return true
 return s.hanging_modules.values().any(func(module):return bool(module.unlocked) or int(module.level)>0 or float(module.exp)>0)
func make_label(parent:Node,value:String)->Label:
 var result=Label.new();result.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;result.text=value;result.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(result);return result
func on_choice(on:bool,id:String)->void:
 if on and not selected.has(id):selected.append(id)
 elif not on:selected.erase(id)
 refresh_summary()
func on_game_event(kind:String,_info:Dictionary)->void:
 if kind in ["hyperspace_changed","planet_reforged"]:
  if int(game.profile.hyperspace.round_id)!=round_id or int(game.profile.hyperspace.inventory.generation)!=generation:
   stale=true;refresh_summary()
func refresh_summary()->void:
 summary.visible=show_drones
 summary.text=Text.t("planet.reforge_selection",{"selected":str(selected.size()),"capacity":str(capacity),"discarded":str(candidates.size()-selected.size())})
 feedback.text=Text.t("planet.reforge_stale") if stale else Text.t("planet.reforge_over_capacity") if selected.size()>capacity else Text.t("planet.reforge_brief" if show_hyperspace else "planet.reforge_brief_basic")
 get_ok_button().disabled=stale or selected.size()>capacity
func commit(allow_zero:=false)->void:
 # Recheck the snapshot and current permission before the authoritative transaction.
 if int(game.profile.hyperspace.round_id)!=round_id or int(game.profile.hyperspace.inventory.generation)!=generation:
  stale=true;refresh_summary();return
 if selected.size()>capacity or not game.can_reforge_planet(planet_id):
  feedback.text=Text.t("planet.reforge_failed");return
 if selected.is_empty() and not candidates.is_empty() and not allow_zero:
  confirm_zero_retention();return
 if not game.reforge_planet(planet_id,selected.duplicate()):
  feedback.text=Text.t("planet.reforge_failed");return
 queue_free()

func confirm_zero_retention()->void:
 if is_instance_valid(zero_confirmation):return
 zero_confirmation=ConfirmationDialog.new()
 zero_confirmation.title=Text.t("planet.reforge_zero_title")
 zero_confirmation.dialog_text=Text.t("planet.reforge_zero_warning",{"count":str(candidates.size())})
 zero_confirmation.ok_button_text=Text.t("planet.reforge_zero_confirm")
 zero_confirmation.cancel_button_text=Text.t("planet.reforge_zero_cancel")
 zero_confirmation.min_size=Vector2i(480,190)
 zero_confirmation.size=Vector2i(600,220)
 zero_confirmation.dialog_hide_on_ok=false
 preload("res://scripts/dialog_presentation.gd").dialog(zero_confirmation)
 add_child(zero_confirmation)
 zero_confirmation.canceled.connect(close_zero_confirmation)
 zero_confirmation.confirmed.connect(func():close_zero_confirmation();commit(true))
 zero_confirmation.popup_centered()
 # Default Enter returns to the draft; deletion requires focusing/clicking its explicit action.
 zero_confirmation.get_cancel_button().grab_focus()
func close_zero_confirmation()->void:
 if is_instance_valid(zero_confirmation):zero_confirmation.queue_free()
 zero_confirmation=null
 if is_instance_valid(get_cancel_button()):get_cancel_button().grab_focus()
