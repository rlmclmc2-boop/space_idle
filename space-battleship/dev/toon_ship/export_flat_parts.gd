extends SceneTree
## Art-only export; no game, profile, saves, simulation or performance measurement.
const OUTPUT := "res://assets/ships/flat_parts/"
const PIXELS := 192
const FRAMES := 64
const COLUMNS := 8
const SETTINGS := {"toon_steps":3,"toon_shadow_threshold":0.60,"rim_strength":0.22,
	"rim_power":4.5,"specular_strength":0.04,"emission_strength":1.0,
	"engine_emission":1.4,"shield_opacity":0.12}
var view
var stage: SubViewport
var scene: Node3D
var camera: Camera3D
var rig: Node3D
var catalog: Dictionary = {"parts":{}}
var images: Dictionary = {}
const DEPTH_CODE := """shader_type spatial;
render_mode unshaded, fog_disabled;
uniform float bottom;
uniform float height;
varying float local_height;
void vertex(){local_height=VERTEX.y;}
void fragment(){float value=clamp((local_height-bottom)/height,0.0,1.0); ALBEDO=vec3(value);}
"""
const SHIELD_MAP_CODE := """shader_type spatial;
render_mode unshaded, fog_disabled, cull_back;
varying vec3 point;
void vertex(){point=normalize(VERTEX);}
void fragment(){ALBEDO=point*0.5+0.5;}
"""

func _initialize() -> void:
	export_art.call_deferred()

func export_art() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var ornaments_only := "--ornaments-only" in OS.get_cmdline_user_args()
	if ornaments_only:catalog=JSON.parse_string(FileAccess.get_file_as_string(OUTPUT+"catalog.json"))
	view=load("res://scripts/presented_ship_view.gd").new()
	view.size=Vector2(572,960)
	root.add_child(view)
	view.flat_compositor.enabled=false
	view.visible=false
	view.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	if not ornaments_only:
		view.set_hull("corvette")
		# Use an actual manifest key if the authored hull IDs differ.
		if view.ship==null:view.set_hull(str(view.manifest.hulls.keys()[0]))
		view.set_loadout([{ "key":"laser" },{ "key":"missile" },{ "key":"cannon" },{ "key":"longLaser" }],4)
		view.apply_parameters(SETTINGS,true,true)
	stage=SubViewport.new();stage.size=Vector2i(PIXELS,PIXELS)
	stage.own_world_3d=true;stage.transparent_bg=true;stage.msaa_3d=Viewport.MSAA_4X
	stage.render_target_update_mode=SubViewport.UPDATE_DISABLED
	root.add_child(stage)
	scene=Node3D.new();stage.add_child(scene)
	for child in view.world.get_children():
		if child is WorldEnvironment or child is DirectionalLight3D:
			var copy=child.duplicate()
			if copy is DirectionalLight3D:copy.shadow_enabled=false
			scene.add_child(copy)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect=Camera3D.KEEP_WIDTH;camera.position=Vector3(0,60,0)
	camera.rotation_degrees.x=-90;camera.far=110;scene.add_child(camera)
	if not ornaments_only:
		for module in view.modules:
			await export_part(module.node,false,str(module.key)+" bearing")
			await export_part(module.pivot,true,str(module.key)+" turret")
		await export_shield_map()
	await export_ornaments()
	if not ornaments_only:
		catalog.shield_shader=view.shield_material.shader.code.sha256_text()
		catalog.exhaust_shader=view.EXHAUST.code.sha256_text()
		catalog.light=lighting_identity(view.world)
		catalog.body_proxy_shader=view.body_baker.BODY_SHADER.code.sha256_text()
	var file=FileAccess.open(OUTPUT+"catalog.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(catalog,"\t")+"\n")
	print("FLAT PART ART EXPORT COMPLETE: ",catalog.parts.size()," parts")
	quit()

static func relative_to(node: Node3D, root_node: Node3D) -> Transform3D:
	var transform:=Transform3D.IDENTITY
	var current: Node3D=node
	while current!=root_node:
		transform=current.transform*transform
		current=current.get_parent() as Node3D
	return transform

static func lighting_identity(world: Node3D) -> String:
	var values: Array=[]
	for child in world.get_children():
		if child is DirectionalLight3D:values.append([child.transform,child.light_color,child.light_energy])
		elif child is WorldEnvironment:
			var env: Environment=child.environment
			values.append([env.background_mode,env.background_color,env.ambient_light_source,env.ambient_light_color,env.ambient_light_energy])
	return var_to_str(values).sha256_text()

func export_part(source: Node3D, pivot: bool, label: String) -> void:
	var parts: Array[Dictionary]=[]
	var source_root: Node3D=source
	while source_root.scene_file_path.is_empty():source_root=source_root.get_parent() as Node3D
	var low:=INF;var high:=-INF;var radius:=0.0
	rig=Node3D.new();scene.add_child(rig)
	for mesh in source.find_children("*","MeshInstance3D",true,false):
		if not pivot and source.find_child("TurretPivot",true,false).is_ancestor_of(mesh):continue
		var transform:=relative_to(mesh,source)
		var materials: Array[Material]=[]
		for index in mesh.mesh.get_surface_count():materials.append(mesh.get_active_material(index))
		parts.append({"source":mesh,"source_path":source_root.scene_file_path,"transform":transform,"materials":materials})
		var copy:=MeshInstance3D.new();copy.mesh=mesh.mesh;copy.transform=transform
		for index in materials.size():copy.set_surface_override_material(index,materials[index])
		rig.add_child(copy)
		var bounds: AABB=transform*mesh.get_aabb()
		low=minf(low,bounds.position.y);high=maxf(high,bounds.end.y)
		for index in 8:
			var corner:=bounds.get_endpoint(index)
			radius=maxf(radius,Vector2(corner.x,corner.z).length())
	var signature: String=view.body_baker.appearance_signature(parts)
	if signature=="unsupported":push_error("Unsupported art source: "+label);quit(1);return
	camera.size=radius*2.0*1.08
	var colors:=Image.create(PIXELS*COLUMNS,PIXELS*COLUMNS,false,Image.FORMAT_RGBA8)
	var depths:=Image.create(PIXELS*COLUMNS,PIXELS*COLUMNS,false,Image.FORMAT_RGBA8)
	for frame in FRAMES:
		rig.rotation.y=TAU*float(frame)/FRAMES
		var image: Image=await capture()
		colors.blit_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),Vector2i(frame%COLUMNS,frame/COLUMNS)*PIXELS)
	var shader:=Shader.new();shader.code=DEPTH_CODE
	for mesh in rig.get_children():
		# Flatten source-local transforms into the mesh so stored height is in
		# the same root space as the compositor's projected depth.
		var baked:=SurfaceTool.new();baked.begin(Mesh.PRIMITIVE_TRIANGLES)
		for surface in mesh.mesh.get_surface_count():baked.append_from(mesh.mesh,surface,mesh.transform)
		mesh.mesh=baked.commit();mesh.transform=Transform3D.IDENTITY
		var mat:=ShaderMaterial.new();mat.shader=shader
		mat.set_shader_parameter("bottom",low);mat.set_shader_parameter("height",maxf(high-low,0.0001))
		mesh.material_override=mat
	for frame in FRAMES:
		rig.rotation.y=TAU*float(frame)/FRAMES
		var image: Image=await capture()
		depths.blit_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),Vector2i(frame%COLUMNS,frame/COLUMNS)*PIXELS)
	var atlas:=Image.create(PIXELS*COLUMNS,PIXELS*COLUMNS*2,false,Image.FORMAT_RGBA8)
	atlas.blit_rect(colors,Rect2i(Vector2i.ZERO,colors.get_size()),Vector2i.ZERO)
	atlas.blit_rect(depths,Rect2i(Vector2i.ZERO,depths.get_size()),Vector2i(0,colors.get_height()))
	catalog.parts[signature]={"atlas":save_image(atlas),"span":camera.size,"low":low,"height":maxf(high-low,0.0001),"frames":FRAMES,"columns":COLUMNS,"size":PIXELS,"source":label}
	print("EXPORTED ",label)
	rig.free()

func capture() -> Image:
	stage.render_target_update_mode=SubViewport.UPDATE_ONCE
	await process_frame
	await RenderingServer.frame_post_draw
	var image:=stage.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	return image

func save_image(image: Image) -> String:
	# Byte-identical bearings share textures across weapon families.
	var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(image.get_data())
	var key:=digest.finish().hex_encode()
	if images.has(key):return images[key]
	var path:=OUTPUT+key+".png"
	if image.save_png(path)!=OK:push_error("Art file write failed");quit(1)
	images[key]=path
	return path

func export_shield_map() -> void:
	stage.size=Vector2i(1024,1024);camera.size=2.0
	var mesh:=MeshInstance3D.new()
	var sphere:=SphereMesh.new();sphere.radius=1.0;sphere.height=2.0;sphere.radial_segments=32;sphere.rings=16
	mesh.mesh=sphere
	var mat:=ShaderMaterial.new();var shader:=Shader.new();shader.code=SHIELD_MAP_CODE;mat.shader=shader;mesh.material_override=mat
	scene.add_child(mesh)
	catalog.shield_map=save_image(await capture())
	mesh.free()

func export_ornaments() -> void:
	var appearance = load("res://scripts/hyperspace_appearance.gd")
	catalog.ornaments = {}
	stage.size=Vector2i(256,256)
	for weapon in ["laser","missile","cannon","longLaser"]:
		for quality in ["white","blue","gold","legendary"]:
			for category in ["","attack","chain","shield","tempo"]:
				for tier in ([6] if category.is_empty() else [1,2]):
					var style: Dictionary=appearance.project({"weapon":weapon,"origin_quality":quality,"ultimate":true})
					style.category=category;style.tier=tier
					var model:=Node3D.new();view.world.add_child(model)
					var ornament: Node3D=appearance.build_ornaments(model,style)
					await export_ornament_group(ornament,weapon+":"+quality+":"+category+":"+str(tier))
					await export_ornament_group(ornament.get_node("UltimateOrbit"),"ultimate orbit")
					model.free()
	print("EXPORTED ORNAMENT GROUPS: ",catalog.ornaments.size())

func export_ornament_group(source: Node3D, label: String) -> void:
	var recipe=load("res://scripts/flat_ornament_recipe.gd")
	var parts: Array[Dictionary]=recipe.collect(source)
	if parts.is_empty():return
	var signature: String=recipe.signature(parts)
	if catalog.ornaments.has(signature):return
	if signature=="unsupported":push_error("Unsupported ornament material");quit(1);return
	rig=Node3D.new();scene.add_child(rig)
	var low:=INF;var high:=-INF;var radius:=0.0
	for part in parts:
		var copy:=MeshInstance3D.new();copy.mesh=part.mesh;copy.transform=part.transform
		for surface in part.materials.size():copy.set_surface_override_material(surface,part.materials[surface])
		rig.add_child(copy)
		var bounds: AABB=part.transform*part.source.get_aabb()
		low=minf(low,bounds.position.y);high=maxf(high,bounds.end.y)
		for index in 8:
			var corner:=bounds.get_endpoint(index)
			radius=maxf(radius,Vector2(corner.x,corner.z).length())
	camera.size=radius*2.0*1.08
	var color: Image=await capture()
	var shader:=Shader.new();shader.code=DEPTH_CODE
	for mesh in rig.get_children():
		var baked:=SurfaceTool.new();baked.begin(Mesh.PRIMITIVE_TRIANGLES)
		for surface in mesh.mesh.get_surface_count():baked.append_from(mesh.mesh,surface,mesh.transform)
		mesh.mesh=baked.commit();mesh.transform=Transform3D.IDENTITY
		var mat:=ShaderMaterial.new();mat.shader=shader
		mat.set_shader_parameter("bottom",low);mat.set_shader_parameter("height",maxf(high-low,0.0001))
		mesh.material_override=mat
	var depth: Image=await capture()
	var atlas:=Image.create(256,512,false,Image.FORMAT_RGBA8)
	atlas.blit_rect(color,Rect2i(Vector2i.ZERO,color.get_size()),Vector2i.ZERO)
	atlas.blit_rect(depth,Rect2i(Vector2i.ZERO,depth.get_size()),Vector2i(0,256))
	catalog.ornaments[signature]={"atlas":save_image(atlas),"span":camera.size,"low":low,"height":maxf(high-low,0.0001),"size":256,"source":label}
	rig.free()
