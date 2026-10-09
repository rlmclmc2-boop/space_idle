extends "res://checkpoint_scene_cost.gd"
# Diagnostic fixed-pose proof only. No production cache or acceptance of input/invalidation.
# Original GUI nodes remain in place; only renderer visibility layers change temporarily.
func measure(scene,g,_save_hash):
 # Diagnostic only: retain existing workspace CanvasItems without reparenting GUI controls.
 for _i in 12:scene._process(0.0);await process_frame;await RenderingServer.frame_post_draw
 var content=scene.equipment_tabs
 var changed=[];var ancestors=[]
 for item in content.find_children("*","CanvasItem",true,false):changed.append([item,item.visibility_layer]);item.visibility_layer=2
 changed.append([content,content.visibility_layer]);content.visibility_layer=2
 var parent=content.get_parent()
 while parent is CanvasItem:
  ancestors.append([parent,parent.visibility_layer]);parent.visibility_layer=3;parent=parent.get_parent()
 var pixels=root.get_stretch_transform()*root.canvas_transform
 var bounds=content.get_global_rect();var p0=pixels*bounds.position;var p1=pixels*bounds.end
 var rect=Rect2i(Vector2i(floor(p0.x),floor(p0.y)),Vector2i(ceil(p1.x)-floor(p0.x),ceil(p1.y)-floor(p0.y))).intersection(Rect2i(Vector2i.ZERO,root.size))
 var cache=SubViewport.new();cache.name="WorkspaceDiagnosticCache";cache.size=rect.size;cache.disable_3d=true;cache.transparent_bg=true;cache.world_2d=root.find_world_2d();cache.canvas_cull_mask=2;cache.render_target_update_mode=SubViewport.UPDATE_DISABLED
 scene.add_child(cache);cache.canvas_transform=Transform2D(0,Vector2(-rect.position))*pixels
 var output=TextureRect.new();output.name="WorkspaceDiagnosticOutput";output.mouse_filter=Control.MOUSE_FILTER_IGNORE;output.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;output.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;output.visibility_layer=1
 var ui_pixels=pixels*scene.ui.get_global_transform_with_canvas()
 output.position=ui_pixels.affine_inverse()*Vector2(rect.position);output.size=Vector2(rect.size)/Vector2(ui_pixels.x.length(),ui_pixels.y.length());output.texture=cache.get_texture();output.visible=false
 var mat=ShaderMaterial.new();var shader=Shader.new();shader.code="shader_type canvas_item; render_mode unshaded, blend_premul_alpha;";mat.shader=shader;output.material=mat;scene.ui.add_child(output)
 print("WORKSPACE_SETUP ",JSON.stringify({"rect":str(rect),"content_rect":str(bounds),"pixels":str(pixels),"items":changed.size(),"source_world":root.find_world_2d().get_instance_id(),"cache_world":cache.find_world_2d().get_instance_id(),"current_tab":content.current_tab,"stage":g.stage,"logical_dt":0.0}))
 var profile=JSON.stringify(g.profile,"",true,true)
 for variant in ["live_control","retained_workspace","live_return"]:
  if variant=="retained_workspace":
   cache.render_target_update_mode=SubViewport.UPDATE_ONCE;var began=Time.get_ticks_usec();await process_frame;await RenderingServer.frame_post_draw
   cache.render_target_update_mode=SubViewport.UPDATE_DISABLED;print("WORKSPACE_PREPARE_US ",Time.get_ticks_usec()-began)
   root.canvas_cull_mask=1;output.visible=true
  else:root.canvas_cull_mask=3;output.visible=false
  var frames=[];var host=[];var calls=[]
  for i in 45:
   var began=Time.get_ticks_usec();scene._process(0.0);await process_frame;await RenderingServer.frame_post_draw
   if i>=20:frames.append(Time.get_ticks_usec()-began);host.append(scene.last_process_us);calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
  root.get_texture().get_image().save_png("res://.runtime/workspace-"+variant+".png")
  var v=[];views(root,v)
  print("WORKSPACE_ROW ",JSON.stringify({"variant":variant,"frames_us":stats(frames),"host_us":stats(host),"calls":stats(calls),"views":v,"same_profile":profile==JSON.stringify(g.profile,"",true,true),"source_visible":content.is_visible_in_tree()}))
 root.canvas_cull_mask=1048575
 for item in changed:item[0].visibility_layer=item[1]
 for item in ancestors:item[0].visibility_layer=item[1]
