extends Node2D
## Presentation only. One retained quad per beam/link; kernel owns every hit.
const BEAM_SHADER=preload("res://shaders/retained_beams.gdshader")
class Quad extends Node2D:
 var values:Array=[]
 var builds:int=0
 func _init()->void:
  material=ShaderMaterial.new();material.shader=BEAM_SHADER
 func _draw()->void:
  builds+=1
  # Conservative CPU culling bounds; vertex shader emits the actual narrow quad.
  draw_rect(Rect2(-128,-128,2304,256),Color.WHITE)
 func publish(start:Vector2,end:Vector2,state:Vector4,clock:float,cue:float,link:bool)->void:
  var delta:Vector2=end-start
  var angle:float=delta.angle() if delta.length_squared()>=0.25 else -PI/2
  position=start;rotation=angle
  var next:Array=[delta.length(),state,Vector4(clock,cue,angle,1.0 if link else 0.0)]
  if next==values:return
  if values.is_empty() or values[0]!=next[0]:material.set_shader_parameter("beam_length",next[0])
  if values.is_empty() or values[1]!=next[1]:material.set_shader_parameter("state",next[1])
  if values.is_empty() or values[2]!=next[2]:material.set_shader_parameter("timing",next[2])
  values=next
class Fallback extends Node2D:
 var scene
 var shot:Dictionary={}
 var offset:=Vector2.ZERO
 func _draw()->void:
  var previous=scene.draw_surface;scene.draw_surface=self
  scene.draw_foreground_beams([shot],offset)
  scene.draw_surface=previous
var records:Dictionary={}
var scene
var publications:int=0
func sync(owner,shots:Array,offset:Vector2)->void:
 scene=owner
 var present:Dictionary={};var order:int=0
 for shot in shots:
  if not shot.get("beam",false) or not owner.game.long_laser_valid(shot):continue
  var serial:int=int(shot.serial);present[serial]=true
  var gpu:bool=owner.prototype_enabled and owner.continuous_beam_enabled and not bool(shot.hostile)
  var row:Dictionary=records.get(serial,{})
  if not row.is_empty() and (not is_same(row.shot,shot) or row.gpu!=gpu):
   row.root.hide();row.root.queue_free();records.erase(serial);row={}
  if row.is_empty():
   var root:=Node2D.new();add_child(root)
   var body=Quad.new() if gpu else Fallback.new();root.add_child(body)
   row={"root":root,"body":body,"shot":shot,"gpu":gpu,"links":[]};records[serial]=row
  if row.root.get_index()!=order:move_child(row.root,order)
  order+=1
  if not gpu:
   row.body.scene=owner;row.body.shot=shot;row.body.offset=offset;row.body.queue_redraw();continue
  var start:Vector2=owner.battle_point(owner.visual_muzzle(shot))+offset
  var end:Vector2=owner.entity_render_position(shot.target)+offset
  var state:=Vector4(1,0,0,-2)
  var links:Array=[];var cue:float=-1.0
  if float(shot.charge)>0 and float(shot.elapsed)<float(shot.charge):state.w=clampf(float(shot.elapsed)/float(shot.charge),0,1)
  elif int(shot.ticks)>0:
   var style:Dictionary=owner.beam_style(shot);state=Vector4(style.width,style.power,style.pulse,-1)
   if owner.beam_full_started.has(serial):cue=owner.fx_time-float(owner.beam_full_started[serial])
   links=owner.game.beam_chain_targets(shot)
  row.body.publish(start,end,state,owner.fx_time,cue,false);publications+=1
  while row.links.size()>links.size():
   var tail=row.links.pop_back();tail.hide();tail.queue_free()
  while row.links.size()<links.size():
   var node=Quad.new();row.root.add_child(node);row.links.append(node)
  for index in links.size():row.links[index].publish(end,owner.entity_render_position(links[index])+offset,Vector4(1,0,0,-1),owner.fx_time,-1,true)
 for serial in records.keys():
  if not present.has(serial):
   records[serial].root.hide();records[serial].root.queue_free();records.erase(serial)
func clear()->void:
 for row in records.values():row.root.hide();row.root.queue_free()
 records.clear()
func metrics()->Dictionary:
 var builds:int=0;var links:int=0
 for row in records.values():
  if row.gpu:
   builds+=row.body.builds
   for node in row.links:builds+=node.builds;links+=1
 return {"beams":records.size(),"links":links,"live_quad_builds":builds,"publications":publications}
