extends SceneTree
## Compare native active-beam pixels with the original script at fixed inputs.
const Beam=preload("res://dev/toon_ship/continuous_beam_vfx.gd")
class Paint extends Node2D:
 var native:RefCounted
 var values:Array=[]
 func _draw()->void:
  if values.is_empty():return
  if native!=null:native.draw_beam_active(self,values[0],values[1],values[2],values[3],values[4],values[5])
  else:Beam.active(self,values[0],values[1],values[2],values[3],values[4],values[5])
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func run()->void:
 var viewports:Array[SubViewport]=[]
 var painters:Array[Paint]=[]
 for i in 2:
  var viewport=SubViewport.new();viewport.size=Vector2i(256,256)
  viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
  root.add_child(viewport);viewports.append(viewport)
  var painter=Paint.new()
  if i==1:painter.native=ClassDB.instantiate("SpaceCombatPresentation")
  viewport.add_child(painter);painters.append(painter)
 var cases:Array=[]
 for power in [0.0,0.25,0.5,0.999998,1.0]:
  for clock in [0.0,1.234,17.9]:
   cases.append([Vector2(30,220),Vector2(180,35),clock,1.2+power*2.2,power,0.73])
 cases.append([Vector2(80,80),Vector2(80,80),1.0,2.0,1.0,1.0])
 cases.append([Vector2(30,220),Vector2(180,35),1.0,0.0,1.0,1.0])
 var differences:Array=[]
 for values in cases:
  for painter in painters:painter.values=values;painter.queue_redraw()
  await process_frame;await RenderingServer.frame_post_draw
  var expected=viewports[0].get_texture().get_image().get_data()
  var actual=viewports[1].get_texture().get_image().get_data()
  var changed:=0;var maximum:=0
  for index in expected.size():
   var difference=absi(int(expected[index])-int(actual[index]))
   if difference>0:changed+=1;maximum=maxi(maximum,difference)
  checks+=1
  if changed>0:failures+=1;differences.append({"case":checks,"changed_channels":changed,"max_channel_difference":maximum})
 print("NATIVE_BEAM_PIXELS ",JSON.stringify({"checks":checks,"failures":failures,"differences":differences}))
 for viewport in viewports:viewport.queue_free()
 await process_frame
 quit(0 if failures==0 else 1)
