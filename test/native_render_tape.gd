extends RefCounted
# Diagnostic native command tape. Recording/readback/validation never timed.
# Nodes/resources remain in the original tree: no bitmap or alternative renderer.
var scene
var output="res://.runtime/"
var replaying=false
var recording=false
var commands={}
var changed={}
var frames=[]
var nodes=[]
var properties={}
var last_values={}
var materials={}
var last_materials={}
var initialized=false
var failure=""
var reference_images={}
var expected_counts=[]
var current_commands={}
var registered={}

func start_frame(enabled:bool)->void:
 recording=enabled;changed={}

func begin(surface:CanvasItem)->void:
 commands[surface]=[];changed[surface]=true

func command(surface:CanvasItem,method:String,args:Array):
 if not changed.has(surface):begin(surface)
 commands[surface].append([method,args])
 return surface.callv(method,args)

func paint(surface:CanvasItem)->void:
 for item in current_commands.get(surface,[]):surface.callv(item[0],item[1])

func collect(node:Node)->void:
 if node is CanvasItem or node is Node3D or node is SubViewport:
  nodes.append(node)
  var names=[]
  for property in ClassDB.class_get_property_list(node.get_class()):
   var key=str(property.name)
   if int(property.usage)&PROPERTY_USAGE_STORAGE==0:continue
   if key in ["script","owner","name","process_mode","process_priority","process_physics_priority"]:continue
   if key.begins_with("metadata/"):continue
   names.append(key)
  properties[node]=names
 for child in node.get_children():collect(child)

func resources(value)->void:
 if value is Resource:
  if registered.has(value):return
  registered[value]=true
  if value is ShaderMaterial:
   var uniforms=[]
   for uniform in value.shader.get_shader_uniform_list():uniforms.append(str(uniform.name))
   materials[value]=uniforms
  for property in value.get_property_list():
   if int(property.usage)&PROPERTY_USAGE_STORAGE and str(property.name)!="script":
    var next=value.get(property.name)
    if next is Resource:resources(next)
 elif value is Array:
  for entry in value:resources(entry)

func capture(index:int,counts:Dictionary)->void:
 if not recording:return
 if not initialized:
  collect(scene);initialized=true
 var full={};var delta=[]
 for node in nodes:
  if not is_instance_valid(node):failure="Native visual node retired during recording";return
  var values=[]
  for key in properties[node]:
   var value=node.get(key);values.append(value);resources(value)
  full[node]=values
  var previous=last_values.get(node,[])
  for i in values.size():
   if previous.is_empty() or values[i]!=previous[i]:delta.append([node,properties[node][i],values[i]])
 var shader_full={};var shader_delta=[]
 for material in materials:
  var values=[]
  for key in materials[material]:values.append(material.get_shader_parameter(key))
  shader_full[material]=values
  var previous=last_materials.get(material,[])
  for i in values.size():
   if previous.is_empty() or values[i]!=previous[i]:shader_delta.append([material,materials[material][i],values[i]])
 var canvas={}
 for surface in commands:
  if frames.is_empty() or changed.has(surface):canvas[surface]=commands[surface]
 var item={"index":index,"nodes":delta,"shaders":shader_delta,"canvas":canvas,"counts":counts.duplicate(true),"full":full,"shader_full":shader_full}
 frames.append(item);last_values=full;last_materials=shader_full
 expected_counts.append(counts.duplicate(true))
 if frames.size() in [1,30,60,120,300,600]:
  var image=scene.get_viewport().get_texture().get_image()
  reference_images[frames.size()-1]=image
  image.save_png(output+"r0-source-%d.png" % (frames.size()-1))

func apply(frame:Dictionary)->void:
 for item in frame.nodes:
  if item[0].get(item[1])!=item[2]:item[0].set(item[1],item[2])
 for item in frame.shaders:item[0].set_shader_parameter(item[1],item[2])
 for surface in frame.canvas:
  current_commands[surface]=frame.canvas[surface]
  surface.queue_redraw()

func mismatch(frame:Dictionary)->Dictionary:
 var bad=[]
 for node in frame.full:
  var values=frame.full[node]
  for i in values.size():
   if node.get(properties[node][i])!=values[i] and bad.size()<12:bad.append([str(node.get_path()),properties[node][i]])
 for material in frame.shader_full:
  var values=frame.shader_full[material]
  for i in values.size():
   if material.get_shader_parameter(materials[material][i])!=values[i] and bad.size()<12:bad.append(["shader",materials[material][i]])
 return {"native_property_mismatches":bad,"commands":current_commands.size()}

func image_difference(a:Image,b:Image)->Dictionary:
 if a.get_size()!=b.get_size():return {"size_mismatch":true}
 a.convert(Image.FORMAT_RGBA8);b.convert(Image.FORMAT_RGBA8)
 var aa=a.get_data();var bb=b.get_data();var changed_pixels=0;var max_channel=0;var sum=0
 for i in range(0,aa.size(),4):
  var different=false
  for j in 4:
   var error=absi(int(aa[i+j])-int(bb[i+j]));max_channel=maxi(max_channel,error);sum+=error
   if error>0:different=true
  if different:changed_pixels+=1
 return {"changed_pixels":changed_pixels,"total_pixels":aa.size()/4,"max_channel_error":max_channel,"mean_channel_error":float(sum)/aa.size()}

func run_replay(tree:SceneTree)->void:
 if not failure.is_empty() or frames.is_empty():
  print("R0_FAILURE ",failure);return
 # Pause all scripts; native drawing and the original live 3D viewport remain.
 for node in scene.find_children("*","Node",true,false):
  node.set_process(false);node.set_physics_process(false)
  if node is Timer:node.stop()
  if node is AnimationPlayer:node.stop()
 for tween in tree.get_processed_tweens():tween.kill()
 scene.set_process(false);replaying=true
 # Prewarm exactly the loaded tape once, excluding replay setup/shader compilation.
 for frame in frames:
  apply(frame);await tree.process_frame;await RenderingServer.frame_post_draw
 var wall=[];var submit=[];var audit=[];var images={};var counts=[]
 for i in frames.size():
  var started=Time.get_ticks_usec();apply(frames[i]);submit.append(Time.get_ticks_usec()-started)
  await tree.process_frame;await RenderingServer.frame_post_draw
  wall.append(Time.get_ticks_usec()-started)
  # Validation occurs after the timed end; no giant state copy in apply().
  audit.append(mismatch(frames[i]));counts.append(frames[i].counts)
  if reference_images.has(i):
   var image=tree.root.get_texture().get_image();image.save_png(output+"r0-replay-%d.png" % i)
   images[str(i)]=image_difference(reference_images[i],image)
 var bad=0
 for row in audit:
  if not row.native_property_mismatches.is_empty():bad+=1
 var report={"mode":"R0 native dynamic replay","frames":frames.size(),"wall_us":tree.stats(wall),"apply_us":tree.stats(submit),"property_mismatch_frames":bad,"audit":audit,"images":images,"visible_counts":counts,"nodes":nodes.size(),"materials":materials.size(),"original_organization_remaining":["same CanvasItem tree and draw order","same native draw calls through callv","same native Controls/layout","same 3D meshes/materials/camera/lights/shadows","same subviewport and MSAA"],"exclusions":["gameplay and presentation queries","recording/decoding","validation/readback"],"clock":"fixed source-frame tape, not natural 1x FPS","equivalence_accepted":false}
 FileAccess.open(output+"r0-replay.json",FileAccess.WRITE).store_string(JSON.stringify(report," "))
 print("R0_ROW ",JSON.stringify(report))
