extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok:failures += 1;printerr(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var renderer = preload("res://scripts/orbital_facilities.gd").new()
 root.add_child(renderer)
 for kind in renderer.KINDS:
  var body: Node3D = renderer.models[kind]
  var moving: Node3D = renderer.parts[kind]
  var meshes := body.find_children("*","MeshInstance3D",true,false)
  check(meshes.size()==2,kind+" keeps two merged meshes")
  var surfaces := 0
  var faces := 0
  var bounds := AABB()
  for item in meshes:
   surfaces += item.mesh.get_surface_count()
   faces += item.mesh.get_faces().size()/3
   var transform: Transform3D = body.global_transform.affine_inverse()*item.global_transform
   bounds = bounds.merge(transform*item.get_aabb())
  check(surfaces<=10,kind+" fits material draw budget")
  check(faces<=25000,kind+" fits triangle budget")
  check(bounds.size.x<8.5 and bounds.size.y<8.5 and bounds.size.z<8.5,kind+" stays inside atlas cell")
  check(moving.name=="Motion" and moving.find_children("*","MeshInstance3D",true,false).size()==1,kind+" preserves animated geometry pivot")
  var texture: Texture2D = preload("res://scripts/planet_art.gd").facility(kind)
  check(texture.resource_path.contains("/models/"),kind+" card matches Blender model")
  check(texture.get_image().has_mipmaps(),kind+" icon has minification mipmaps")
  check(texture.get_image().detect_alpha()!=Image.ALPHA_NONE,kind+" icon has transparent background")
  print("MODEL %s faces=%d surfaces=%d" % [kind,faces,surfaces])
 print("BLENDER ASSETS: %d checks, %d failures" % [checks,failures])
 quit(1 if failures else 0)
