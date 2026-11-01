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
 var single: Dictionary=meta.single_smelting
 for key in single.shifts:
  var shift: Array=single.shifts[key]
  model.get_node(NodePath(key)).position=Vector3(shift[0],-shift[1],0)
 for role in ["core","device"]:
  var marker: Node3D=model.get_node(single[role+"_marker"])
  var q: Array=single.route["core_port" if role=="core" else "device_port"]
  var expected:=Vector3(q[0],-q[1],28)
  var axis: Vector3
  if role=="core":
   var control: Array=single.route.controls[0]
   axis=Vector3(control[0]-q[0],-(control[1]-q[1]),-12).normalized()
  else:
   var raw: Array=single.route.axis_to_device
   axis=Vector3(raw[0],-raw[1],0).normalized();axis.z=.35;axis=axis.normalized()
  var position_error: float=marker.global_position.distance_to(expected)
  var axis_error: float=marker.global_basis.z.normalized().distance_to(axis)
  print("SINGLE_PORT ",role," position_error=",position_error," axis_error=",axis_error)
  assert(position_error<.001 and axis_error<.001)
 model.free()
 print("PORT_CHECK_OK eight explicit GLB markers match shared metadata; geometry-only, not visual acceptance")
 quit()
