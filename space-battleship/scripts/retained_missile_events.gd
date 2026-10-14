extends Node2D
## Only paints real launch/contact events. Retired casings retain their original painter.
const FX=preload("res://dev/toon_ship/missile_vfx.gd")
const SHADER=preload("res://shaders/retained_missile_events.gdshader")
class Batch extends MultiMeshInstance2D:
 var buffer:=PackedFloat32Array()
 var capacity:=0
 var used:=0
 var bounds:=Rect2()
 func _init()->void:
  multimesh=MultiMesh.new();multimesh.transform_format=MultiMesh.TRANSFORM_2D
  multimesh.use_custom_data=true;multimesh.mesh=QuadMesh.new()
  material=ShaderMaterial.new();material.shader=SHADER
 func begin(count:int)->void:
  if capacity<count:
   capacity=maxi(8,capacity)
   while capacity<count:capacity*=2
   multimesh.instance_count=capacity;buffer.resize(capacity*12)
  used=0;bounds=Rect2()
 func append_event(point:Vector2,direction:Vector2,age:float,budget:float,critical:bool,launch:bool)->void:
  var axis:Vector2=FX._axis(direction)
  var i:=used*12
  buffer[i]=axis.x;buffer[i+1]=-axis.y;buffer[i+2]=0;buffer[i+3]=point.x
  buffer[i+4]=axis.y;buffer[i+5]=axis.x;buffer[i+6]=0;buffer[i+7]=point.y
  buffer[i+8]=age;buffer[i+9]=budget;buffer[i+10]=1.0 if critical else 0.0;buffer[i+11]=1.0 if launch else 0.0
  var area:=Rect2(point-Vector2.ONE*36,Vector2.ONE*72)
  bounds=area if used==0 else bounds.merge(area);used+=1
 func finish()->void:
  multimesh.visible_instance_count=used
  if used>0:
   multimesh.buffer=buffer
   RenderingServer.canvas_item_set_custom_rect(get_canvas_item(),true,bounds)
class Casing extends Node2D:
 var point:Vector2
 var direction:Vector2
 var age:float
 var coast:float
 var serial:int
 func _draw()->void:
  if age<coast:FX.flight(self,point,direction,1.0,serial,1.0,true,false)
  else:FX.retire(self,point,direction,age-coast)
var pieces:Array=[]
func piece(index:int,retired:bool):
 if index<pieces.size() and ((pieces[index] is Casing)!=retired):
  pieces[index].hide();pieces[index].queue_free();pieces[index]=null
 if index==pieces.size():pieces.append(null)
 if pieces[index]==null:
  pieces[index]=Casing.new() if retired else Batch.new();add_child(pieces[index]);move_child(pieces[index],index)
 # Deferred deletion leaves hidden children until frame end. Order every live
 # piece, including reused ones, so replacement cannot cross a casing barrier.
 if pieces[index].get_index()!=index:move_child(pieces[index],index)
 pieces[index].show()
 return pieces[index]
func sync(scene,events:Array,clock:float,budget:float)->void:
 var index:=0;var batch:Batch
 for event_index in events.size():
  var event:Dictionary=events[event_index]
  var age:=clock-float(event.born)
  if event.kind=="retired":
   if batch!=null:batch.finish();batch=null
   var node:Casing=piece(index,true);index+=1
   var coast:=float(event.coast_time)
   node.point=scene.battle_point(Vector2(event.position)+Vector2(event.direction)*float(event.speed)*minf(age,coast))
   node.direction=event.direction;node.age=age;node.coast=coast;node.serial=int(event.serial);node.queue_redraw()
  else:
   if batch==null:
    batch=piece(index,false);index+=1
    var count:=1
    while event_index+count<events.size() and events[event_index+count].kind!="retired":count+=1
    batch.begin(count)
   batch.append_event(scene.battle_point(Vector2(event.position)),event.direction,age,budget,bool(event.get("critical",false)),event.kind=="fire")
 if batch!=null:batch.finish()
 for i in range(index,pieces.size()):pieces[i].hide()
