extends Node2D
## Presentation only. One instance stream per beam; kernel owns every hit.
const BEAM_SHADER=preload("res://shaders/retained_beams.gdshader")
class BeamBatch extends MultiMeshInstance2D:
 # One instance stream per original beam preserves ordering across fallback
 # painters. Color/custom data carry unbounded float shader parameters.
 var buffer:=PackedFloat32Array()
 var capacity:int=0
 var used:int=0
 var builds:int=0
 var uploads:int=0
 var bounds:=Rect2()
 var valid_clock:bool=true
 func _init()->void:
  multimesh=MultiMesh.new()
  multimesh.transform_format=MultiMesh.TRANSFORM_2D
  multimesh.use_colors=true;multimesh.use_custom_data=true
  multimesh.mesh=QuadMesh.new()
  material=ShaderMaterial.new();material.shader=BEAM_SHADER
 func begin(count:int,clock:float)->void:
  if capacity<count:
   capacity=maxi(4,capacity)
   while capacity<count:capacity*=2
   multimesh.instance_count=capacity;buffer.resize(capacity*16);builds+=1
  used=0;bounds=Rect2();valid_clock=is_finite(clock)
  if valid_clock:material.set_shader_parameter("clock",clock)
 func append_ray(start:Vector2,end:Vector2,state:Vector4,cue:float,link:bool)->void:
  if not valid_clock or not start.is_finite() or not end.is_finite() or not state.is_finite() or not is_finite(cue) or state.x<=0.0:return
  var delta:=end-start;var length:=delta.length()
  var body:=maxf(0.7,state.x)*lerpf(0.65,1.8,clampf(state.y,0,1))
  var pad:=maxf(24.0,body*3.0+10.0)
  if not is_finite(length+pad*2.0):return
  var angle:=delta.angle() if delta.length_squared()>=0.25 else -PI/2
  var c:=cos(angle);var s:=sin(angle);var i:=used*16
  buffer[i]=c;buffer[i+1]=-s;buffer[i+2]=0;buffer[i+3]=start.x
  buffer[i+4]=s;buffer[i+5]=c;buffer[i+6]=0;buffer[i+7]=start.y
  buffer[i+8]=length;buffer[i+9]=cue;buffer[i+10]=angle;buffer[i+11]=1.0 if link else 0.0
  buffer[i+12]=state.x;buffer[i+13]=state.y;buffer[i+14]=state.z;buffer[i+15]=state.w
  var ray_bounds:=Rect2(start,Vector2.ZERO).expand(end).grow(pad*1.42)
  bounds=ray_bounds if used==0 else bounds.merge(ray_bounds)
  used+=1
 func finish()->void:
  multimesh.visible_instance_count=used
  if used==0:return
  multimesh.buffer=buffer;uploads+=1
  RenderingServer.canvas_item_set_custom_rect(get_canvas_item(),true,bounds)
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
 # Read the kernel's ordered beam subset; ordinary flights never enter this renderer.
 # Legacy and old-extension sessions keep the existing full-array fallback.
 if owner.game.native_execution!=null and owner.game.native_execution.kernel.has_method("presentation_beams"):
  shots=owner.game.native_execution.kernel.presentation_beams()
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
   var body=BeamBatch.new() if gpu else Fallback.new();root.add_child(body)
   row={"root":root,"body":body,"shot":shot,"gpu":gpu,"links":[],"evolution_tier":-1};records[serial]=row
  if gpu:
   var tier:int=owner.weapon_evolution_tier(shot)
   if int(row.evolution_tier)!=tier:
    row.evolution_tier=tier
    row.body.material.set_shader_parameter("evolution_color",owner.evolution_color(tier))
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
  row.body.begin(1+links.size(),owner.fx_time)
  row.body.append_ray(start,end,state,cue,false);publications+=1
  for target in links:row.body.append_ray(end,owner.entity_render_position(target)+offset,Vector4(1,0,0,-1),-1,true)
  row.body.finish()
  row.links=links
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
   links+=row.links.size()
 return {"beams":records.size(),"links":links,"live_quad_builds":builds,"publications":publications}
