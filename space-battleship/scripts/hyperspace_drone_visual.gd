extends Node3D
## Read-only visual source: shares the fleet's world and viewport; no combat objects.
const FAMILIES={"laser":"pulse","missile":"missile","cannon":"rail","longLaser":"beam"}
const Appearance=preload("res://scripts/hyperspace_appearance.gd")
var members: Dictionary={}
var style_keys: Dictionary={}
static var base_materials: Dictionary={}
var appearance_generation=-1
var model_creations=0
var style_updates=0
var animated=true
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
 var generation=int(bag.get("generation",-1))
 if next==signature and generation==appearance_generation:return false
 var member_changed=next!=signature
 var keep: Array=[]
 for source in sources:keep.append(str(source[0]))
 for id in members.keys():
  if not id in keep:
   members[id].free();members.erase(id);style_keys.erase(id);muzzles.erase(id)
 nodes.clear();identities.clear()
 for source in sources:
  var id=str(source[0]);var weapon=str(source[1])
  if members.has(id) and members[id].get_meta("weapon")!=weapon:
   members[id].free();members.erase(id);style_keys.erase(id);muzzles.erase(id)
  if not members.has(id):
   var node=Appearance.scene(weapon).instantiate() as Node3D
   node.name="HyperspaceDrone"+id.replace(":","_");node.visible=false;node.set_meta("weapon",weapon);add_child(node);install_materials(node);members[id]=node;model_creations+=1;install_muzzles(node,id,weapon)
  var node: Node3D=members[id]
  var style=Appearance.project(bag.drones[id]);var key=Appearance.fingerprint(style)
  if style_keys.get(id,"")!=key:
   var old=node.get_node_or_null("Appearance")
   if old!=null:old.free()
   install_materials(node,style);Appearance.build_ornaments(node,style);style_keys[id]=key;style_updates+=1
  nodes.append(node);identities.append(id)
 signature=next;appearance_generation=generation
 if member_changed:rebuilds+=1
 return true

func install_materials(node: Node,style: Dictionary={}) -> void:
 if node is MeshInstance3D:
  for i in node.mesh.get_surface_count():
   var source=node.mesh.surface_get_material(i) as StandardMaterial3D
   if source==null:continue
   var color=source.albedo_color
   if not style.is_empty() and style.quality!="white" and source.resource_name in ["PhaseDroneIvory","PhaseDroneMetal"]:
    color=color.lerp(style.color,clampf(float(Appearance.settings().get("body_tint",0.72)),0.0,1.0))
   var key=color.to_html()
   if not base_materials.has(key):
    var mat=ShaderMaterial.new();mat.shader=TOON;mat.set_shader_parameter("albedo",color);mat.set_shader_parameter("clamp_diffuse_to_max",true);mat.set_shader_parameter("cuts",3);base_materials[key]=mat
   node.set_surface_override_material(i,base_materials[key])
 for child in node.get_children():
  if child.name!="Appearance":install_materials(child,style)
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
  var ring=nodes[i].get_node_or_null("Appearance/UltimateOrbit")
  if ring!=null and animated and bool(Appearance.settings().get("animate",true)):ring.rotation.y=view.orbit_elapsed*0.45
