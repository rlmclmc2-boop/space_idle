extends Node2D
## Native Canvas command owners. Motion updates transforms; true shape/status
## changes rebuild only their own part. No textures, offscreen views or scaling
## approximation. Unrecognized mounts and leaders use the original painter.
class Part extends Node2D:
 var host
 var kind:String
 var data:Dictionary
 var signature:Array=[]
 var builds:=0
 var pieces:Dictionary={}
 func update(values:Dictionary,key:Array)->void:
  if signature==key:return
  signature=key.duplicate(true);data=values;queue_redraw()
 func _draw()->void:
  builds+=1
  if kind=="foreground" or not data.is_empty():host.paint(self,kind,data)

class MountRecord extends RefCounted:
 var node:Part
 var physical:bool
 var normalized:Vector2
 var module_factor:float
 var port_factor:Vector2
 var base_rotation:float
 var aim_limit:float
 var aim_factor:float
 var under:bool

class DisplayRecord extends RefCounted:
 var entity:Dictionary
 var root:Node2D
 var fallback:Part
 var hull:Part
 var deck:Part
 var protection:Part
 var health:Part
 var shield:Part
 var mounts:Array[MountRecord]=[]
 var shape_revision:int=-1
 var supported:bool=false
 var boss:bool=false
 var texture:Texture2D
 var used:Rect2
 var corners:PackedVector2Array
 var descriptors:Array=[]
 var pose:Dictionary
 var packet:Dictionary={}
 var status:Dictionary={}
 var protection_width:float=-INF
 var protection_clock:float=-INF
 var armour:int=-1
 var shield_type:int=-1
 var size:int=-1
 var screen_scale:float
 var protection_gap:float=-INF
 var layer_gap:float=-INF
 var physical:bool=false
 var energy:bool=false
 var alive:bool=false

var paint_owner
var records:Dictionary={}
var foreground:Part
var frame:Dictionary={}
var saved_positions:Dictionary={}

func setup(scene)->void:
 paint_owner=scene
 foreground=Part.new();foreground.host=self;foreground.kind="foreground"
 add_child(foreground)

func part(root:Node2D,kind:String)->Part:
 var result=Part.new();result.host=self;result.kind=kind
 root.add_child(result)
 return result

func build_deck(parent:Node2D)->Part:
 var group=part(parent,"deck_group")
 for kind in ["deck_physical_body","deck_physical_strokes","deck_energy_body","deck_energy_strokes"]:group.pieces[kind]=part(group,kind)
 return group

func build_weapon(parent:Node2D)->Part:
 var group=part(parent,"weapon_group")
 group.pieces.body=part(group,"weapon_body");group.pieces.strokes=part(group,"weapon_strokes")
 return group

func create_record(enemy:Dictionary)->DisplayRecord:
 var record=DisplayRecord.new();record.entity=enemy
 record.root=Node2D.new();add_child(record.root)
 record.fallback=part(record.root,"fallback");record.hull=part(record.root,"hull")
 record.deck=build_deck(record.root);record.protection=part(record.root,"protection")
 record.health=part(record.root,"meter");record.shield=part(record.root,"meter")
 record.health.data={"rect":Rect2(),"ratio":-INF,"color":paint_owner.BATTLE_WARM}
 record.shield.data={"rect":Rect2(),"ratio":-INF,"color":Color.WHITE}
 record.protection.data={"enemy":enemy,"width":0.0,"packet":{},"status":record.status,"clock":0.0}
 return record

func compile_record(record:DisplayRecord,spatial:Dictionary,boss:bool)->void:
 var enemy=record.entity
 record.shape_revision=int(spatial.shape_revision);record.boss=boss
 record.pose=paint_owner.enemy_pose(enemy)
 record.screen_scale=paint_owner.enemy_recognition_screen_scale()
 record.texture=paint_owner.ship_hull_texture("enemy_"+str(clampi(int(enemy.size),1,6)))
 record.used=paint_owner.enemy_hull_bounds(record.texture)
 record.corners=PackedVector2Array([record.used.position,Vector2(record.used.end.x,record.used.position.y),record.used.end,Vector2(record.used.position.x,record.used.end.y)])
 record.descriptors=record.pose.recognition_mounts
 record.supported=not boss and not paint_owner.encounter_presentation.is_leader(enemy)
 var components:Array=spatial.components
 for component in components:
  var visual_class=str(component.profile.get("visual_class",""))
  if not ((component.damage_type==2 and visual_class=="gun") or (component.damage_type==1 and visual_class=="energy")):record.supported=false
 record.physical=false;record.energy=false
 for damage_type in paint_owner.enemy_attack_types(enemy):
  if damage_type==2:record.physical=true
  if damage_type==1:record.energy=true
 for mount in record.mounts:mount.node.hide();mount.node.queue_free()
 record.mounts.clear()
 record.fallback.visible=not record.supported
 for node in [record.hull,record.deck,record.protection,record.health,record.shield]:node.visible=record.supported
 if not record.supported:return
 record.hull.data={"texture":record.texture};record.hull.queue_redraw()
 for physical in [true,false]:
  var prefix="deck_physical_" if physical else "deck_energy_"
  var body:Part=record.deck.pieces[prefix+"body"]
  var strokes:Part=record.deck.pieces[prefix+"strokes"]
  var enabled=record.physical if physical else record.energy
  body.visible=enabled;strokes.visible=enabled
  body.data={"physical":physical};body.queue_redraw()
  strokes.data={"width":-INF,"physical":physical}
 for component in components:
  var mount=MountRecord.new();mount.node=build_weapon(record.root)
  mount.physical=component.damage_type==2
  var point:Dictionary=component.hardpoint
  mount.normalized=Vector2(float(point.pos[0]),float(point.pos[1])*2.0)
  mount.module_factor=0.42*float({"small":0.7,"medium":0.9,"large":1.1}.get(str(point.get("visual_size_class","small")),0.7))
  mount.base_rotation=deg_to_rad(float(point.get("base_rotation",0)))
  var muzzle:Array=component.profile.get("muzzle",[[0.22,0]])
  mount.port_factor=Vector2(float(muzzle[0][0]),float(muzzle[0][1]))
  # The canonical aim chooses the first component owning owner_slot. Resolve
  # that same owner once; grouping/overlapping slots retain their old meaning.
  var aim_component=paint_owner.enemy_component_for_slot(enemy,component.owner_slot)
  var role:String=aim_component.mode() if aim_component!=null else ""
  mount.aim_factor=1.0 if role=="main" else 0.2 if role=="secondary" else 0.0
  mount.aim_limit=deg_to_rad(float(aim_component.hardpoint.get("rotation_limit",0))) if aim_component!=null else 0.0
  mount.under=int(point.get("z",1))<=0
  mount.node.pieces.body.data={"physical":mount.physical};mount.node.pieces.body.queue_redraw()
  mount.node.pieces.strokes.visible=not mount.physical
  mount.node.pieces.strokes.data={"width":-INF}
  record.mounts.append(mount)
 # Stable paint order is compiled only when identity/appearance changes.
 var ordered:Array=[record.fallback]
 for mount in record.mounts:
  if mount.under:ordered.append(mount.node)
 ordered.append_array([record.hull,record.deck,record.protection])
 for mount in record.mounts:
  if not mount.under:ordered.append(mount.node)
 ordered.append_array([record.health,record.shield])
 for index in ordered.size():record.root.move_child(ordered[index],index)
 record.packet={};record.protection_width=-INF;record.protection_clock=-INF

func sync(offset:Vector2,boss:bool)->void:
 var live={};var order_changed=false
 var model=paint_owner.battle_read_model
 for enemy in paint_owner.game.enemies:
  var uid=int(enemy.uid);live[uid]=true
  var record:DisplayRecord=records.get(uid)
  if record!=null and not is_same(record.entity,enemy):
   record.root.hide();record.root.queue_free();records.erase(uid);record=null;order_changed=true
  if record==null:
   if enemy.hp<=0:continue
   record=create_record(enemy);records[uid]=record;order_changed=true
  var alive:bool=enemy.hp>0
  if record.alive!=alive:record.alive=alive;record.root.visible=alive;order_changed=true
  if not alive:continue
  var spatial:Dictionary=model.entry(enemy)
  if record.shape_revision!=int(spatial.shape_revision) or record.boss!=boss:compile_record(record,spatial,boss)
  if not record.supported:
   record.root.position=Vector2.ZERO
   record.fallback.update({"enemy":enemy,"offset":offset,"boss":boss},[paint_owner.fx_time,enemy,offset,boss])
   continue
  update_record(record,spatial,offset)
 for uid in records.keys():
  if not live.has(uid):records[uid].root.hide();records[uid].root.queue_free();records.erase(uid);order_changed=true
 # Do not scan child indices or reconstitute per-part order in the steady path.
 if order_changed:
  var index=0
  for enemy in paint_owner.game.enemies:
   var record:DisplayRecord=records.get(int(enemy.uid))
   if record==null:continue
   move_child(record.root,index);index+=1
  move_child(foreground,get_child_count()-1)

func update_record(record:DisplayRecord,spatial:Dictionary,offset:Vector2)->void:
 var enemy=record.entity
 var point:Vector2=spatial.position
 var pos=point+offset
 var width:float=paint_owner.battle_read_model.width_at(enemy,point.y)
 var angle:float=paint_owner.enemy_render_angle(enemy)
 var depth=clampf((point.y-90.0)/maxf(1.0,float(spatial.frontline)-90.0),0,1)
 var light=lerpf(1.18,1.30,depth) if int(enemy.size)<=2 else lerpf(0.76,1.0,depth)
 record.root.position=pos;record.hull.rotation=PI+angle
 record.hull.scale=Vector2.ONE*width;record.hull.self_modulate=Color(light,light,light,1)
 record.deck.rotation=PI+angle
 for prefix in ["deck_physical_","deck_energy_"]:
  var body:Part=record.deck.pieces[prefix+"body"]
  if not body.visible:continue
  body.scale=Vector2.ONE*width
  set_stroke_width(record.deck.pieces[prefix+"strokes"],width)
 var repair:bool=float(enemy.get("max_shield",0))>0 and float(enemy.get("shieldRecovery",0))>0
 var packet:Dictionary=paint_owner.enemy_recognition.geometry(record.texture,width,record.descriptors,repair,record.pose,record.screen_scale,int(enemy.size)>=4)
 var old_alive:bool=record.status.get("alive",false)
 var old_active:bool=record.status.get("active",false)
 var old_repair:bool=record.status.get("repair",false)
 var old_fraction:float=record.status.get("fraction",-INF)
 var old_recovering:bool=record.status.get("recovering",false)
 var old_hull:bool=record.status.get("show_hull",false)
 paint_owner.enemy_recognition.state(enemy,paint_owner.game.enemy_shield_time,paint_owner.game.paused,record.pose,record.status)
 var status=record.status
 var armour=int(enemy.get("armourType",0));var shield_type=int(enemy.get("shieldType",0));var size=int(enemy.size)
 var changed=not is_same(record.packet,packet) or old_alive!=status.alive or old_active!=status.active or old_repair!=status.repair or old_fraction!=status.fraction or old_recovering!=status.recovering or old_hull!=status.show_hull or record.armour!=armour or record.shield_type!=shield_type or record.size!=size
 if status.repair and record.protection_width!=width:changed=true
 if status.recovering and record.protection_clock!=paint_owner.game.enemy_shield_time:changed=true
 record.packet=packet;record.armour=armour;record.shield_type=shield_type;record.size=size
 record.protection_width=width;record.protection_clock=paint_owner.game.enemy_shield_time
 record.protection.rotation=PI+angle
 if changed:
  record.protection.data.width=width;record.protection.data.packet=packet;record.protection.data.clock=paint_owner.game.enemy_shield_time
  record.protection.queue_redraw()
 var outline:PackedVector2Array=packet.inner
 if not status.alive:outline=PackedVector2Array()
 elif status.active and shield_type in [0,1,2]:
  outline=packet.outer if status.show_hull and armour in [1,2] else packet.inner
  if shield_type==1 and size>=4:outline=packet.front if status.show_hull and armour in [1,2] else packet.single_front
 elif not (status.show_hull and armour in [1,2]) and not status.repair:outline=PackedVector2Array()
 update_meters(record,pos,width,angle,outline)
 var desired=wrapf((paint_owner.player_render_position()-point).angle()-PI/2-angle,-PI,PI)
 var min_width=15.0/maxf(0.1,record.screen_scale)
 for mount in record.mounts:
  var module_width=width*mount.module_factor
  var w=maxf(min_width,module_width)
  var mount_angle=PI/2+angle+clampf(desired,-mount.aim_limit,mount.aim_limit)*mount.aim_factor+mount.base_rotation
  var origin=(mount.normalized*width).rotated(PI+angle)
  var shift=mount.port_factor*module_width-Vector2((0.64 if mount.physical else 0.45)*w,0)
  mount.node.position=origin+shift.rotated(mount_angle);mount.node.rotation=mount_angle-PI/2
  mount.node.pieces.body.scale=Vector2.ONE*w
  if not mount.physical:set_stroke_width(mount.node.pieces.strokes,w)

func set_stroke_width(node:Part,width:float)->void:
 if node.data.width==width:return
 node.data.width=width;node.queue_redraw()

func update_meters(record:DisplayRecord,pos:Vector2,width:float,angle:float,outline:PackedVector2Array)->void:
 # Ordinary contacts draw only meters. Leader/caption consumers keep the full
 # canonical enemy_status_layout through the unsupported painter above.
 var top:float=pos.y
 for corner in record.corners:top=minf(top,pos.y+(corner*Vector2(width,width*2.0)).rotated(PI+angle).y)
 for point in outline:top=minf(top,pos.y+point.rotated(PI+angle).y)
 top-=9.0
 var bar_width=clampf(width*record.used.size.x,28,100)
 var left=clampf(pos.x-bar_width*0.5,6,paint_owner.BATTLE_VIEW_SIZE.x-bar_width-6)
 var enemy=record.entity
 if enemy.get("explicit_formation",false) and absf(float(enemy.x)-paint_owner.BATTLE_VIEW_SIZE.x*0.5)>150.0:
  left=clampf(pos.x if pos.x>=paint_owner.BATTLE_VIEW_SIZE.x*0.5 else pos.x-bar_width,6,paint_owner.BATTLE_VIEW_SIZE.x-bar_width-6)
 meter(record.health,Vector2(left,maxf(6,top))-pos,Vector2(bar_width,4),float(enemy.hp)/maxf(1,float(enemy.max_hp)),paint_owner.BATTLE_WARM)
 record.shield.visible=float(enemy.get("max_shield",0))>0
 if record.shield.visible:meter(record.shield,Vector2(left,maxf(6,top-7))-pos,Vector2(bar_width,4),float(enemy.shield)/float(enemy.max_shield),paint_owner.ENEMY_RECOGNITION.shield_color(int(enemy.get("shieldType",0))))

func meter(node:Part,position_value:Vector2,size_value:Vector2,ratio:float,color:Color)->void:
 node.position=position_value
 if node.data.rect.size==size_value and node.data.ratio==ratio and node.data.color==color:return
 node.data.rect=Rect2(Vector2.ZERO,size_value);node.data.ratio=ratio;node.data.color=color
 node.queue_redraw()

func stage_foreground(flights:Array,shots:Array,offset:Vector2)->void:
 frame={"flights":flights,"shots":shots,"offset":offset}
 saved_positions=paint_owner.battle_draw_enemy_positions.duplicate()
 foreground.queue_redraw()

func paint(surface:Part,kind:String,data:Dictionary)->void:
 var previous=paint_owner.draw_surface;paint_owner.draw_surface=surface
 match kind:
  "hull":
   surface.draw_texture_rect(data.texture,Rect2(Vector2(-0.5,-1.0),Vector2(1.0,2.0)),false,Color.WHITE)
  "deck_physical_body","deck_energy_body":paint_owner.enemy_recognition.draw_deck_body(surface,1.0,data.physical)
  "deck_physical_strokes","deck_energy_strokes":paint_owner.enemy_recognition.draw_deck_strokes(surface,data.width,data.physical)
  "weapon_body":paint_owner.enemy_recognition.draw_weapon_body(surface,1.0,data.physical)
  "weapon_strokes":paint_owner.enemy_recognition.draw_weapon_strokes(surface,data.width)
  "protection":paint_owner.enemy_recognition.draw_protection(surface,data.enemy,data.width,data.packet,data.status,data.clock)
  "meter":paint_owner.battle_meter(data.rect,data.ratio,data.color)
  "fallback":paint_owner.draw_enemy_hull_and_status(data.enemy,data.offset,data.boss)
  "foreground":
   if frame.is_empty():paint_owner.draw_surface=previous;return
   paint_owner.battle_draw_active=true;paint_owner.enemy_entry_batch_active=true
   paint_owner.battle_draw_enemy_positions=saved_positions.duplicate()
   paint_owner.draw_battle_foreground(frame.flights,frame.shots,frame.offset)
 paint_owner.draw_surface=previous
