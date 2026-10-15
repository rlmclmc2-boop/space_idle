extends SceneTree

func _initialize()->void:
 print("RENDER_API ",JSON.stringify({
  "method":RenderingServer.get_current_rendering_method(),
  "adapter":RenderingServer.get_video_adapter_name(),
  "set_measure":RenderingServer.has_method("viewport_set_measure_render_time"),
  "cpu":RenderingServer.has_method("viewport_get_measured_render_time_cpu"),
  "gpu":RenderingServer.has_method("viewport_get_measured_render_time_gpu"),
  "setup":RenderingServer.has_method("get_frame_setup_time_cpu"),
  "root_rid_valid":root.get_viewport_rid().is_valid(),
 }))
 quit()
