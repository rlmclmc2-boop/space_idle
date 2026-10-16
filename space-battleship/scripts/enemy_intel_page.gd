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

func surface(fill: Color, border: Color = IntelSkin.SLATE) -> StyleBoxFlat:
 var box := StyleBoxFlat.new()
 box.bg_color=fill
 box.border_color=border
 box.set_border_width_all(1)
 box.set_corner_radius_all(12)
 box.content_margin_left=20
 box.content_margin_right=20
 box.content_margin_top=16
 box.content_margin_bottom=16
 return box

func setup(owner: Node) -> void:
 host=owner
 name="EnemyIntel"
 var margin := MarginContainer.new()
 margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,16)
 add_child(margin)
 var layout := VBoxContainer.new()
 layout.add_theme_constant_override("separation",18)
 margin.add_child(layout)
 var header := HBoxContainer.new()
 layout.add_child(header)
 stage_label=add_label(header,"",28)
 stage_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 var follow := Button.new()
 follow.text=UIText.t("enemy.intel.current")
 follow.pressed.connect(func():follow_current=true;show_point(current_point))
 skin_button(follow)
 header.add_child(follow)
 point_bar=HBoxContainer.new()
 point_bar.add_theme_constant_override("separation",8)
 layout.add_child(point_bar)
 var body := HBoxContainer.new()
 body.size_flags_vertical=Control.SIZE_EXPAND_FILL
 body.add_theme_constant_override("separation",18)
 layout.add_child(body)
 var roster := PanelContainer.new()
 roster.custom_minimum_size.x=270
 roster.add_theme_stylebox_override("panel",surface(IntelSkin.STRUCTURE))
 body.add_child(roster)
 var roster_layout := VBoxContainer.new()
 roster_layout.add_theme_constant_override("separation",16)
 roster.add_child(roster_layout)
 add_label(roster_layout,UIText.t("enemy.intel.roster"),18).modulate=IntelSkin.TEAL
 list=ItemList.new()
 list.size_flags_vertical=Control.SIZE_EXPAND_FILL
 list.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
 list.add_theme_stylebox_override("selected",surface(IntelSkin.SLATE,IntelSkin.TEAL))
 list.add_theme_stylebox_override("selected_focus",surface(IntelSkin.SLATE,IntelSkin.TEAL))
 list.add_theme_font_size_override("font_size",20)
 list.add_theme_constant_override("v_separation",22)
 list.fixed_icon_size=Vector2i(44,56)
 list.item_selected.connect(func(i:int):show_entry(visible_entry_indices[i]))
 roster_layout.add_child(list)
 var dossier := PanelContainer.new()
 dossier.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 dossier.add_theme_stylebox_override("panel",surface(IntelSkin.NAVY,IntelSkin.SLATE))
 body.add_child(dossier)
 var sheet := VBoxContainer.new()
 sheet.add_theme_constant_override("separation",14)
 dossier.add_child(sheet)
 identity=add_label(sheet,"",18)
 identity.modulate=IntelSkin.TEAL
 heading=add_label(sheet,"",34)
 var portrait := PanelContainer.new()
 portrait.custom_minimum_size.y=340
 portrait.size_flags_vertical=Control.SIZE_EXPAND_FILL
 portrait.add_theme_stylebox_override("panel",surface(IntelSkin.STRUCTURE))
 sheet.add_child(portrait)
 image=TextureRect.new()
 image.custom_minimum_size=Vector2(220,220)
 image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 portrait.add_child(image)
 trait_label=add_label(sheet,"",22)
 var badges := HBoxContainer.new()
 badges.add_theme_constant_override("separation",22)
 sheet.add_child(badges)
 armour_badge=add_label(badges,"",19)
 attack_badge=add_label(badges,"",19)
 armour_badge.modulate=IntelSkin.TEAL
 attack_badge.modulate=Color("e9c48b")
 details_button=Button.new()
 details_button.text=UIText.t("enemy.intel.details")
 details_button.toggle_mode=true
 skin_button(details_button)
 details_button.toggled.connect(func(on:bool):detail_scroll.visible=on)
 sheet.add_child(details_button)
 detail_scroll=ScrollContainer.new()
 detail_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
 detail_scroll.custom_minimum_size.y=120
 detail_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 detail_scroll.visible=false
 sheet.add_child(detail_scroll)
 detail=VBoxContainer.new()
 detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 detail.add_theme_constant_override("separation",10)
 detail_scroll.add_child(detail)
 for index in 10:
  var line:=add_label(detail,"",18)
  line.visible=false
  detail_lines.append(line)
 visibility_changed.connect(refresh_if_needed)

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
 button.add_theme_stylebox_override("pressed",surface(IntelSkin.SLATE,IntelSkin.TEAL))
 button.add_theme_font_size_override("font_size",18)

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
  point_bar.add_child(button)
  point_buttons.append(button)
 show_point(current_point)

func update_point_buttons() -> void:
 for i in point_buttons.size():
  point_buttons[i].set_pressed_no_signal(i==selected_point)
  point_buttons[i].text=UIText.t("enemy.intel.point_now",{"point":str(i+1)}) if i==current_point else str(i+1)

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
 # Every authored enemy timer and the reactive reset interval is in whole milliseconds.
 return str(roundi(seconds*1000.0))+" 毫秒"

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
