extends SceneTree
func _initialize()->void:
 for name in ClassDB.class_get_enum_list("RenderingServer"):
  if "ViewportRender" in name:
   var values:Dictionary={}
   for key in ClassDB.class_get_enum_constants("RenderingServer",name):values[key]=ClassDB.class_get_integer_constant("RenderingServer",key)
   print(name," ",values)
 for method in ClassDB.class_get_method_list("RenderingServer"):
  if method.name=="viewport_get_render_info":print(method)
 quit()
