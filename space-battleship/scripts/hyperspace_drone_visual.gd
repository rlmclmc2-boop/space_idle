extends Node3D
## Read-only visual source: shares the fleet's world and viewport; no combat objects.
const FAMILIES={"laser":"pulse","missile":"missile","cannon":"rail","longLaser":"beam"}
const TOON=preload("res://addons/flexible_toon_shader/flexible_toon.gdshader")
const OFFSETS=[Vector2(-130,-28),Vector2(130,-60),Vector2(-130,-116),Vector2(130,-148),Vector2(0,-224)]
var signature=""
var nodes: Array[Node3D]=[]
var rebuilds=0
var identities: Array[String]=[]
var muzzles: Dictionary={}
const MUZZLE_MESHES={"laser":["PulseLens"],"missile":["LaunchBay"] ,"cannon":["RailMuzzleCap"] ,"longLaser":["AxialFocusingLens"]}
func sync(bag: Dictionary) -> bool:
 var sources: Array=[]
 for id in bag.get("equipped",[]):
  var drone: Dictionary=bag.get("drones",{}).get(id,{})
  if FAMILIES.has(drone.get("weapon")):sources.append([str(id),str(drone.weapon)])
  if sources.size()==5:break
 var next=JSON.stringify(sources)
 if next==signature:return false
 for node in nodes:node.free()
 nodes.clear();identities.clear();muzzles.clear();signature=next;rebuilds+=1
 for source in sources:
  var node=(load("res://assets/hyperspace/models/"+FAMILIES[source[1]]+".glb") as PackedScene).instantiate() as Node3D
  node.name="HyperspaceDrone"+str(nodes.size());node.visible=false;add_child(node);install_materials(node);nodes.append(node);identities.append(str(source[0]));install_muzzles(node,str(source[0]),str(source[1]))
 return true
func install_materials(node: Node) -> void:
 if node is MeshInstance3D:
  for i in node.mesh.get_surface_count():
   var source=node.mesh.surface_get_material(i) as StandardMaterial3D
   if source==null:continue
   var mat=ShaderMaterial.new();mat.shader=TOON;mat.set_shader_parameter("albedo",source.albedo_color);mat.set_shader_parameter("clamp_diffuse_to_max",true);mat.set_shader_parameter("toon_steps",3);node.set_surface_override_material(i,mat)
 for child in node.get_children():install_materials(child)
func install_muzzles(node: Node3D,id: String,weapon: String) -> void:
 var sockets: Array[Node3D]=[]
 for mesh_name in MUZZLE_MESHES[weapon]:
  var found=node.find_children(mesh_name+"*","MeshInstance3D",true,false)
  for mesh in found:
   var bounds=mesh.get_aabb()
   # The authored front face owns this socket; mount indices and guessed offsets do not.
   var front=mesh.to_global(Vector3(bounds.position.x+bounds.size.x/2.0,bounds.position.y+bounds.size.y/2.0,bounds.position.z))
   var socket=Node3D.new();socket.name="HyperspaceMuzzle"+str(sockets.size());node.add_child(socket);socket.global_position=front;sockets.append(socket)
 muzzles[id]=sockets
func screen_muzzle_for_drone(id: String,ordinal: int,view) -> Vector2:
 var sockets: Array=muzzles.get(id,[])
 if sockets.is_empty():return view.rendered_position
 return view.camera.unproject_position(sockets[posmod(ordinal,sockets.size())].global_position)
func pose(view,disabled: Array=[],zoom: float=1.0) -> void:
 for i in nodes.size():
  var offset: Vector2=OFFSETS[i];var bob=sin(view.orbit_elapsed*TAU/8.0+i)*2.0
  var center: Vector2=view.rendered_position+(offset+Vector2(0,bob))*zoom
  if zoom==1.0:
   center.x=clampf(center.x,28,view.size.x-28);center.y=clampf(center.y,32,view.size.y-60)
  nodes[i].global_position=Vector3((center.x-view.size.x*0.5)*view.WORLD_PER_PIXEL,0.5,(center.y-view.size.y*0.5)*view.WORLD_PER_PIXEL)
  nodes[i].scale=Vector3.ONE*16.0*view.WORLD_PER_PIXEL*zoom
  nodes[i].visible=not disabled.has(identities[i])
