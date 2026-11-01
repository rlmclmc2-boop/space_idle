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
 # The two-device assembly consumes the same markers after declared shifts.
 for key in meta.double_left.shifts:
  var raw_shift: Array=meta.double_left.shifts[key]
  model.get_node(NodePath(key)).position=Vector3(raw_shift[0],-raw_shift[1],0)
 for id in meta.double_left.ids:
  var route: Dictionary=meta.double_left.routes[id].route
  for role in ["core","device"]:
   var marker: Node3D=model.get_node(meta.ports[id][role+"_marker"])
   var raw: Array=route["core_port" if role=="core" else "device_port"]
   var expected:=Vector3(raw[0],-raw[1],28)
   var error: float=marker.global_position.distance_to(expected)
   print("DOUBLE_PORT ",id," ",role," position_error=",error)
   assert(error<.001)
 # Restore the single-device positions for the authored-frame samples below.
 model.get_node("weapons").position=Vector3.ZERO
 for key in meta.single_smelting.shifts:
  var shift: Array=meta.single_smelting.shifts[key]
  model.get_node(NodePath(key)).position=Vector3(shift[0],-shift[1],0)
 for item in [["weapons","weapon_charge_segment_0",Vector3(181,-153,68)],["smelting","furnace_feed_0",Vector3(160,-442,67)],["condensation","crystal_body_2",Vector3(1024,-478,81)]]:
  var id: String=item[0]
  var frame: Dictionary=meta.work_frames[id]
  var cols: Array=frame.basis_columns
  var vectors: Array[Vector3]=[]
  for col in cols:vectors.append(Vector3(col[0],col[1],col[2]))
  var o: Array=frame.origin
  var inverse:=Transform3D(Basis(vectors[0],vectors[1],vectors[2]),Vector3(o[0],o[1],o[2])).affine_inverse()
  var part: Node3D
  for candidate in model.get_node(NodePath(id)).get_children():
   if String(candidate.name).replace("_"," ")==String(item[1]).replace("_"," "):part=candidate;break
  assert(part!=null)
  var shift:=Vector3(200,50,0) if id=="smelting" else Vector3.ZERO
  var error: float=INF
  if id=="condensation":
   var mesh_part: MeshInstance3D=part
   for surface in mesh_part.mesh.get_surface_count():
    var vertices: PackedVector3Array=mesh_part.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
    for vertex in vertices:error=minf(error,(inverse*(mesh_part.global_transform*vertex-shift)).distance_to(item[2]))
  else:error=(inverse*(part.global_position-shift)).distance_to(item[2])
  print("WORK_FRAME ",id," author_sample_error=",error)
  assert(error<.01)
 var colored: int=0
 for group in model.get_children():
  for part in group.get_children():
   if not part is MeshInstance3D or not String(part.name).ends_with("structure"):continue
   for surface in part.mesh.get_surface_count():
    var values: PackedColorArray=part.mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]
    assert(not values.is_empty())
    var minimum: float=1.0
    for color in values:minimum=minf(minimum,color.r)
    print("LOCAL_CAVITY ",group.name," surface=",surface," colors=",values.size()," min=",minimum)
    if minimum<.99:colored+=1
 assert(colored>0)
 print("LOCAL_CAVITY_IMPORT_OK surfaces_with_nonwhite=",colored)
 model.free()
 print("PORT_CHECK_OK eight explicit GLB markers match shared metadata; geometry-only, not visual acceptance")
 quit()
