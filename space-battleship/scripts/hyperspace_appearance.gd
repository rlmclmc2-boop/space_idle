extends RefCounted
## Cosmetic data only. No combat/configuration authority or saved state.
const FAMILIES={"laser":"pulse","missile":"missile","cannon":"rail","longLaser":"beam"}
static var config: Dictionary={}
static var scenes: Dictionary={}
static var icons: Dictionary={}
static var materials: Dictionary={}
static var meshes: Dictionary={}
static var rig_meshes: Dictionary={}
static var rig_order: Array=[]
static var thumbnail_cache: Dictionary={}
static var thumbnail_order: Array=[]
static var projections=0
static var resource_creations=0
static func reload_config() -> bool:
 var raw=JSON.parse_string(FileAccess.get_file_as_string("res://data/hyperspace_visuals.json"))
 if not raw is Dictionary or raw.is_empty():return false
 for key in ["emission","ornament_scale","body_tint","tier_glyph_scale","high_tier_max","version"]:
  if raw.has(key) and not (raw[key] is int or raw[key] is float):return false
 if not raw.get("quality") is Dictionary:return false
 for quality in ["white","blue","gold","legendary"]:
  var entry=raw.get("quality",{}).get(quality,{})
  if not entry is Dictionary or not Color.html_is_valid(str(entry.get("color",""))):return false
  if not entry.get("rank") is int and not entry.get("rank") is float:return false
  if float(entry.rank)!=int(entry.rank) or int(entry.rank)<0 or int(entry.rank)>3:return false
 if not Color.html_is_valid(str(raw.get("ultimate_color",""))):return false
 if raw.has("animate") and not raw.animate is bool:return false
 var ranges={"emission":Vector2(0,0.7),"ornament_scale":Vector2(0.5,1.1),"body_tint":Vector2(0,1),"tier_glyph_scale":Vector2(1,3),"high_tier_max":Vector2(1,5)}
 for key in ranges:
  var limits=ranges[key]
  if raw.has(key) and (float(raw[key])<limits.x or float(raw[key])>limits.y):return false
 for key in ["version","high_tier_max"]:
  if raw.has(key) and (float(raw[key])!=int(raw[key]) or int(raw[key])<1):return false
 if raw==config:return false
 config=raw
 materials.clear();rig_meshes.clear();rig_order.clear();thumbnail_cache.clear();thumbnail_order.clear()
 return true
static func settings() -> Dictionary:
 if config.is_empty():
  if not reload_config():config={"version":1}
 return config
static func project(d: Dictionary) -> Dictionary:
 projections+=1
 var c=settings()
 var quality="legendary" if bool(d.get("legendary",false)) else str(d.get("origin_quality","white"))
 if not quality in ["white","blue","gold","legendary"]:quality="white"
 var tier=6
 var category=""
 var candidates: Array=d.get("affixes",[]).duplicate()
 if bool(d.get("ultimate",false)) and not d.get("ultimate_affix",{}).is_empty():candidates.append(d.ultimate_affix)
 for a in candidates:
  var at=int(a.get("tier",6));var key=str(a.get("key",""))
  if at<1 or at>5:continue
  var kind="chain" if "chain" in key else ("shield" if "shield" in key or "armour" in key or "health" in key or "defence" in key else ("attack" if "damage" in key or "crit" in key else "tempo"))
  if at<tier or (at==tier and kind<category):tier=at;category=kind
 if tier>int(c.get("high_tier_max",2)):category=""
 return {"quality":quality,"rank":clampi(int(c.get("quality",{}).get(quality,{}).get("rank",0)),0,3),"color":Color(str(c.get("quality",{}).get(quality,{}).get("color","b8c7d0"))),"ultimate":bool(d.get("ultimate",false)),"tier":tier,"category":category,"weapon":str(d.get("weapon","laser"))}
static func fingerprint(s: Dictionary) -> String:
 return "%s:%s:%s:%s:%s:%s"%[s.weapon,s.quality,s.ultimate,(s.tier if not s.category.is_empty() else 0),s.category,settings().get("version",1)]
static func scene(weapon: String) -> PackedScene:
 if not scenes.has(weapon):scenes[weapon]=load("res://assets/hyperspace/models/"+FAMILIES[weapon]+".glb");resource_creations+=1
 return scenes[weapon]
static func icon(weapon: String) -> Texture2D:
 if not icons.has(weapon):
  var source=load("res://assets/hyperspace/icons/"+FAMILIES[weapon]+".png") as Texture2D
  var cropped=AtlasTexture.new();cropped.atlas=source
  var used=source.get_image().get_used_rect();cropped.region=used.grow(12).intersection(Rect2i(Vector2i.ZERO,source.get_size()))
  icons[weapon]=cropped;resource_creations+=1
 return icons[weapon]
static func material(color: Color,emission: bool=false) -> StandardMaterial3D:
 var key=color.to_html()+str(emission)
 if not materials.has(key):
  var m=StandardMaterial3D.new();m.albedo_color=color;m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
  m.emission_enabled=emission;m.emission=color;m.emission_energy_multiplier=clampf(float(settings().get("emission",0.28)),0,0.7)
  materials[key]=m;resource_creations+=1
 return materials[key]
static func mesh(kind: String,size: Vector3) -> Mesh:
 var key=kind+str(size)
 if not meshes.has(key):
  var m: Mesh
  if kind=="ring":
   var ring=TorusMesh.new();ring.inner_radius=size.x;ring.outer_radius=size.z;ring.rings=12;ring.ring_segments=16;m=ring
  elif kind=="lens":
   var sphere=SphereMesh.new();sphere.radius=size.x/2;sphere.height=size.y;sphere.radial_segments=8;sphere.rings=4;m=sphere
  elif kind=="wing":var prism=PrismMesh.new();prism.size=size;m=prism
  else:var box=BoxMesh.new();box.size=size;m=box
  meshes[key]=m;resource_creations+=1
 return meshes[key]
static func add_part(root: Node3D,kind: String,size: Vector3,position: Vector3,color: Color,angle: float=0) -> MeshInstance3D:
 var part=MeshInstance3D.new();part.mesh=mesh(kind,size);part.material_override=material(color,true);part.position=position;part.rotation.y=angle;part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(part);return part
static func build_ornaments(root: Node3D,s: Dictionary) -> Node3D:
 var rig=Node3D.new();rig.name="Appearance";root.add_child(rig)
 var cache_key=fingerprint(s)
 if rig_meshes.has(cache_key):
  rig_order.erase(cache_key);rig_order.append(cache_key)
  var cached=rig_meshes[cache_key]
  add_combined(rig,cached.hull)
  if cached.orbit!=null:
   var orbit=Node3D.new();orbit.name="UltimateOrbit";orbit.position=Vector3(0,0.55,0);rig.add_child(orbit);add_combined(orbit,cached.orbit)
  rig.scale=Vector3.ONE*clampf(float(settings().get("ornament_scale",1)),0.5,1.1)
  return rig
 var color: Color=s.color;var rank=int(s.rank)
 # The approved hull and muzzle remain untouched; each quality adds real outer structures.
 var kind="box" if s.weapon in ["missile","cannon"] else "wing"
 for side in [-1,1]:
  for n in rank:
   var z=-0.45+float(n)*0.4
   var size=Vector3(0.18,0.13,0.4 if s.weapon in ["cannon","longLaser"] else 0.25)
   add_part(rig,kind,size,Vector3(side*(0.85+rank*0.05),0.1,z),Color("dae3eb"),side*0.35)
   add_part(rig,"box",Vector3(0.045,0.16,size.z*0.78),Vector3(side*(0.94+rank*0.05),0.1,z),color,side*0.35)
 if rank>=2:
  add_part(rig,"box",Vector3(0.72,0.07,0.055),Vector3(0,0.15,0.48),color)
 if rank==3:
  add_part(rig,"ring",Vector3(0.25,0,0.29),Vector3(0,0.5,0),color)
  for side in [-1,1]:add_part(rig,"wing",Vector3(0.17,0.14,0.3),Vector3(side*0.2,0.13,-0.64),color,side*0.45)
 if s.ultimate:
  var ring=Node3D.new();ring.name="UltimateOrbit";ring.position=Vector3(0,0.55,0);rig.add_child(ring)
  add_part(ring,"ring",Vector3(0.4,0,0.45),Vector3.ZERO,Color(str(settings().get("ultimate_color","7ef5e0"))))
  for side in [-1,1]:add_part(ring,"wing",Vector3(0.07,0.06,0.1),Vector3(side*0.46,0,0),Color("f0fffa"))
 if not s.category.is_empty():
  var glyph=Node3D.new();glyph.name="TierGlyph";glyph.position=Vector3(0,0.55,1.05);glyph.scale=Vector3.ONE*clampf(float(settings().get("tier_glyph_scale",2.8)),1.0,3.0);rig.add_child(glyph)
  var ink=Color("e6f4ff")
  if s.category=="shield":add_part(glyph,"ring",Vector3(0.09,0,0.12),Vector3.ZERO,ink)
  elif s.category=="attack":
   for n in 3:add_part(glyph,"wing",Vector3(0.055,0.06,0.15),Vector3((n-1)*0.07,0,0),ink)
  elif s.category=="chain":
   for n in 3:add_part(glyph,"box",Vector3(0.06,0.06,0.06),Vector3((n-1)*0.1,0,abs(n-1)*0.05),ink)
   add_part(glyph,"box",Vector3(0.23,0.025,0.025),Vector3(0,0,0.02),ink)
  else:
   for side in [-1,1]:add_part(glyph,"lens",Vector3(0.09,0.06,0.09),Vector3(side*0.085,0,0),ink)
  if int(s.tier)==1:add_part(glyph,"box",Vector3(0.22,0.025,0.025),Vector3(0,0,0.12),color)
 var orbit=rig.get_node_or_null("UltimateOrbit")
 var orbit_mesh=combine(orbit) if orbit!=null else null
 var hull_mesh=combine(rig)
 rig_meshes[cache_key]={"hull":hull_mesh,"orbit":orbit_mesh}
 rig_order.append(cache_key)
 while rig_order.size()>64:rig_meshes.erase(rig_order.pop_front())
 rig.scale=Vector3.ONE*clampf(float(settings().get("ornament_scale",1)),0.5,1.1)
 return rig

static func add_combined(parent:Node3D,mesh_resource:Mesh) -> void:
 if mesh_resource==null:return
 var part=MeshInstance3D.new();part.mesh=mesh_resource;part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(part)
static func combine(root:Node3D):
 var groups={};var parts=[]
 for part in root.find_children("*","MeshInstance3D",true,false):
  if root.name!="UltimateOrbit" and root.get_node_or_null("UltimateOrbit")!=null and root.get_node("UltimateOrbit").is_ancestor_of(part):continue
  var m=part.material_override
  if m==null:continue
  if not groups.has(m):groups[m]=SurfaceTool.new();groups[m].begin(Mesh.PRIMITIVE_TRIANGLES);groups[m].set_material(m)
  groups[m].append_from(part.mesh,0,root.global_transform.affine_inverse()*part.global_transform);parts.append(part)
 var combined=ArrayMesh.new()
 for m in groups:groups[m].commit(combined)
 for part in parts:part.free()
 # Only the ultimate pivot is animated; all other decorations become a few cached surfaces.
 for child in root.get_children():
  if child.name!="UltimateOrbit":child.free()
 if combined.get_surface_count()==0:return null
 add_combined(root,combined);resource_creations+=1;return combined

static func thumbnail(style: Dictionary) -> Texture2D:
 var key=fingerprint(style)
 if not thumbnail_cache.has(key):
  var texture=preload("res://scripts/hyperspace_icon_texture.gd").bake(style,icon(str(style.weapon)).get_image(),Color(str(settings().get("ultimate_color","7ef5e0"))))
  thumbnail_cache[key]=texture;resource_creations+=1
 if key in thumbnail_order:thumbnail_order.erase(key)
 thumbnail_order.append(key)
 while thumbnail_order.size()>64:thumbnail_cache.erase(thumbnail_order.pop_front())
 return thumbnail_cache[key]
