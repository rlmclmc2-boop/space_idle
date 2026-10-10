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
 var stroke_kind=""
 var stroke_width=-INF
 func update(values:Dictionary,key:Array)->void:
  if signature==key:return
  signature=key.duplicate(true);data=values;queue_redraw()
 func _draw()->void:
  builds+=1
  if kind=="foreground" or not data.is_empty():host.paint(self,kind,data)

var stroke_geometry=preload("res://scripts/resident_stroke_geometry.gd").new()
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

func update_stroke(node:Part,kind:String,width:float)->void:
 if node.stroke_kind!=kind:
  var packet=stroke_geometry.asset(kind)
  node.material=stroke_geometry.material_for(packet)
  node.stroke_kind=kind;node.stroke_width=-INF
  node.update({"mesh":packet.mesh},[kind])
 if node.stroke_width==width:return
 node.stroke_width=width;node.material.set_shader_parameter("shape_width",width)
 # Shader displacement is not visible to Canvas culling. Publish a conservative
 # local bound at the same size boundary, without recreating commands or mesh.
 RenderingServer.canvas_item_set_custom_rect(node.get_canvas_item(),true,Rect2(Vector2(-0.65,-0.15)*width-Vector2.ONE*8,Vector2(1.3,0.85)*width+Vector2.ONE*16))

func sync(offset:Vector2,boss:bool)->void:
 var live={}
 var order_index=0
 var screen_scale:float=paint_owner.enemy_recognition_screen_scale()
 for enemy in paint_owner.game.enemies:
  if enemy.hp<=0:continue
  var uid=int(enemy.uid);live[uid]=true
  if records.has(uid) and not is_same(records[uid].entity,enemy):
   records[uid].root.hide();records[uid].root.queue_free();records.erase(uid)
  if not records.has(uid):
   var root=Node2D.new();add_child(root)
   records[uid]={"entity":enemy,"root":root,"fallback":part(root,"fallback"),"mounts":[],"hull":part(root,"hull"),"deck":build_deck(root),"protection":part(root,"protection"),"health":part(root,"meter"),"shield":part(root,"meter")}
  var record:Dictionary=records[uid]
  if record.root.get_index()!=order_index:move_child(record.root,order_index)
  order_index+=1
  var publication:Dictionary=paint_owner.battle_read_model.display_contact(enemy,offset,boss)
  var components:Array=publication.components
  var supported:bool=publication.supported
  record.fallback.visible=not supported
  for child in record.root.get_children():
   if child!=record.fallback:child.visible=supported
  if not supported:
   record.root.position=Vector2.ZERO
   record.fallback.update({"enemy":enemy,"offset":offset,"boss":boss},[paint_owner.fx_time,enemy,offset,boss])
   continue
  var pos:Vector2=publication.position
  var width:float=publication.width
  var angle:float=publication.angle
  record.root.position=pos
  var light:float=publication.light
  record.hull.rotation=PI+angle
  record.hull.scale=Vector2.ONE*width
  record.hull.self_modulate=Color(light,light,light,1.0)
  var texture=paint_owner.ship_hull_texture("enemy_"+str(clampi(int(enemy.size),1,6)))
  record.hull.update({"texture":texture},[texture.get_instance_id()])
  record.deck.rotation=PI+angle
  var types:Array=publication.types
  for physical in [true,false]:
   var prefix="deck_physical_" if physical else "deck_energy_"
   var body:Part=record.deck.pieces[prefix+"body"]
   var strokes:Part=record.deck.pieces[prefix+"strokes"]
   var enabled=types.has(2 if physical else 1)
   body.visible=enabled;strokes.visible=enabled
   if enabled:
    body.scale=Vector2.ONE*width
    body.update({"physical":physical},[physical])
    update_stroke(strokes,"deck_physical" if physical else "deck_energy",width)
  var packet:Dictionary=publication.packet
  var status:Dictionary=publication.status
  record.protection.rotation=PI+angle
  var key=[packet.inner,packet.outer,packet.front,packet.single_front,packet.hull_stroke,packet.shield_stroke,packet.scale,status,int(enemy.get("armourType",0)),int(enemy.get("shieldType",0)),int(enemy.size)]
  if status.repair:key.append(width)
  if status.recovering:key.append(paint_owner.game.enemy_shield_time)
  record.protection.update({"enemy":enemy,"width":width,"packet":packet,"status":status,"clock":paint_owner.game.enemy_shield_time},key)
  var layout:Dictionary=publication.layout
  meter(record.health,layout.health,pos,float(enemy.hp)/maxf(1,float(enemy.max_hp)),paint_owner.BATTLE_WARM)
  record.shield.visible=float(enemy.get("max_shield",0))>0
  if record.shield.visible:meter(record.shield,layout.shield,pos,float(enemy.shield)/float(enemy.max_shield),paint_owner.ENEMY_RECOGNITION.shield_color(int(enemy.get("shieldType",0))))
  if record.mounts.size()!=components.size():
   for item in record.mounts:item.hide();item.queue_free()
   record.mounts.clear()
   for component in components:record.mounts.append(build_weapon(record.root))
  for index in components.size():
   var component=components[index]
   var node:Part=record.mounts[index]
   var pose:Dictionary=publication.mounts[index]
   var physical=component.damage_type==2
   var w=maxf(15.0/maxf(0.1,screen_scale),float(pose.width))
   var shift:Vector2=Vector2(pose.port)-Vector2((0.64 if physical else 0.45)*w,0)
   node.position=Vector2(pose.origin)+shift.rotated(pose.angle)
   node.rotation=float(pose.angle)-PI/2
   var body:Part=node.pieces.body
   var strokes:Part=node.pieces.strokes
   body.scale=Vector2.ONE*w
   body.update({"physical":physical},[physical])
   strokes.visible=not physical
   if not physical:update_stroke(strokes,"weapon_energy",w)
   # Preserve the existing under-hull/over-hull painter ordering.
  var ordered=[record.fallback]
  for index in components.size():
   if int(components[index].hardpoint.get("z",1))<=0:ordered.append(record.mounts[index])
  ordered.append_array([record.hull,record.deck,record.protection])
  for index in components.size():
   if int(components[index].hardpoint.get("z",1))>0:ordered.append(record.mounts[index])
  ordered.append_array([record.health,record.shield])
  for index in ordered.size():
   if ordered[index].get_index()!=index:record.root.move_child(ordered[index],index)
 for uid in records.keys():
  if not live.has(uid):records[uid].root.hide();records[uid].root.queue_free();records.erase(uid)
 if foreground.get_index()!=get_child_count()-1:move_child(foreground,get_child_count()-1)

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
   surface.draw_texture_rect(data.texture,Rect2(Vector2(-0.5,-1.0),Vector2(1.0,2.0)),false,Color.WHITE)
  "deck_physical_body","deck_energy_body":paint_owner.enemy_recognition.draw_deck_body(surface,1.0,data.physical)
  "deck_physical_strokes","deck_energy_strokes":surface.draw_mesh(data.mesh)
  "weapon_body":paint_owner.enemy_recognition.draw_weapon_body(surface,1.0,data.physical)
  "weapon_strokes":surface.draw_mesh(data.mesh)
  "protection":paint_owner.enemy_recognition.draw_protection(surface,data.enemy,data.width,data.packet,data.status,data.clock)
  "meter":paint_owner.battle_meter(data.rect,data.ratio,data.color)
  "fallback":paint_owner.draw_enemy_hull_and_status(data.enemy,data.offset,data.boss)
  "foreground":
   if frame.is_empty():paint_owner.draw_surface=previous;return
   paint_owner.battle_draw_active=true;paint_owner.enemy_entry_batch_active=true
   paint_owner.battle_draw_enemy_positions=saved_positions.duplicate()
   paint_owner.draw_battle_foreground(frame.flights,frame.shots,frame.offset)
 paint_owner.draw_surface=previous
