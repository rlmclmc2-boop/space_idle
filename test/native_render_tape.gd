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
var settled_node_ids=[]
var script_drawers={}
var recorded_commands=[]
var excluded_pages=[]

func start_frame(enabled:bool)->void:
 recording=enabled;changed={}

func begin(surface:CanvasItem,script_draw:bool=false)->void:
 if script_draw:script_drawers[surface]=true
 commands[surface]=[];changed[surface]=true

func command(surface:CanvasItem,method:String,args:Array):
 if not changed.has(surface):begin(surface)
 commands[surface].append([method,args])
 return surface.callv(method,args)

func paint(surface:CanvasItem)->void:
 for item in current_commands.get(surface,[]):surface.callv(item[0],item[1])

func collect(node:Node)->void:
 if node in excluded_pages:return
 var relevant=(node is CanvasItem) or (node is Node3D and (node==scene.ship_view.world or scene.ship_view.world.is_ancestor_of(node))) or node==scene.ship_view.viewport
 if relevant:
  nodes.append(node)
  var names=[]
  for property in ClassDB.class_get_property_list(node.get_class()):
   var key=str(property.name)
   if int(property.usage)&PROPERTY_USAGE_STORAGE==0:continue
   if key in ["script","owner","name","process_mode","process_priority","process_physics_priority"]:continue
   if key.begins_with("metadata/"):continue
   names.append(key)
  properties[node]=names
 for child in node.get_children(true):collect(child)

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
 # Initialization can rebuild UI. Those old command owners are outside the
 # settled sample and must never enter its tape. During-sample retirement fails.
 for surface in commands.keys():
  if not is_instance_valid(surface):
   if not frames.is_empty():failure="Canvas owner retired during sampled recording";return
   commands.erase(surface);changed.erase(surface);script_drawers.erase(surface)
  elif not surface.is_visible_in_tree():
   commands.erase(surface);changed.erase(surface)
 if not initialized:
  for page in scene.equipment_tabs.get_children():
   if page is Control and not page.is_visible_in_tree():excluded_pages.append(page)
  if is_instance_valid(scene.beginner_guide) and not scene.beginner_guide.is_visible_in_tree():excluded_pages.append(scene.beginner_guide)
  collect(scene);initialized=true
  for node in scene.find_children("*","Node",true,false):settled_node_ids.append(node.get_instance_id())
 else:
  var ids=[]
  for node in scene.find_children("*","Node",true,false):ids.append(node.get_instance_id())
  if ids!=settled_node_ids:failure="Sampled native hierarchy changed; replay lifecycle not equivalent";return
  for node in scene.find_children("*","CanvasItem",true,false):
   if node.is_visible_in_tree() and not properties.has(node):failure="Unrecorded Canvas owner became visible at %d: %s" % [index,node.get_path()];return
 var full={};var delta=[]
 counts.native_draw_calls=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
 counts.native_primitives=Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
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
  resources(commands[surface])
  if frames.is_empty() or changed.has(surface):canvas[surface]=commands[surface]
 var command_total=0
 for surface in commands:command_total+=commands[surface].size()
 counts.native_commands=command_total
 var full_commands=commands.duplicate()
 var item={"index":index,"nodes":delta,"shaders":shader_delta,"canvas":canvas,"counts":counts.duplicate(true),"full":full,"shader_full":shader_full,"full_commands":full_commands}
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
 var command_bad=0;var command_total=0
 for surface in frame.full_commands:
  if current_commands.get(surface,[])!=frame.full_commands[surface]:command_bad+=1
 for surface in current_commands:command_total+=current_commands[surface].size()
 return {"native_property_mismatches":bad,"command_owner_mismatches":command_bad,"native_commands":command_total,"commands":current_commands.size(),"native_draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"native_primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}

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
 # Original draw-signal callbacks can query gameplay. Keep script _draw guards
 # and replace signal painters by the final recorded native command stream.
 for surface in commands:
  for connection in surface.get_signal_connection_list("draw"):surface.disconnect("draw",connection.callable)
  if not script_drawers.has(surface):surface.draw.connect(paint.bind(surface))
 scene.set_process(false);replaying=true
 var cost_views=[];var cost_trace=[]
 if OS.get_environment("PERF_RENDER_COST")=="1":tree.measured_views(tree.root,cost_views)
 # Frame zero initially contains a full snapshot. Reduce its cyclic restart
 # to last->first deltas outside timing; restoring the tape is not gameplay.
 var restart=[]
 for node in frames[0].full:
  var first=frames[0].full[node];var last=frames[-1].full[node]
  for i in first.size():
   if first[i]!=last[i]:restart.append([node,properties[node][i],first[i]])
 var restore_full=frames[0].nodes;frames[0].nodes=restart
 for item in restore_full:
  if item[0].get(item[1])!=item[2]:item[0].set(item[1],item[2])
 # Prewarm exactly the loaded tape once, excluding replay setup/shader compilation.
 for frame in frames:
  apply(frame);await tree.process_frame;await RenderingServer.frame_post_draw
 var wall=[];var submit=[];var audit=[];var images={};var counts=[]
 for i in frames.size():
  apply(frames[i])
  await tree.process_frame;await RenderingServer.frame_post_draw
  # Entire validation pass is separate: its readback/audit must not leave
  # interframe idle gaps inside a supposedly clean contiguous throughput run.
  audit.append(mismatch(frames[i]));counts.append(frames[i].counts)
  if reference_images.has(i):
   var image=tree.root.get_texture().get_image();image.save_png(output+"r0-replay-%d.png" % i)
   images[str(i)]=image_difference(reference_images[i],image)
 var bad=0
 for row in audit:
  if not row.native_property_mismatches.is_empty() or row.command_owner_mismatches>0:bad+=1
 var equivalent=bad==0
 var count_mismatches=0
 for i in audit.size():
  if audit[i].native_commands!=frames[i].counts.native_commands or audit[i].native_draw_calls!=frames[i].counts.native_draw_calls or audit[i].native_primitives!=frames[i].counts.native_primitives:count_mismatches+=1
 if count_mismatches>0:equivalent=false
 var exact=true
 for check in images.values():
  if int(check.get("changed_pixels",-1))!=0:exact=false
  if int(check.get("max_channel_error",999))>1 or int(check.get("changed_pixels",999))>8:equivalent=false
 if equivalent:
  for frame in frames:
   var started=Time.get_ticks_usec();apply(frame);submit.append(Time.get_ticks_usec()-started)
   await tree.process_frame;await RenderingServer.frame_post_draw
   wall.append(Time.get_ticks_usec()-started)
   if not cost_views.is_empty():
    var values=[]
    for view in cost_views:
     var rid=view.get_viewport_rid()
     values.append([str(view.get_path()),RenderingServer.viewport_get_measured_render_time_cpu(rid),RenderingServer.viewport_get_measured_render_time_gpu(rid)])
    cost_trace.append([frame.index,RenderingServer.get_frame_setup_time_cpu(),values])
 else:
  wall=[0];submit=[0]
 var report={"mode":"R0 native dynamic replay","frames":frames.size(),"wall_us":tree.stats(wall),"apply_us":tree.stats(submit),"property_mismatch_frames":bad,"audit":audit,"images":images,"visible_counts":counts,"nodes":nodes.size(),"materials":materials.size(),"original_organization_remaining":["same CanvasItem tree and draw order","same native draw calls through callv","same native Controls/layout","same 3D meshes/materials/camera/lights/shadows","same subviewport and MSAA"],"exclusions":["gameplay and presentation queries","recording/decoding","validation/readback"],"clock":"fixed source-frame tape, not natural 1x FPS","equivalence_accepted":equivalent}
 report.pixel_exact=exact
 report.native_count_mismatch_frames=count_mismatches
 report.pixel_tolerance={"max_channel_error":1,"maximum_nonexact_pixels_per_1211476":8,"reason":"explicit one 8-bit level allowance; no material/geometry/content omission"}
 report.render_cost_trace=cost_trace
 report.render_cost_scope="diagnostic queries only when requested; milliseconds, CPU wall may include stalls, GPU last available query; stages not added and no stage-P95 claim"
 report.clean_timing=cost_views.is_empty()
 FileAccess.open(output+"r0-replay.json",FileAccess.WRITE).store_string(JSON.stringify(report," "))
 print("R0_ROW ",JSON.stringify(report))

func release()->void:
 for surface in commands:
  if is_instance_valid(surface):
   for connection in surface.get_signal_connection_list("draw"):surface.disconnect("draw",connection.callable)
 frames.clear();commands.clear();changed.clear();nodes.clear();properties.clear()
 last_values.clear();materials.clear();last_materials.clear();registered.clear()
 script_drawers.clear();current_commands.clear();reference_images.clear();scene=null
