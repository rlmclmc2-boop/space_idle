extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var model=load("res://assets/ui/reactor/b01/faceted-reactor.glb").instantiate()
 root.add_child(model)
 var meta: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/reactor/b01/faceted-layout.json"))
 for id in meta.ports:
  var data: Dictionary=meta.ports[id]
  for role in ["device","core"]:
   var marker: Node3D=model.get_node(data[role+"_marker"])
   var position_key: String="interface_center_source3d" if role=="device" else "core_interface_source3d"
   var axis_key: String="axis_to_device_source3d" if role=="device" else "core_axis_out_source3d"
   var raw: Array=data[position_key];var expected:=Vector3(raw[0],raw[1],raw[2])
   raw=data[axis_key];var axis:=Vector3(raw[0],raw[1],raw[2])
   var position_error: float=marker.global_position.distance_to(expected)
   var axis_error: float=marker.global_basis.z.normalized().distance_to(axis)
   print("PORT ",id," ",role," position_error=",position_error," axis_error=",axis_error)
   assert(position_error<0.001 and axis_error<0.001)
 model.free()
 print("PORT_CHECK_OK eight explicit GLB markers match shared metadata; geometry-only, not visual acceptance")
 quit()
