extends SceneTree
var rows:Array=[]
func bounds(node:Node,transform:Transform3D,out:Array)->void:
 var next=transform*node.transform if node is Node3D else transform
 if node is MeshInstance3D and node.mesh!=null:out.append(next*node.get_aabb())
 for child in node.get_children():bounds(child,next,out)
func _initialize()->void:
 var visuals:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/ship_weapon_visuals.json"))
 for key in visuals.ships:
  if not str(key).begins_with("enemy_"):continue
  var path:String=visuals.ships[key].texture
  var image=Image.load_from_file(path);var used=image.get_used_rect();var size=Vector2(image.get_size())
  rows.append({"kind":"enemy_sprite","key":key,"path":path,"size":str(size),"alpha_bounds":str(used),"center_minus_canvas":str(Vector2(used.position)+Vector2(used.size)*0.5-size*0.5),"normalized_center_offset":str((Vector2(used.position)+Vector2(used.size)*0.5-size*0.5)/size)})
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://dev/toon_ship/hybrid_manifest.json"))
 var models:Dictionary=manifest.hulls.duplicate(true);models["WeaponDrone_carrier"]=manifest.drone
 for key in models:
  var row:Dictionary=models[key];var node=load(row.path).instantiate();var boxes:Array=[]
  bounds(node,Transform3D.IDENTITY,boxes)
  var box:AABB=boxes[0]
  for item in boxes.slice(1):box=box.merge(item)
  rows.append({"kind":"player_glb","key":key,"path":row.path,"bounds":str(box),"center_minus_origin":str(box.get_center()),"center_z_per_height":box.get_center().z/box.size.z,"authored_span":row.model_span})
  node.free()
 for weapon in ["laser","longLaser","missile","cannon"]:
  var node=preload("res://scripts/hyperspace_appearance.gd").scene(weapon).instantiate();var boxes:Array=[]
  bounds(node,Transform3D.IDENTITY,boxes);var box:AABB=boxes[0]
  for item in boxes.slice(1):box=box.merge(item)
  rows.append({"kind":"equipped_drone","key":weapon,"bounds":str(box),"center_minus_origin":str(box.get_center()),"targetable":false,"contract":"full root transform and socket chain shared by numeric and visible owners"});node.free()
 DirAccess.make_dir_recursive_absolute("res://.runtime")
 var file=FileAccess.open("res://.runtime/ship-center-audit.json",FileAccess.WRITE);file.store_string(JSON.stringify(rows,"\t"));file.close()
 print(JSON.stringify(rows));quit()
