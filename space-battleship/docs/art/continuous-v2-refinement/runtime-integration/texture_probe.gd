extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 await process_frame
 await RenderingServer.frame_post_draw
 var info=[]
 for method in RenderingServer.get_method_list():
  if "usage" in method.name:print("USAGE_METHOD ",method.name)
 var baseline=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)
 var held=[]
 for stage in range(1,11):
  var texture=load("res://assets/backgrounds/opening/stage_%02d.png"%stage);held.append(texture)
  await process_frame
  await RenderingServer.frame_post_draw
  var now=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)
  info.append({"stage":stage,"size":[texture.get_width(),texture.get_height()],"total_texture_bytes":now,"delta_from_empty_probe":now-baseline,"rid":texture.get_rid().get_id()})
 var before=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)
 for frame in 30:await process_frame
 var after=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)
 var file=FileAccess.open(OS.get_environment("OPENING_REVIEW_DIR")+"/texture-residency.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"renderer":"Godot 4.6.3 GL Compatibility / Mesa llvmpipe","baseline_bytes":baseline,"textures":info,"stable_before":before,"stable_after":after,"driver_physical_vram_claim":false},"\t"))
 print("TEXTURE_PROBE_OK ",before," ",after)
 quit()
