extends Control
## Table-owned intelligence. Build stage projections once; hidden pages do no work.
const IntelSkin := preload("res://scripts/shell_presentation.gd")
var host: Node
var route_stage := -1
var route_builds := 0
var detail_builds := 0
var entries: Array[Dictionary] = []
var selected := -1
var list: ItemList
var detail: VBoxContainer
var heading: Label
var image: TextureRect
var detail_lines: Array[Label] = []
var detail_cursor := 0
var preview_textures: Dictionary = {}
var point_bar: HBoxContainer
var point_buttons: Array[Button] = []
var visible_entry_indices: Array[int] = []
var selected_point := -1
var current_point := -1
var follow_current := true
var stage_label: Label
var identity: Label
var trait_label: Label
var armour_badge: Label
var attack_badge: Label
var detail_scroll: ScrollContainer
var details_button: Button
var follow_button: Button
var portrait_backdrop: TextureRect
var portrait_frame: Control
var portrait_panel: PanelContainer

func surface(fill: Color, border: Color = IntelSkin.SLATE, radius: int = 12) -> StyleBoxFlat:
 var box := StyleBoxFlat.new()
 box.bg_color=fill
 box.border_color=border
 box.set_border_width_all(1)
 box.set_corner_radius_all(radius)
 box.content_margin_left=20
 box.content_margin_right=20
 box.content_margin_top=14
 box.content_margin_bottom=14
 return box

func rule(parent: Node, tint: Color = IntelSkin.SLATE) -> void:
 var line:=ColorRect.new()
 line.color=tint
 line.custom_minimum_size.y=2
 line.mouse_filter=Control.MOUSE_FILTER_IGNORE
 parent.add_child(line)

func setup(owner: Node) -> void:
 host=owner
 name="EnemyIntel"
 add_theme_color_override("font_color",IntelSkin.PAPER)
 var background:=ColorRect.new()
 background.color=Color("0c1a27")
 background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 background.mouse_filter=Control.MOUSE_FILTER_IGNORE
 add_child(background)
 var margin := MarginContainer.new()
 margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,20)
 margin.add_theme_constant_override("margin_right",44)
 add_child(margin)
 var layout := VBoxContainer.new()
 layout.add_theme_constant_override("separation",14)
 margin.add_child(layout)
 var header := HBoxContainer.new()
 layout.add_child(header)
 stage_label=add_label(header,"",30)
 stage_label.add_theme_font_override("font",IntelSkin.face(700))
 stage_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 follow_button=Button.new()
 follow_button.text=UIText.t("enemy.intel.current")
 follow_button.pressed.connect(func():follow_current=true;show_point(current_point);update_point_buttons())
 skin_button(follow_button)
 header.add_child(follow_button)
 rule(layout,IntelSkin.TEAL.darkened(0.48))
 point_bar=HBoxContainer.new()
 point_bar.add_theme_constant_override("separation",5)
 layout.add_child(point_bar)
 var body := HBoxContainer.new()
 body.size_flags_vertical=Control.SIZE_EXPAND_FILL
 body.add_theme_constant_override("separation",14)
 layout.add_child(body)
 var roster := PanelContainer.new()
 roster.custom_minimum_size.x=290
 roster.add_theme_stylebox_override("panel",surface(Color("152b3a"),IntelSkin.SLATE))
 body.add_child(roster)
 var roster_layout := VBoxContainer.new()
 roster_layout.add_theme_constant_override("separation",14)
 roster.add_child(roster_layout)
 var roster_title:=add_label(roster_layout,UIText.t("enemy.intel.roster"),20)
 roster_title.modulate=IntelSkin.TEAL
 roster_title.add_theme_font_override("font",IntelSkin.face(700))
 rule(roster_layout)
 list=ItemList.new()
 list.size_flags_vertical=Control.SIZE_EXPAND_FILL
 list.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
 list.add_theme_stylebox_override("selected",surface(Color("285066"),IntelSkin.TEAL,8))
 list.add_theme_stylebox_override("selected_focus",surface(Color("285066"),IntelSkin.TEAL,8))
 list.add_theme_stylebox_override("hovered",surface(IntelSkin.SLATE,IntelSkin.SLATE,8))
 list.add_theme_font_override("font",IntelSkin.face(600))
 list.add_theme_font_size_override("font_size",17)
 list.add_theme_constant_override("v_separation",14)
 list.add_theme_constant_override("h_separation",12)
 list.fixed_icon_size=Vector2i(68,68)
 list.item_selected.connect(func(i:int):show_entry(visible_entry_indices[i]))
 roster_layout.add_child(list)
 var dossier := PanelContainer.new()
 dossier.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 dossier.add_theme_stylebox_override("panel",surface(Color("1c3546"),IntelSkin.SLATE))
 body.add_child(dossier)
 var sheet := VBoxContainer.new()
 sheet.add_theme_constant_override("separation",10)
 dossier.add_child(sheet)
 identity=add_label(sheet,"",16)
 identity.modulate=IntelSkin.TEAL
 heading=add_label(sheet,"",32)
 heading.add_theme_font_override("font",IntelSkin.face(700))
 rule(sheet,IntelSkin.TEAL.darkened(0.55))
 var portrait := PanelContainer.new()
 portrait_panel=portrait
 portrait.custom_minimum_size.y=350
 portrait.size_flags_vertical=Control.SIZE_FILL
 portrait.add_theme_stylebox_override("panel",surface(Color("102637"),IntelSkin.SLATE,8))
 sheet.add_child(portrait)
 portrait_frame=Control.new()
 portrait_frame.clip_contents=true
 portrait.add_child(portrait_frame)
 portrait_backdrop=TextureRect.new()
 portrait_backdrop.texture=preload("res://assets/backgrounds/opening/stage_01.png")
 portrait_backdrop.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 portrait_backdrop.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
 portrait_backdrop.modulate=Color(0.52,0.77,0.85,0.32)
 portrait_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 portrait_backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE
 portrait_frame.add_child(portrait_backdrop)
 var scan:=Control.new()
 scan.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 scan.mouse_filter=Control.MOUSE_FILTER_IGNORE
 scan.draw.connect(draw_scan_overlay.bind(scan))
 scan.resized.connect(scan.queue_redraw)
 portrait_frame.add_child(scan)
 image=TextureRect.new()
 image.custom_minimum_size=Vector2.ZERO
 image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 image.mouse_filter=Control.MOUSE_FILTER_IGNORE
 portrait_frame.add_child(image)
 trait_label=add_label(sheet,"",20)
 trait_label.modulate=Color("c5d9d8")
 var badges := HBoxContainer.new()
 badges.add_theme_constant_override("separation",12)
 sheet.add_child(badges)
 armour_badge=add_label(badges,"",16)
 attack_badge=add_label(badges,"",16)
 armour_badge.modulate=IntelSkin.TEAL
 attack_badge.modulate=Color("e9c48b")
 details_button=Button.new()
 details_button.text=UIText.t("enemy.intel.details")
 details_button.toggle_mode=true
 skin_button(details_button)
 details_button.alignment=HORIZONTAL_ALIGNMENT_LEFT
 details_button.toggled.connect(func(on:bool):detail_scroll.visible=on;update_portrait_height())
 sheet.add_child(details_button)
 detail_scroll=ScrollContainer.new()
 detail_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
 detail_scroll.custom_minimum_size.y=130
 detail_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 detail_scroll.visible=false
 sheet.add_child(detail_scroll)
 detail=VBoxContainer.new()
 detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 detail.add_theme_constant_override("separation",10)
 detail_scroll.add_child(detail)
 for index in 10:
  var line:=add_label(detail,"",16)
  line.visible=false
  detail_lines.append(line)
 resized.connect(update_portrait_height)
 visibility_changed.connect(refresh_if_needed)

func update_portrait_height() -> void:
 if not is_instance_valid(portrait_panel) or not is_instance_valid(details_button):return
 portrait_panel.custom_minimum_size.y=220 if size.y<950 and details_button.button_pressed else 350

func draw_scan_overlay(layer: Control) -> void:
 var bounds:=layer.size
 if bounds.x<80 or bounds.y<80:return
 var accent:=Color(0.52,0.82,0.79,0.30)
 var center:=bounds*0.5
 var radius:=minf(bounds.x,bounds.y)*0.38
 layer.draw_arc(center,radius,0,TAU,72,Color(0.52,0.82,0.79,0.12),1.0,true)
 layer.draw_arc(center,radius*0.68,0,TAU,72,Color(0.52,0.82,0.79,0.09),1.0,true)
 for x in [20.0,bounds.x-20.0]:
  var direction:float=1.0 if x<bounds.x*0.5 else -1.0
  for y in [20.0,bounds.y-20.0]:
   var vertical:float=1.0 if y<bounds.y*0.5 else -1.0
   layer.draw_line(Vector2(x,y),Vector2(x+direction*36.0,y),accent,2.0,true)
   layer.draw_line(Vector2(x,y),Vector2(x,y+vertical*36.0),accent,2.0,true)

func preview_texture(texture: Texture2D) -> Texture2D:
 if texture==null:return null
 var key:=texture.get_instance_id()
 if preview_textures.has(key):return preview_textures[key]
 var pixels:=texture.get_image()
 if pixels==null:return texture
 var used:=pixels.get_used_rect()
 if not used.has_area():return texture
 var atlas:=AtlasTexture.new()
 atlas.atlas=texture
 atlas.region=Rect2(used).grow(12).intersection(Rect2(Vector2.ZERO,Vector2(texture.get_size())))
 preview_textures[key]=atlas
 return atlas

func skin_button(button: Button) -> void:
 button.add_theme_stylebox_override("normal",surface(IntelSkin.STRUCTURE))
 button.add_theme_stylebox_override("hover",surface(IntelSkin.SLATE,IntelSkin.TEAL))
 button.add_theme_stylebox_override("pressed",surface(Color("285066"),IntelSkin.TEAL))
 button.add_theme_stylebox_override("focus",surface(Color.TRANSPARENT,IntelSkin.TEAL))
 button.add_theme_font_override("font",IntelSkin.face(600))
 button.add_theme_font_size_override("font_size",16)
 button.add_theme_color_override("font_color",IntelSkin.PAPER)
 button.add_theme_color_override("font_hover_color",IntelSkin.PAPER)
 button.add_theme_color_override("font_pressed_color",IntelSkin.TEAL)

func add_label(parent: Node, value: String, size: int = 22) -> Label:
 var label:=Label.new()
 label.text=value
 label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 label.add_theme_font_size_override("font_size",size)
 label.add_theme_color_override("font_color",IntelSkin.PAPER)
 label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 parent.add_child(label)
 return label

func refresh_if_needed() -> void:
 if not visible or not is_instance_valid(host) or host.game==null:return
 var point:=clampi(host.game.group_index-1,0,host.db.levels[host.game.stage-1].groups.size()-1)
 if route_stage==host.game.stage:
  if current_point!=point:
   current_point=point
   if follow_current:show_point(point)
   else:update_point_buttons()
  return
 route_builds+=1
 route_stage=host.game.stage
 current_point=point
 selected_point=-1
 selected=-1
 follow_current=true
 entries.clear()
 for child in point_bar.get_children():point_bar.remove_child(child);child.queue_free()
 point_buttons.clear()
 var level:Dictionary=host.db.levels[route_stage-1]
 stage_label.text=UIText.t("enemy.intel.stage",{"stage":str(route_stage)})
 for p in level.groups.size():
  var group:Dictionary=host.db.groups[str(int(level.groups[p].id))]
  var counts:Dictionary={}
  for id in group.slots:
   if id!=null:counts[str(int(id))]=int(counts.get(str(int(id)),0))+1
  for id in counts:entries.append({"id":id,"point":p,"count":counts[id]})
  var button:=Button.new()
  button.text=str(p+1)
  button.toggle_mode=true
  button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  button.pressed.connect(func():follow_current=false;show_point(p))
  skin_button(button)
  button.custom_minimum_size.y=42
  point_bar.add_child(button)
  point_buttons.append(button)
 show_point(current_point)

func update_point_buttons() -> void:
 follow_button.disabled=follow_current
 for i in point_buttons.size():
  var button:=point_buttons[i]
  button.set_pressed_no_signal(i==selected_point)
  button.text=UIText.t("enemy.intel.point_now",{"point":str(i+1)}) if i==current_point else str(i+1)
  var edge:=IntelSkin.TEAL if i==selected_point else IntelSkin.SLATE
  var fill:=Color("285066") if i==selected_point else IntelSkin.STRUCTURE
  button.add_theme_stylebox_override("normal",surface(fill,edge,6))
  button.add_theme_color_override("font_color",IntelSkin.TEAL if i==selected_point else IntelSkin.PAPER)

func show_point(point: int) -> void:
 if point<0 or selected_point==point:return
 selected_point=point
 selected=-1
 visible_entry_indices.clear()
 list.clear()
 for i in entries.size():
  var entry:Dictionary=entries[i]
  if int(entry.point)!=point:continue
  visible_entry_indices.append(i)
  var row:Dictionary=host.db.enemies[entry.id]
  var source:Dictionary={"archetype_id":str(row.get("intelVisualRef",row.get("archetype_id",""))),"armourType":row.armourType,"size":row.size}
  var texture:Texture2D=host.ship_hull_texture(host.enemy_visual_identity.resolve(source,host.visual_config))
  list.add_item(UIText.t("enemy.intel.ship_count",{"name":str(row.get("intelName",row.des)),"count":str(entry.count)}),preview_texture(texture))
  list.set_item_tooltip(list.item_count-1,str(row.get("intelTrait","")))
 update_point_buttons()
 if not visible_entry_indices.is_empty():list.select(0)
 show_entry(visible_entry_indices[0] if not visible_entry_indices.is_empty() else -1)

func show_entry(index: int) -> void:
 if index==selected:return
 detail_builds += 1
 selected = index
 detail_cursor = 0
 for line in detail_lines:line.visible = false
 if index<0:
  heading.text = UIText.t("enemy.intel.empty")
  image.visible = false
  return
 var entry: Dictionary = entries[index]
 var row: Dictionary = host.db.enemies[entry.id]
 heading.text = str(row.get("intelName",row.des))
 identity.text = UIText.t("enemy.intel.identity",{"point":str(int(entry.point)+1),"count":str(entry.count)})
 trait_label.text = str(row.get("intelTrait",""))
 var attack_types: Array[String] = []
 for mount in row.equipment:
  var kind := resistance_text(int(host.db.enemy_weapon(str(mount.name)).dmgtype))
  if not attack_types.has(kind):attack_types.append(kind)
 armour_badge.text = UIText.t("enemy.intel.armour_kind",{"type":resistance_text(int(row.armourType))})
 attack_badge.text = UIText.t("enemy.intel.attack_kind",{"type":" / ".join(attack_types)})
 image.visible = true
 var visual_ref := str(row.get("intelVisualRef",row.get("archetype_id","")))
 var visual_source := {"archetype_id":visual_ref,"armourType":row.armourType,"size":row.size}
 image.texture = preview_texture(host.ship_hull_texture(host.enemy_visual_identity.resolve(visual_source,host.visual_config)))
 add_detail_line(UIText.t("enemy.intel.identity",{"point":str(int(entry.point)+1),"count":str(entry.count)}))
 var summary := str(row.get("intelTrait",""))
 add_detail_line(summary if not summary.is_empty() else UIText.t("enemy.intel.missing"))
 if summary.is_empty():push_warning("Enemy intelligence missing for mon "+str(entry.id))
 var stage := route_stage
 var point := int(entry.point)
 var health = host.db.enemy_encounter_capacity(row,stage,point,"health")
 add_detail_line(UIText.t("enemy.intel.armour",{"health":host.number(health),"resistance":resistance_text(int(row.armourType))}))
 var shield = host.db.enemy_encounter_capacity(row,stage,point,"shield")
 add_detail_line(UIText.t("enemy.intel.shield",{"capacity":host.number(shield),"resistance":resistance_text(int(row.get("shieldType",0)))}))
 var attacks: Dictionary = {}
 for mount in row.equipment:
  attacks[str(mount.name)] = int(attacks.get(str(mount.name),0))+1
 for key in attacks:
  var weapon: Dictionary = host.db.enemy_weapon(str(key))
  var base_key := str(key).replace("_mon", "").replace("-mon", "")
  var weapon_name := UIText.t("weapon."+base_key+"_name") if base_key in ["laser","cannon","missile","longLaser"] else str(key)
  add_detail_line(UIText.t("enemy.intel.attack",{"name":weapon_name,"count":str(attacks[key]),"damage":host.number(host.db.enemy_attack_damage(row,weapon,stage,point)),"type":resistance_text(int(weapon.dmgtype)),"cooldown":duration_text(float(weapon.cd))}))
 var mechanics: Array = row.get("intelMechanics",[])
 if mechanics.is_empty():add_detail_line(UIText.t("enemy.intel.no_mechanic"))
 for mechanic in mechanics:
  match str(mechanic):
   "reactiveReduction":
    add_detail_line(UIText.t("enemy.intel.reactive",{"stacks":str(host.game.REACTIVE_STACK_LIMIT),"reduction":host.number(host.game.REACTIVE_STACK_REDUCTION*100.0),"window":duration_text(host.game.REACTIVE_RESET_SECONDS)}))
   "shieldRecovery":
    add_detail_line(UIText.t("enemy.intel.recovery",{"delay":duration_text(float(row.shieldDelay)),"rate":host.number(float(row.shieldRecovery)*100.0)}))

func duration_text(seconds: float) -> String:
 # Authored timers have millisecond precision; present their value in seconds.
 return str(snappedf(seconds,0.001))+" 秒"

func add_detail_line(value: String) -> void:
 if detail_cursor == detail_lines.size():
  var line := add_label(detail,"",22)
  line.visible = false
  detail_lines.append(line)
 var line := detail_lines[detail_cursor]
 line.text = value
 line.visible = true
 detail_cursor += 1

func resistance_text(value: int) -> String:
 return UIText.t("battle.enemy_defence.neutral") if value==0 else UIText.t("equipment.energy" if value==1 else "equipment.physical")
