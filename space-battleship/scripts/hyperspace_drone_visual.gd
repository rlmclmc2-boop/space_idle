extends Node3D
## Read-only visual source: shares the fleet's world and viewport; no combat objects.
const FAMILIES={"laser":"pulse","missile":"missile","cannon":"rail","longLaser":"beam"}
const TOON=preload("res://addons/flexible_toon_shader/flexible_toon.gdshader")
const OFFSETS=[Vector2(-130,-28),Vector2(130,-60),Vector2(-130,-116),Vector2(130,-148),Vector2(0,-224)]
var signature=""
var nodes: Array[Node3D]=[]
var rebuilds=0
func sync(bag: Dictionary) -> bool:
 var sources: Array=[]
 for id in bag.get("equipped",[]):
  var drone: Dictionary=bag.get("drones",{}).get(id,{})
  if FAMILIES.has(drone.get("weapon")):sources.append([str(id),str(drone.weapon)])
  if sources.size()==5:break
 var next=JSON.stringify(sources)
 if next==signature:return false
 for node in nodes:node.free()
 nodes.clear();signature=next;rebuilds+=1
 for source in sources:
  var node=(load("res://assets/hyperspace/models/"+FAMILIES[source[1]]+".glb") as PackedScene).instantiate() as Node3D
  node.name="HyperspaceDrone"+str(nodes.size());node.visible=false;add_child(node);install_materials(node);nodes.append(node)
 return true
func install_materials(node: Node) -> void:
 if node is MeshInstance3D:
  for i in node.mesh.get_surface_count():
   var source=node.mesh.surface_get_material(i) as StandardMaterial3D
   if source==null:continue
   var mat=ShaderMaterial.new();mat.shader=TOON;mat.set_shader_parameter("albedo",source.albedo_color);mat.set_shader_parameter("clamp_diffuse_to_max",true);mat.set_shader_parameter("toon_steps",3);node.set_surface_override_material(i,mat)
 for child in node.get_children():install_materials(child)
func pose(view) -> void:
 # Fixed staggered escort positions stay inside the existing viewport and above HUD.
 for i in nodes.size():
  var offset: Vector2=OFFSETS[i];var bob=sin(view.orbit_elapsed*TAU/8.0+i)*2.0
  var center: Vector2=view.rendered_position+offset+Vector2(0,bob)
  center.x=clampf(center.x,28,view.size.x-28);center.y=clampf(center.y,32,view.size.y-60)
  nodes[i].global_position=Vector3((center.x-view.size.x*0.5)*view.WORLD_PER_PIXEL,0.5,(center.y-view.size.y*0.5)*view.WORLD_PER_PIXEL)
  nodes[i].scale=Vector3.ONE*16.0*view.WORLD_PER_PIXEL
  nodes[i].visible=true
