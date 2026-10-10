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
 func update(values:Dictionary,key:Array)->void:
  if signature==key:return
  signature=key.duplicate(true);data=values;queue_redraw()
 func _draw()->void:
  builds+=1
  if kind=="foreground" or not data.is_empty():host.paint(self,kind,data)

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

func sync(offset:Vector2,boss:bool)->void:
 var live={}
 var screen_scale:float=paint_owner.enemy_recognition_screen_scale()
 for enemy in paint_owner.game.enemies:
  if enemy.hp<=0:continue
  var uid=int(enemy.uid);live[uid]=true
  if records.has(uid) and not is_same(records[uid].entity,enemy):
   records[uid].root.hide();records[uid].root.queue_free();records.erase(uid)
  if not records.has(uid):
   var root=Node2D.new();add_child(root)
   records[uid]={"entity":enemy,"root":root,"fallback":part(root,"fallback"),"mounts":[],"hull":part(root,"hull"),"deck":part(root,"deck"),"protection":part(root,"protection"),"health":part(root,"meter"),"shield":part(root,"meter")}
  var record:Dictionary=records[uid]
  move_child(record.root,get_child_count()-1)
  var components=paint_owner.enemy_weapon_components(enemy)
  var supported=not boss and not paint_owner.encounter_presentation.is_leader(enemy)
  for component in components:
   var visual_class=str(component.profile.get("visual_class",""))
   if not ((component.damage_type==2 and visual_class=="gun") or (component.damage_type==1 and visual_class=="energy")):supported=false
  record.fallback.visible=not supported
  for child in record.root.get_children():
   if child!=record.fallback:child.visible=supported
  if not supported:
   record.root.position=Vector2.ZERO
   record.fallback.update({"enemy":enemy,"offset":offset,"boss":boss},[paint_owner.fx_time,enemy,offset,boss])
   continue
  var pos:Vector2=paint_owner.enemy_render_position(enemy)+offset
  var width:float=paint_owner.enemy_render_width(enemy)
  var angle:float=paint_owner.enemy_render_angle(enemy)
  record.root.position=pos
  var light:float=paint_owner.enemy_hull_light(enemy)
  record.hull.rotation=PI+angle
  record.hull.update({"width":width,"light":light,"texture":paint_owner.ship_hull_texture("enemy_"+str(clampi(int(enemy.size),1,6)))},[width,int(enemy.size),light])
  record.deck.rotation=PI+angle
  var types:Array=paint_owner.enemy_attack_types(enemy)
  record.deck.update({"width":width,"types":types},[width,types])
  var packet:Dictionary=paint_owner.enemy_recognition_geometry(enemy,width)
  var status:Dictionary=paint_owner.enemy_recognition.state(enemy,paint_owner.game.enemy_shield_time,paint_owner.game.paused,paint_owner.enemy_pose(enemy))
  record.protection.rotation=PI+angle
  var key=[packet.inner,packet.outer,packet.front,packet.single_front,packet.hull_stroke,packet.shield_stroke,packet.scale,status,int(enemy.get("armourType",0)),int(enemy.get("shieldType",0)),int(enemy.size)]
  if status.repair:key.append(width)
  if status.recovering:key.append(paint_owner.game.enemy_shield_time)
  record.protection.update({"enemy":enemy,"width":width,"packet":packet,"status":status,"clock":paint_owner.game.enemy_shield_time},key)
  # Return geometry follows the same branch order as draw_protection, even when
  # native commands are retained. It remains authoritative for meter placement.
  var outline:PackedVector2Array=packet.inner
  if not status.alive: outline=PackedVector2Array()
  elif status.active and int(enemy.get("shieldType",0)) in [0,1,2]:
   outline=packet.outer if status.show_hull and int(enemy.get("armourType",0)) in [1,2] else packet.inner
   if int(enemy.get("shieldType",0))==1 and int(enemy.size)>=4:outline=packet.front if status.show_hull and int(enemy.get("armourType",0)) in [1,2] else packet.single_front
  elif not (status.show_hull and int(enemy.get("armourType",0)) in [1,2]) and not status.repair:outline=PackedVector2Array()
  var layout:Dictionary=paint_owner.enemy_status_layout(enemy,pos,width,angle,outline)
  meter(record.health,layout.health,pos,float(enemy.hp)/maxf(1,float(enemy.max_hp)),paint_owner.BATTLE_WARM)
  record.shield.visible=float(enemy.get("max_shield",0))>0
  if record.shield.visible:meter(record.shield,layout.shield,pos,float(enemy.shield)/float(enemy.max_shield),paint_owner.ENEMY_RECOGNITION.shield_color(int(enemy.get("shieldType",0))))
  if record.mounts.size()!=components.size():
   for item in record.mounts:item.hide();item.queue_free()
   record.mounts.clear()
   for component in components:record.mounts.append(part(record.root,"weapon"))
  for index in components.size():
   var component=components[index]
   var node:Part=record.mounts[index]
   var pose:Dictionary=paint_owner.enemy_component_pose(enemy,component,Vector2.INF,width)
   var physical=component.damage_type==2
   var w=maxf(15.0/maxf(0.1,screen_scale),float(pose.width))
   var shift:Vector2=Vector2(pose.port)-Vector2((0.64 if physical else 0.45)*w,0)
   node.position=Vector2(pose.origin)+shift.rotated(pose.angle)
   node.rotation=float(pose.angle)-PI/2
   node.update({"width":w,"physical":physical},[w,physical])
   # Preserve the existing under-hull/over-hull painter ordering.
  var ordered=[record.fallback]
  for index in components.size():
   if int(components[index].hardpoint.get("z",1))<=0:ordered.append(record.mounts[index])
  ordered.append_array([record.hull,record.deck,record.protection])
  for index in components.size():
   if int(components[index].hardpoint.get("z",1))>0:ordered.append(record.mounts[index])
  ordered.append_array([record.health,record.shield])
  for index in ordered.size():record.root.move_child(ordered[index],index)
 for uid in records.keys():
  if not live.has(uid):records[uid].root.hide();records[uid].root.queue_free();records.erase(uid)
 move_child(foreground,get_child_count()-1)

func meter(node:Part,rect:Rect2,pos:Vector2,ratio:float,color:Color)->void:
 node.position=rect.position-pos
 node.update({"rect":Rect2(Vector2.ZERO,rect.size),"ratio":ratio,"color":color},[rect.size,ratio,color])

func stage_foreground(flights:Array,shots:Array,offset:Vector2)->void:
 frame={"flights":flights,"shots":shots,"offset":offset}
 saved_positions=paint_owner.battle_draw_enemy_positions.duplicate()
 foreground.queue_redraw()

func paint(surface:Part,kind:String,data:Dictionary)->void:
 var previous=paint_owner.draw_surface;paint_owner.draw_surface=surface
 match kind:
  "hull":
   var dimensions=Vector2(data.width,data.width*2.0)
   surface.draw_texture_rect(data.texture,Rect2(-dimensions/2,dimensions),false,Color(data.light,data.light,data.light,1.0))
  "deck":paint_owner.enemy_recognition.draw_attack_deck(surface,data.width,data.types)
  "weapon":paint_owner.enemy_recognition.draw_weapon_shape(surface,data.width,data.physical)
  "protection":paint_owner.enemy_recognition.draw_protection(surface,data.enemy,data.width,data.packet,data.status,data.clock)
  "meter":paint_owner.battle_meter(data.rect,data.ratio,data.color)
  "fallback":paint_owner.draw_enemy_hull_and_status(data.enemy,data.offset,data.boss)
  "foreground":
   if frame.is_empty():paint_owner.draw_surface=previous;return
   paint_owner.battle_draw_active=true;paint_owner.enemy_entry_batch_active=true
   paint_owner.battle_draw_enemy_positions=saved_positions.duplicate()
   paint_owner.draw_battle_foreground(frame.flights,frame.shots,frame.offset)
 paint_owner.draw_surface=previous
