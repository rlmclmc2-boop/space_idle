extends Control
## Editable GLB parts share one orthographic contract. Fixed lighting and exact
## body depth are baked only when availability changes; projected work geometry
## retains authored normals, depth and UVs without a full-frame 3D MSAA pass.
const MODEL=preload("res://assets/ui/reactor/b01/faceted-reactor.glb")
const SURFACE=preload("res://assets/ui/reactor/b01/faceted-surface.gdshader")
const OUTLINE=preload("res://assets/ui/reactor/b01/faceted-structure-outline.gdshader")
const DEPTH=preload("res://assets/ui/reactor/b01/faceted-depth.gdshader")
const BACKGROUND=preload("res://assets/ui/reactor/b01/faceted-canvas-background.gdshader")
const WORK=preload("res://assets/ui/reactor/b01/faceted-canvas-work.gdshader")
const IDS := ["weapons","defence","smelting","condensation"]
const SOURCE_SIZE:=Vector2(1187.0,1326.0)
const VIEW_SIZE:=Vector2(808.0,835.0)
const SOURCE_SCALE: float=835.0/1326.0
const SOURCE_OFFSET:=Vector2((808.0-1187.0*SOURCE_SCALE)*.5,0)
var _layout: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/reactor/b01/faceted-layout.json"))
var _single_mode: bool=false
var _baker: SubViewport
var _asset: Node3D
var _environment: Environment
var _core_lamp: OmniLight3D
var _background: ColorRect
var _background_material: ShaderMaterial
var _palette: Dictionary={}
var _bodies: Array=[]
var _outlines: Array[MeshInstance3D]=[]
var _outline_material: ShaderMaterial
var _groups: Dictionary={}
var _materials: Dictionary={}
var _mechanisms: Dictionary={}
var _age: Dictionary={}
var _enabled: Array=[]
var _loads: Dictionary={}
var _clock: float=-1.0
var _phase: float=0.0
var _cache_generation: int=0
var _cache_ready: bool=false
var diagnostics: Dictionary={"draws":0,"field_updates":0,"active_frames":0,"cache_renders":0}

static func source_point(point: Vector2) -> Vector2:return SOURCE_OFFSET+point*SOURCE_SCALE
static func source_rect(rect: Rect2) -> Rect2:return Rect2(source_point(rect.position),rect.size*SOURCE_SCALE)
static func visibility_power(value: float) -> float:return maxf(value,.18) if value>0.0 else 0.0

func _init() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	custom_minimum_size=VIEW_SIZE
	set_process(false)
	_background=ColorRect.new()
	_background.size=VIEW_SIZE
	_background.color=Color("0a1d30")
	_background.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(_background)
	_background_material=ShaderMaterial.new()
	_background_material.shader=BACKGROUND
	_baker=SubViewport.new()
	_baker.size=Vector2i(VIEW_SIZE)
	_baker.own_world_3d=true
	_baker.msaa_3d=Viewport.MSAA_2X
	_baker.render_target_update_mode=SubViewport.UPDATE_DISABLED
	add_child(_baker)
	var camera:=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=1326.0
	camera.near=.5
	camera.far=4000.0
	camera.position=Vector3(593.5,-663,1500)
	_baker.add_child(camera)
	camera.current=true
	_environment=Environment.new()
	_environment.background_mode=Environment.BG_COLOR
	_environment.background_color=Color("0a1d30")
	_environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	_environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color=Color("3c6592")
	_environment.ambient_light_energy=.18
	# The same broad cool hull / warm deck environment is reflected by metal.
	# This is initialized once for the cached structure, never per work tick.
	var sky_material:=ProceduralSkyMaterial.new()
	sky_material.sky_top_color=Color("20394f")
	sky_material.sky_horizon_color=Color("9eb8c8")
	sky_material.ground_horizon_color=Color("b6a17c")
	sky_material.ground_bottom_color=Color("122132")
	sky_material.sky_energy_multiplier=.45
	sky_material.ground_energy_multiplier=.30
	var sky:=Sky.new()
	sky.radiance_size=Sky.RADIANCE_SIZE_128
	sky.sky_material=sky_material
	_environment.sky=sky
	_environment.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
	var environment_node:=WorldEnvironment.new()
	environment_node.environment=_environment
	_baker.add_child(environment_node)
	var light:=DirectionalLight3D.new()
	light.light_color=Color("fff0d4")
	light.light_energy=1.0
	light.light_angular_distance=.6
	light.shadow_enabled=true
	light.shadow_opacity=.62
	light.directional_shadow_mode=DirectionalLight3D.SHADOW_ORTHOGONAL
	light.directional_shadow_max_distance=3000
	_baker.add_child(light)
	light.look_at_from_position(Vector3(80,-20,650),Vector3(594,-400,0))
	for x in [185.0,1010.0]:
		var luminaire:=OmniLight3D.new()
		luminaire.position=Vector3(x,-78.0,180.0)
		luminaire.light_color=Color("ffd6a0")
		luminaire.light_energy=.65
		luminaire.omni_range=650.0
		luminaire.omni_attenuation=1.8
		_baker.add_child(luminaire)
	_core_lamp=OmniLight3D.new()
	_core_lamp.light_color=Color("5bd8ff")
	_core_lamp.light_energy=0.0
	_core_lamp.omni_range=650.0
	_core_lamp.omni_attenuation=1.35
	_core_lamp.shadow_enabled=true
	_core_lamp.shadow_opacity=.72
	_baker.add_child(_core_lamp)
	_outline_material=ShaderMaterial.new()
	_outline_material.shader=OUTLINE
	_asset=MODEL.instantiate()
	_baker.add_child(_asset)
	for group in _asset.get_children():
		var key: String=String(group.name)
		var canvas:=Node2D.new()
		canvas.name="Working_"+key
		add_child(canvas)
		_groups[key]=canvas
		_materials[key]=[]
		_mechanisms[key]=[]
		_age[key]=0.0
		for child in group.get_children():
			if child is MeshInstance3D:_prepare_mesh(child,key,group.transform*child.transform)
		if key in IDS or key.begins_with("pipe_") or key.begins_with("console_"):
			group.visible=false
			canvas.visible=false

func _ready() -> void:
	set_notify_transform(true)
	_update_canvas_transform()

func _notification(what: int) -> void:
	if what==NOTIFICATION_TRANSFORM_CHANGED and is_inside_tree():_update_canvas_transform()

func _update_canvas_transform() -> void:
	var inverse: Transform2D=get_global_transform().affine_inverse()
	var basis:=Basis(Vector3(inverse.x.x,inverse.x.y,0),Vector3(inverse.y.x,inverse.y.y,0),Vector3(0,0,1))
	var matrix:=Transform3D(basis,Vector3(inverse.origin.x,inverse.origin.y,0))
	for materials in _materials.values():
		for material in materials:material.set_shader_parameter("stage_from_canvas",matrix)

func _kind(title: String) -> int:
	if "core energy rim" in title or "core field meridian" in title:return 12
	if "core containment glass" in title or "weapon chamber glazing" in title or "crystal containment glass" in title:return 1
	if "receiver acknowledgement" in title:return 11
	if "core transfer packet" in title:return 10
	if "core polar channel" in title:return 14
	if "core plasma kernel" in title:return 9
	if "core plasma strands" in title:return 2
	if "core plasma mass" in title:return 3
	if "shield bowed field" in title or "shield active rim" in title:return 4
	if title.begins_with("furnace feed"):return 8
	if title.begins_with("furnace ") and not "structure" in title:return 5
	if "crystal body" in title:return 6
	if "channel work" in title:return 7
	if "weapon charge segment" in title or "weapon output" in title:return 8
	return 0

func _prepare_mesh(node: MeshInstance3D,key: String,world: Transform3D) -> void:
	var title: String=String(node.name).replace("_"," ")
	var kind: int=_kind(title)
	if kind==0:
		var colors: Array=[]
		for index in range(node.mesh.get_surface_count()):
			var original: Material=node.mesh.surface_get_material(index)
			var color: Color=original.albedo_color if original is BaseMaterial3D else Color.WHITE
			var material_name: String=String(original.resource_name).to_lower() if original!=null else ""
			var role: int=1 if "steel" in material_name else 3 if "ceramic" in material_name else 4 if "glass" in material_name else 5 if "copper" in material_name else 0 if "armor" in material_name else 2
			var palette_key: String=color.to_html()+":"+str(role)
			if not _palette.has(palette_key):
				var material:=ShaderMaterial.new()
				material.shader=SURFACE
				material.set_shader_parameter("base_color",color)
				material.set_shader_parameter("surface_role",role)
				_palette[palette_key]=material
			node.set_surface_override_material(index,_palette[palette_key])
			colors.append(_palette[palette_key])
		var outline:=MeshInstance3D.new()
		outline.name="StructureSilhouette"
		outline.mesh=node.mesh
		outline.material_override=_outline_material
		outline.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(outline)
		_outlines.append(outline)
		_bodies.append({"node":node,"materials":colors})
		return
	node.visible=false
	var part:=Node2D.new()
	part.name=node.name
	var pivot:=Vector2(world.origin.x,-world.origin.y)
	part.position=source_point(pivot)
	part.scale=Vector2.ONE*SOURCE_SCALE
	_groups[key].add_child(part)
	if kind==1:part.z_index=5
	elif kind==9:part.z_index=3
	elif kind in [12,14]:part.z_index=2
	elif kind==10:part.z_index=4 if title.get_slice("packet ",1) in ["weapons","condensation"] else 0
	elif kind==3:part.z_index=1
	elif kind==2:part.z_index=2
	var bottom: float=-INF
	var right: float=-INF
	for index in range(node.mesh.get_surface_count()):
		var arrays: Array=node.mesh.surface_get_arrays(index)
		var raw: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		var vertices:=PackedVector2Array()
		var colors:=PackedColorArray()
		var points:=PackedVector3Array()
		var world_normals:=PackedVector3Array()
		var normal_basis: Basis=world.basis.inverse().transposed()
		for i in raw.size():
			var point: Vector3=world*raw[i]
			var normal: Vector3=(normal_basis*normals[i]).normalized()
			points.append(point)
			world_normals.append(normal)
			vertices.append(Vector2(point.x,-point.y)-pivot)
			var depth_code: int=int(roundf(clampf((point.z+256.0)/1024.0,0.0,1.0)*65535.0))
			colors.append(Color(float(depth_code/256)/255.0,float(depth_code%256)/255.0,normal.x*.5+.5,normal.y*.5+.5))
			bottom=maxf(bottom,-point.y)
			right=maxf(right,point.x)
		var original_indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		if original_indices.is_empty():
			for i in raw.size():original_indices.append(i)
		var indices:=PackedInt32Array()
		for triangle in range(0,original_indices.size(),3):
			var a: int=original_indices[triangle]
			var b: int=original_indices[triangle+1]
			var c: int=original_indices[triangle+2]
			# The only open, double-sided part is the bowed projection surface.
			if kind not in [4,7] and (world_normals[a]+world_normals[b]+world_normals[c]).z<=0.00001:continue
			indices.append_array(PackedInt32Array([a,b,c]))
		if indices.is_empty():continue
		var projected: Array=[]
		projected.resize(Mesh.ARRAY_MAX)
		projected[Mesh.ARRAY_VERTEX]=vertices
		projected[Mesh.ARRAY_COLOR]=colors
		projected[Mesh.ARRAY_INDEX]=indices
		projected[Mesh.ARRAY_TEX_UV]=arrays[Mesh.ARRAY_TEX_UV]
		var mesh:=ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,projected)
		var drawable:=MeshInstance2D.new()
		drawable.mesh=mesh
		var original: Material=node.mesh.surface_get_material(index)
		var color: Color=original.albedo_color if original is BaseMaterial3D else Color.WHITE
		var material:=ShaderMaterial.new()
		material.shader=WORK
		material.set_shader_parameter("base_color",color)
		material.set_shader_parameter("work_kind",kind)
		if kind==10:
			var id: String=title.get_slice("packet ",1)
			var target: Array=_layout.ports[id].core_interface_source3d
			material.set_shader_parameter("transfer_target",Vector3(target[0],target[1],target[2]))
			material.set_shader_parameter("transfer_layer",1.0 if id in ["weapons","condensation"] else -1.0)
			material.set_meta("outlet",id)
		if kind==11:material.set_shader_parameter("receiver_u",float(_layout.ports[key].receiver_u))
		if kind==8:material.set_shader_parameter("work_zone",2 if title.begins_with("weapon output") else 1 if title.begins_with("weapon") else 0)
		if kind==9:material.set_shader_parameter("work_zone",1 if "cyan" in String(original.resource_name).to_lower() else 0)
		if kind==4:material.set_shader_parameter("work_zone",1 if "bowed" in title else 0)
		if kind==5:material.set_shader_parameter("work_zone",0 if "pour" in title else 3 if "outlet" in title else 2 if "liquid" in title else 1)
		drawable.material=material
		part.add_child(drawable)
		_materials[key].append(material)
	_mechanisms[key].append({"node":part,"title":title,"origin":pivot,"bottom":bottom,"right":right,"kind":kind})
	part.visible=kind==1

func _pipe_key(id: String) -> String:
	return "pipe_single_smelting" if _single_mode and id=="smelting" else "pipe_"+id

func _group_visible(key: String,ids: Array) -> bool:
	if key=="pipe_single_smelting":return _single_mode
	if key.begins_with("pipe_"):return key.trim_prefix("pipe_") in ids and not (_single_mode and key=="pipe_smelting")
	if key in IDS:return key in ids
	if key.begins_with("console_"):return not ids.is_empty() and int(key.trim_prefix("console_"))==ids.size()
	return true

func _install_composition(ids: Array) -> void:
	_single_mode=ids.size()==1 and ids[0]=="smelting"
	for key in _groups:
		var shift:=Vector2.ZERO
		if _single_mode and _layout.single_smelting.shifts.has(key):
			var raw: Array=_layout.single_smelting.shifts[key]
			shift=Vector2(raw[0],raw[1])
		_groups[key].position=shift*SOURCE_SCALE
		_asset.get_node(NodePath(key)).position=Vector3(shift.x,-shift.y,0)
		_groups[key].visible=_group_visible(key,ids)
		for material in _materials[key]:
			material.set_shader_parameter("assembly_offset",Vector3(shift.x,-shift.y,0))
			if key in IDS:material.set_shader_parameter("receiver_u",float(_layout.single_smelting.receiver_u) if _single_mode and key=="smelting" else float(_layout.ports[key].receiver_u))

func show_snapshot(ids: Array,loads: Dictionary) -> void:
	if ids==_enabled and loads==_loads:return
	var availability_changed: bool=ids!=_enabled or _cache_generation==0
	var previous: Dictionary=_loads
	if availability_changed:_install_composition(ids)
	_enabled=ids.duplicate()
	_loads=loads.duplicate()
	if float(loads.get("core",0.0))>0.0 and float(previous.get("core",0.0))<=0.0:
		_phase=0.0
		for key in ["core"]+ids+ids.map(func(id):return _pipe_key(str(id))):
			for material in _materials[key]:material.set_shader_parameter("phase",_phase)
	for id in IDS:
		_groups[id].visible=id in ids
		var load: float=float(loads.get(id,0.0)) if id in ids else 0.0
		if load>0.0 and float(previous.get(id,0.0))<=0.0:
			_age[id]=0.0
			for material in _materials[id]:material.set_shader_parameter("powered_at",_phase)
		for key in [id,_pipe_key(id)]:
			for material in _materials[key]:material.set_shader_parameter("load_fraction",visibility_power(load))
			for mechanism in _mechanisms[key]:mechanism.node.visible=load>0.0 or mechanism.kind==1
	var core_load: float=visibility_power(float(loads.get("core",0.0)))
	for material in _materials.core:
		material.set_shader_parameter("load_fraction",core_load)
		if material.has_meta("outlet"):material.set_shader_parameter("outlet_enabled",str(material.get_meta("outlet")) in ids)
	for mechanism in _mechanisms.core:mechanism.node.visible=core_load>0.0 or mechanism.kind==1
	_update_core_light()
	if availability_changed:_refresh_bake(ids)
	_animate_mechanisms()
	diagnostics.field_updates+=1

func _update_core_light() -> void:
	var cycle: float=fposmod(_phase/4.8,1.0)
	var gathering: float=smoothstep(0.0,.43,cycle)*(1.0-smoothstep(.72,.92,cycle))
	var compression: float=smoothstep(.43,.60,cycle)*(1.0-smoothstep(.66,.80,cycle))
	var release: float=smoothstep(.60,.64,cycle)*(1.0-smoothstep(.66,.72,cycle))
	var radiance: float=clampf(.58+.20*gathering+.12*compression+.10*release,0.0,1.0)
	_background_material.set_shader_parameter("core_power",visibility_power(float(_loads.get("core",0.0)))*radiance)

func _refresh_bake(ids: Array) -> void:
	for outline in _outlines:outline.visible=true
	for body in _bodies:
		for index in body.materials.size():body.node.set_surface_override_material(index,body.materials[index])
	_environment.background_color=Color("0a1d30")
	_cache_generation+=1
	var generation: int=_cache_generation
	for group in _asset.get_children():
		var key: String=String(group.name)
		group.visible=_group_visible(key,ids)
	_core_lamp.position=Vector3(724.0 if _single_mode else 594.0,-340.0,235.0)
	_core_lamp.light_energy=0.0
	_baker.msaa_3d=Viewport.MSAA_2X
	_baker.render_target_update_mode=SubViewport.UPDATE_ONCE
	_finish_bake(generation)

func _finish_bake(generation: int) -> void:
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	if generation!=_cache_generation:return
	var resting:=ImageTexture.create_from_image(_baker.get_texture().get_image())
	_background_material.set_shader_parameter("resting_surface",resting)
	_background_material.set_shader_parameter("working_surface",resting)
	_background.material=_background_material
	_core_lamp.light_energy=1.65
	_baker.render_target_update_mode=SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	if generation!=_cache_generation:return
	var working:=ImageTexture.create_from_image(_baker.get_texture().get_image())
	_background_material.set_shader_parameter("working_surface",working)
	for outline in _outlines:outline.visible=false
	var depth_material:=ShaderMaterial.new()
	depth_material.shader=DEPTH
	for body in _bodies:
		for index in body.materials.size():body.node.set_surface_override_material(index,depth_material)
	_environment.background_color=Color.BLACK
	_baker.msaa_3d=Viewport.MSAA_DISABLED
	_baker.render_target_update_mode=SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	if generation!=_cache_generation:return
	var depth:=ImageTexture.create_from_image(_baker.get_texture().get_image())
	for materials in _materials.values():
		for material in materials:
			material.set_shader_parameter("body_depth",depth)
			material.set_shader_parameter("depth_ready",true)
	for body in _bodies:
		for index in body.materials.size():body.node.set_surface_override_material(index,body.materials[index])
	_environment.background_color=Color("0a1d30")
	_baker.render_target_update_mode=SubViewport.UPDATE_DISABLED
	for outline in _outlines:outline.visible=true
	_cache_ready=true
	diagnostics.cache_renders+=3
	queue_redraw()

func clear_snapshot() -> void:show_snapshot([], {})

func _animate_mechanisms() -> void:
	for id in _enabled:
		if float(_loads.get(id,0.0))<=0.0:continue
		var age: float=float(_age[id])
		for mechanism in _mechanisms[id]:
			var part: Node2D=mechanism.node
			var title: String=mechanism.title
			var origin: Vector2=mechanism.origin
			if title.begins_with("weapon charge segment"):
				var index: int=int(title.get_slice("segment ",1))
				var charge: float=clampf(fmod(age,1.8)/1.17*3.0-float(index),0.0,1.0)
				part.scale=Vector2(1.0,maxf(.02,charge))*SOURCE_SCALE
				part.position=source_point(Vector2(origin.x,mechanism.bottom-(mechanism.bottom-origin.y)*charge))
				part.visible=charge>0.0
			elif title.begins_with("weapon output"):
				var shot: float=fmod(age,1.8)
				part.visible=shot>1.17 and shot<1.53
				if "pulse" in title:
					var pulse: float=maxf(.01,sin((shot-1.17)/.36*PI))
					part.scale=Vector2(pulse,1.0)*SOURCE_SCALE
					part.position=source_point(Vector2(float(mechanism.right)-(float(mechanism.right)-origin.x)*pulse,origin.y))
			elif title.begins_with("furnace feed"):
				var index: int=int(title.get_slice("feed ",1))
				var descent: float=fmod(age/1.2+float(index)/3,1.0)
				part.position=source_point(Vector2(origin.x,430+60*descent))
				part.visible=descent<.85
			elif title.begins_with("crystal body"):
				var growth: float=.12+.88*smoothstep(0.0,3.5,age)
				part.scale=Vector2(1.0,growth)*SOURCE_SCALE
				part.position=source_point(Vector2(origin.x,mechanism.bottom-(mechanism.bottom-origin.y)*growth))
			elif mechanism.kind==11:
				var u: float=float(_layout.single_smelting.receiver_u) if _single_mode and id=="smelting" else float(_layout.ports[id].receiver_u)
				var arrival: float=.72+.28*(u+.08)/1.16
				var age_cycles: float=_phase/4.8-arrival
				var event_time: float=(floorf(age_cycles)+arrival)*4.8
				var shown: bool=age_cycles>=0.0 and event_time+0.001>=_phase-age and fposmod(age_cycles,1.0)<.22
				if part.visible!=shown:part.visible=shown
		for material in _materials[id]:material.set_shader_parameter("formation",minf(age/1.6,1.0))

	for mechanism in _mechanisms.core:
		if mechanism.kind==10:
			var id: String=mechanism.title.get_slice("packet ",1)
			mechanism.node.visible=float(_loads.get("core",0.0))>0.0

func advance_visual_clock(game_time: float,paused: bool) -> bool:
	if not is_visible_in_tree():
		_clock=-1.0
		return false
	var elapsed: float=0.0 if _clock<0.0 else maxf(0.0,game_time-_clock)
	_clock=game_time
	if paused or elapsed==0.0 or float(_loads.get("core",0.0))<=0.0:return false
	_phase=fmod(_phase+elapsed,4096.0)
	_update_core_light()
	for id in _enabled:
		if float(_loads.get(id,0.0))<=0.0:continue
		_age[id]=float(_age[id])+elapsed
		for key in [id,_pipe_key(id)]:
			for material in _materials[key]:material.set_shader_parameter("phase",_phase)
	for material in _materials.core:material.set_shader_parameter("phase",_phase)
	_animate_mechanisms()
	diagnostics.active_frames+=1
	return true
func reset_clock() -> void:_clock=-1.0
func visual_phase() -> float:return _phase
