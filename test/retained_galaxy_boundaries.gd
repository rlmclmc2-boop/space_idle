extends "res://retained_galaxy_probe.gd"
# Diagnostic only. Camera/building fallback plus transport dock edge comparisons.
# Known dock-edge differences block production acceptance. Animated construction stays live.
class RetainedContext extends RefCounted:
 var map;var depth;var view;var plane;var depth_camera;var dynamic_camera
 var active=false;var saved_signature=[]
 func signature():return [map.camera.global_transform,map.camera.size,map.view.size,map.region.building_revision]
 func live():
  active=false;plane.visible=false;view.render_target_update_mode=SubViewport.UPDATE_DISABLED
  map.camera.cull_mask=3;map.view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;map.container.texture=map.view.get_texture()
 func before_frame():
  if active and saved_signature!=signature():live()
 func enter():
  for cam in [depth_camera,dynamic_camera]:
   cam.global_transform=map.camera.global_transform;cam.size=map.camera.size;cam.near=map.camera.near;cam.far=map.camera.far
  depth.size=map.view.size;view.size=map.view.size
  depth.mesh_lod_threshold=map.view.mesh_lod_threshold;view.mesh_lod_threshold=map.view.mesh_lod_threshold
  map.camera.cull_mask=1;map.view.render_target_update_mode=SubViewport.UPDATE_ONCE;depth.render_target_update_mode=SubViewport.UPDATE_ONCE
  plane.visible=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;map.container.texture=view.get_texture()
  saved_signature=signature();active=true
func check_retained(_scene,map,g,original_profile,depth,dynamic_view,plane,depth_camera,dynamic_camera,depth_mat,cache_mat,quad):
 var warm=SubViewport.new();warm.size=Vector2i(2,2);warm.own_world_3d=true;warm.msaa_3d=Viewport.MSAA_4X;map.add_child(warm)
 var warm_world=Node3D.new();warm.add_child(warm_world)
 var warm_camera=Camera3D.new();warm_world.add_child(warm_camera);warm_camera.projection=Camera3D.PROJECTION_ORTHOGONAL;warm_camera.size=2;warm_camera.position=Vector3(0,0,4);warm_camera.current=true
 for mat in [depth_mat,cache_mat]:
  var node=MeshInstance3D.new();node.mesh=quad;node.material_override=mat;node.extra_cull_margin=10000;warm_world.add_child(node)
 var warm_start=Time.get_ticks_usec();warm.render_target_update_mode=SubViewport.UPDATE_ONCE
 await process_frame;await RenderingServer.frame_post_draw
 print("BOUNDARY_SHADER_WARM ",JSON.stringify({"frame_us":Time.get_ticks_usec()-warm_start,"tiny_calls":warm.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)}))
 warm.render_target_update_mode=SubViewport.UPDATE_DISABLED;warm.queue_free()
 # Child sources render before their dynamic parent: transition directly without a missing-actor frame.
 var old_world=map.view.find_world_3d().get_instance_id()
 map.view.reparent(dynamic_view);depth.reparent(dynamic_view);dynamic_view.world_3d=map.view.find_world_3d()
 print("BOUNDARY_WORLD ",JSON.stringify({"before":old_world,"after":map.view.find_world_3d().get_instance_id(),"dynamic":dynamic_view.find_world_3d().get_instance_id()}))
 var context=RetainedContext.new();context.map=map;context.depth=depth;context.view=dynamic_view;context.plane=plane;context.depth_camera=depth_camera;context.dynamic_camera=dynamic_camera
 context.live()
 # One before/after entry image, then actual transport progression, wheel zoom and pan.
 for i in map.transports.size():map.transports[i].phase=0.45+float(i)*0.005
 map._process(0.0)
 await process_frame;await RenderingServer.frame_post_draw
 map.view.get_texture().get_image().save_png("res://.runtime/boundary-entry-live.png")
 var entry_start=Time.get_ticks_usec();context.enter()
 await process_frame;await RenderingServer.frame_post_draw
 var entry_first_us=Time.get_ticks_usec()-entry_start
 map.view.render_target_update_mode=SubViewport.UPDATE_DISABLED;depth.render_target_update_mode=SubViewport.UPDATE_DISABLED
 dynamic_view.get_texture().get_image().save_png("res://.runtime/boundary-entry-cache.png")
 print("BOUNDARY_ENTRY ",JSON.stringify({"first_frame_us":entry_first_us,"profile_equal":original_profile==JSON.stringify(g.profile,"",true,true),"dynamic_calls":dynamic_view.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)}))
 var first_position=map.transports[0].node.position;var moving_times=[]
 for i in 15:
  var frame_start=Time.get_ticks_usec();map._process(1.0/60.0);context.before_frame();await process_frame;await RenderingServer.frame_post_draw
  moving_times.append(Time.get_ticks_usec()-frame_start)
 print("BOUNDARY_MOVING ",JSON.stringify({"frames_us":stats(moving_times),"transport_moved":first_position!=map.transports[0].node.position,"active":context.active,"profile_equal":original_profile==JSON.stringify(g.profile,"",true,true)}))
 var wheel=InputEventMouseButton.new();wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN;wheel.pressed=true;wheel.position=map.size*0.5
 map._gui_input(wheel);context.before_frame()
 await process_frame;await RenderingServer.frame_post_draw
 map.view.get_texture().get_image().save_png("res://.runtime/boundary-wheel-live.png")
 print("BOUNDARY_WHEEL ",JSON.stringify({"active":context.active,"zoom":map.zoom,"camera_size":map.camera.size,"live_calls":map.view.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)}))
 var rebuild_start=Time.get_ticks_usec();context.enter();await process_frame;await RenderingServer.frame_post_draw
 map.view.render_target_update_mode=SubViewport.UPDATE_DISABLED;depth.render_target_update_mode=SubViewport.UPDATE_DISABLED
 dynamic_view.get_texture().get_image().save_png("res://.runtime/boundary-wheel-cache.png")
 print("BOUNDARY_WHEEL_REBUILD ",Time.get_ticks_usec()-rebuild_start)
 var pan_start=map.pan
 var press=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;press.position=map.size*0.5;map._gui_input(press)
 var motion=InputEventMouseMotion.new();motion.position=map.size*0.5+Vector2(40,20);motion.relative=Vector2(40,20);map._gui_input(motion)
 context.before_frame();await process_frame;await RenderingServer.frame_post_draw
 print("BOUNDARY_PAN ",JSON.stringify({"active":context.active,"pan_changed":map.pan!=pan_start,"live_calls":map.view.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),"profile_equal":original_profile==JSON.stringify(g.profile,"",true,true)}))
 # Boundary-only pair at two route ends, not a broad frame benchmark.
 context.live()
 map.pan=Vector2.ZERO;map.layout()
 for phase in [0.03,0.97]:
  for item in map.transports:item.phase=phase
  map._process(0.0)
  var positions=[]
  for item in map.transports:positions.append(str(item.node.position))
  context.live();await process_frame;await RenderingServer.frame_post_draw
  map.view.get_texture().get_image().save_png("res://.runtime/boundary-dock-"+str(phase)+"-live.png")
  context.enter();await process_frame;await RenderingServer.frame_post_draw
  map.view.render_target_update_mode=SubViewport.UPDATE_DISABLED;depth.render_target_update_mode=SubViewport.UPDATE_DISABLED
  dynamic_view.get_texture().get_image().save_png("res://.runtime/boundary-dock-"+str(phase)+"-cache.png")
  # Removing actors in the retained viewport exposes their actually visible pixels.
  for item in map.transports:item.node.visible=false
  await process_frame;await RenderingServer.frame_post_draw
  dynamic_view.get_texture().get_image().save_png("res://.runtime/boundary-dock-"+str(phase)+"-no-boats.png")
  for item in map.transports:item.node.visible=true
  print("BOUNDARY_DOCK ",JSON.stringify({"phase":phase,"positions":positions,"profile_equal":original_profile==JSON.stringify(g.profile,"",true,true)}))
 # Initial level/state adjustment is a declared fixture. Upgrade selection and completion use authority methods.
 var slot=map.region.slots[0];slot.level=4;slot.status="active";slot.upgrade_progress=0.0
 map.region.state.status="developing";map.region.building_revision+=1;map.region.refresh_counts();map.refresh()
 context.before_frame();await process_frame;await RenderingServer.frame_post_draw
 print("BOUNDARY_BUILDING_FIXTURE ",JSON.stringify({"active":context.active,"level":slot.level,"status":slot.status}))
 var selected=map.region.select_upgrades();map.refresh();context.before_frame()
 await process_frame;await RenderingServer.frame_post_draw
 print("BOUNDARY_UPGRADE_START ",JSON.stringify({"selected":selected.size(),"active":context.active,"level":slot.level,"status":slot.status,"live_calls":map.view.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)}))
 map.region.advance(1000000.0,20);map.refresh();context.before_frame()
 await process_frame;await RenderingServer.frame_post_draw
 print("BOUNDARY_UPGRADE_FINISH ",JSON.stringify({"active":context.active,"level":slot.level,"status":slot.status,"live_calls":map.view.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)}))
 # No demolition gameplay API: remove only a rendered fixture slot, then authority build_attempt restores it.
 slot.status="empty";slot.level=0;slot.work=0.0;slot.construction=0.0
 map.region.state.status="exploring";map.region.building_revision+=1;map.region.refresh_counts();map.refresh();context.before_frame()
 await process_frame;await RenderingServer.frame_post_draw
 print("BOUNDARY_REMOVE_FIXTURE ",JSON.stringify({"active":context.active,"status":slot.status,"building_present":map.slot_nodes[int(slot.id)].get_node_or_null("Building")!=null}))
 var built=map.region.build_attempt();map.refresh();context.before_frame()
 await process_frame;await RenderingServer.frame_post_draw
 print("BOUNDARY_BUILD_START ",JSON.stringify({"built":built,"active":context.active,"status":slot.status,"building_present":map.slot_nodes[int(slot.id)].get_node_or_null("Building")!=null,"explorers":map.explorers.size()}))
 context.live();map.view.reparent(map);depth.reparent(map);dynamic_view.world_3d=map.view.find_world_3d()
