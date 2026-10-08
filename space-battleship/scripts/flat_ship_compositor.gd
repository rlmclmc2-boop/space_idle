extends ColorRect
## Opt-in all-or-nothing presentation candidate. Owns no simulation state.
const MAX_ITEMS := 48
const MAX_TEXTURES := 12
const RECIPE := "res://assets/ships/flat_parts/catalog.json"
const SOURCE := preload("res://scripts/flat_ship_compositor.gdshader")
var enabled := false
var active := false
var fallback_reason := "candidate disabled"
var view
var catalog: Dictionary = {}
var items: Array[Dictionary] = []
var geometry: Array[VisualInstance3D] = []
var covered: Dictionary = {}
var textures: Array[Texture2D] = []
var shader_cache: Dictionary = {}
var dirty := true
var observed: Dictionary = {}
var changed_geometry: Dictionary = {}
var last_uniforms: Dictionary = {}
var lighting_matches := false
var light_values: Array = []

func configure(owner_view) -> void:
	view = owner_view
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	if enabled:_initialize_catalog()

func _initialize_catalog() -> void:
	if FileAccess.file_exists(RECIPE):
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(RECIPE))
		if value is Dictionary:catalog = value
	_watch(view.world)

func _watch(node: Node) -> void:
	if observed.has(node.get_instance_id()):return
	observed[node.get_instance_id()] = true
	node.child_entered_tree.connect(_watch)
	node.child_exiting_tree.connect(_unwatch)
	for child in node.get_children():_watch(child)
	dirty = true

func _unwatch(node: Node) -> void:
	observed.erase(node.get_instance_id())
	dirty = true

func invalidate() -> void:
	dirty = true

func _texture(texture: Texture2D) -> int:
	var found := textures.find(texture)
	if found >= 0:return found
	textures.append(texture)
	return textures.size()-1

func _cover(node: GeometryInstance3D) -> void:
	covered[node.get_instance_id()] = true

func _relative_to(node: Node3D, root: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node3D = node
	while current != root:
		result = current.transform*result
		current = current.get_parent() as Node3D
	return result

func _mesh_changed(id: int) -> void:
	changed_geometry[id] = true
	invalidate()

func _part(root: Node3D, pivot: bool) -> Dictionary:
	var parts: Array[Dictionary] = []
	# Imported geometry/material identity uses the same stable recipe as hulls.
	var source_root: Node3D = root
	while source_root.scene_file_path.is_empty():source_root = source_root.get_parent() as Node3D
	for mesh in root.find_children("*","MeshInstance3D",true,false):
		if not pivot and root.find_child("TurretPivot",true,false).is_ancestor_of(mesh):continue
		if mesh.mesh.resource_path.is_empty() or changed_geometry.has(mesh.mesh.get_instance_id()):return {}
		var reject := _mesh_changed.bind(mesh.mesh.get_instance_id())
		if not mesh.mesh.changed.is_connected(reject):mesh.mesh.changed.connect(reject)
		var mats: Array[Material] = []
		for surface in mesh.mesh.get_surface_count():
			var mat: Material = mesh.get_active_material(surface)
			if mat==null:return {}
			mats.append(mat)
			if not mat.changed.is_connected(invalidate):mat.changed.connect(invalidate)
			if mat is ShaderMaterial and not mat.shader.changed.is_connected(invalidate):mat.shader.changed.connect(invalidate)
		parts.append({"source":mesh,"source_path":source_root.scene_file_path,
			"transform":_relative_to(mesh,root),"materials":mats,"mesh":mesh.mesh})
	var signature: String = view.body_baker.appearance_signature(parts)
	var asset: Dictionary = catalog.get("parts",{}).get(signature,{})
	if asset.is_empty() or int(asset.get("frames",0))!=64:return {}
	if not ResourceLoader.exists(str(asset.get("atlas",""))):return {}
	var texture := load(str(asset.atlas)) as Texture2D
	if texture == null:return {}
	for part in parts:_cover(part.source)
	return {"node":root,"kind":1,"asset":asset,"parts":parts,"color":_texture(texture),"depth":_texture(texture)}

func _lighting_identity() -> String:
	var values: Array = []
	for child in view.world.get_children():
		if child is DirectionalLight3D:
			values.append([child.transform,child.light_color,child.light_energy])
		elif child is WorldEnvironment:
			var env: Environment = child.environment
			values.append([env.background_mode,env.background_color,env.ambient_light_source,env.ambient_light_color,env.ambient_light_energy])
			if not env.changed.is_connected(invalidate):env.changed.connect(invalidate)
	return var_to_str(values).sha256_text()

func _rebuild() -> void:
	dirty = false
	lighting_matches = _lighting_identity() == str(catalog.get("light",""))
	var light: DirectionalLight3D = view.world.get_node("KeyLight")
	light_values = [light.transform,light.light_color,light.light_energy]
	items.clear();geometry.clear();covered.clear();textures.clear()
	for node in view.world.find_children("*","VisualInstance3D",true,false):
		if node != light:geometry.append(node)
	for record in view.body_baker.records.values():
		if not is_instance_valid(record.plane) or not view.body_baker.textures.has(record.key):continue
		var entry: Dictionary = view.body_baker.textures[record.key]
		var texture: Texture2D = entry.material.get_shader_parameter("body_texture")
		if texture == null:continue
		items.append({"node":record.plane,"kind":0,"span":float(entry.span),"color":_texture(texture)})
		_cover(record.plane)
	for module in view.modules:
		for is_pivot in [false,true]:
			var part := _part(module.pivot if is_pivot else module.node,is_pivot)
			if not part.is_empty():items.append(part)
	if is_instance_valid(view.shield) and catalog.has("shield_map") and ResourceLoader.exists(str(catalog.shield_map)):
		var texture := load(str(catalog.shield_map)) as Texture2D
		if texture != null:
			items.append({"node":view.shield,"kind":2,"color":_texture(texture)})
			_cover(view.shield)
	for plume in view.exhaust_nodes:
		items.append({"node":plume,"kind":3})
		_cover(plume)
	if textures.size()>MAX_TEXTURES:return
	# One shader per texture-count layout; no shader compilation on pose changes.
	var key := str(textures.size())
	if not shader_cache.has(key):
		var declarations := ""
		var sampler := "vec4 sample_asset(int index, vec2 uv) {\n"
		for i in textures.size():
			declarations += "uniform sampler2D asset_%d : filter_linear, repeat_disable;\n"%i
			sampler += "if (index == %d) return texture(asset_%d, uv);\n"%[i,i]
		sampler += "return vec4(0.0);\n}\n"
		var shader := Shader.new()
		shader.code = SOURCE.code.replace("vec4 sample_asset(int index, vec2 uv) { return vec4(0.0); }",declarations+sampler)
		shader_cache[key] = shader
	var result := ShaderMaterial.new();result.shader = shader_cache[key]
	material = result
	last_uniforms.clear()
	for i in textures.size():_uniform("asset_%d"%i,textures[i])

func _uniform(key: String, value: Variant) -> void:
	if last_uniforms.has(key) and last_uniforms[key] == value:return
	last_uniforms[key] = value
	(material as ShaderMaterial).set_shader_parameter(key,value)

func _fail(reason: String) -> bool:
	fallback_reason = reason
	active = false
	if visible:visible = false
	return false

func sync() -> bool:
	if not enabled:return _fail("candidate disabled")
	if observed.is_empty():_initialize_catalog()
	if catalog.is_empty():return _fail("offline part catalog unavailable")
	if dirty:_rebuild()
	if textures.size()>MAX_TEXTURES:return _fail("texture coverage exceeds compositor capacity")
	if not is_equal_approx(view.camera.size,view.viewport.size.x*view.WORLD_PER_PIXEL):return _fail("camera scale differs from projection recipe")
	if view.camera.projection != Camera3D.PROJECTION_ORTHOGONAL or not view.camera.global_basis.is_equal_approx(Basis(Vector3.RIGHT,-PI/2.0)):
		return _fail("camera differs from fixed top-down recipe")
	var light: DirectionalLight3D = view.world.get_node("KeyLight")
	if not lighting_matches or light_values != [light.transform,light.light_color,light.light_energy]:return _fail("lighting differs from offline recipe")
	if not light.is_visible_in_tree():return _fail("offline light is hidden")
	if light.shadow_enabled:return _fail("live shadow receiver requires realtime path")
	for node in geometry:
		if is_instance_valid(node) and node.is_visible_in_tree() and not covered.has(node.get_instance_id()):
			return _fail("unexported visible geometry: "+str(node.name))
	var centers := PackedVector4Array()
	var params := PackedVector4Array()
	var assets := PackedVector4Array()
	var effects := PackedVector4Array()
	var bounds := Rect2()
	var density: Vector2 = (get_viewport().get_stretch_transform()*view.get_global_transform_with_canvas()).get_scale().abs()
	for item in items:
		var node: Node3D = item.node
		if not is_instance_valid(node) or not node.is_visible_in_tree():continue
		var basis := node.global_basis
		var scale := basis.get_scale().abs()
		if absf(basis.x.y)>0.0001 or absf(basis.z.y)>0.0001 or absf(basis.y.x)>0.0001 or absf(basis.y.z)>0.0001 or absf(basis.x.dot(basis.z))>0.0001 or basis.y.y<=0.0 or basis.determinant()<=0.0:
			return _fail("tilted or mirrored geometry")
		var yaw := atan2(basis.z.x,basis.z.z)
		var center: Vector2 = view.camera.unproject_position(node.global_position)
		var span := Vector2.ONE
		var depth_low := 0.0
		var depth_span := 0.0
		var orientation := Vector2(cos(yaw),sin(yaw))
		var color_index := int(item.get("color",0))
		var effect := Vector4.ZERO
		if item.kind==0:
			var mat := node.material_override as ShaderMaterial
			if mat == null or mat.shader.code.sha256_text()!=catalog.body_proxy_shader or mat.get_shader_parameter("body_texture")!=textures[color_index]:return _fail("body proxy material changed")
			span = Vector2.ONE*float(item.span)
		elif item.kind==1:
			for part in item.parts:
				if not is_instance_valid(part.source) or not part.source.is_visible_in_tree() or part.source.mesh!=part.mesh or _relative_to(part.source,node)!=part.transform:return _fail("turret mesh or local pose changed")
				for surface in part.materials.size():
					if part.source.get_active_material(surface)!=part.materials[surface]:invalidate();return _fail("turret material assignment changed")
			if not is_equal_approx(scale.x,scale.z):return _fail("nonuniform turret scale")
			var asset: Dictionary = item.asset
			span = Vector2.ONE*float(asset.span)
			depth_low = float(asset.low)*scale.y
			depth_span = float(asset.height)*scale.y
			var direction := fposmod(yaw,TAU)*float(asset.frames)/TAU
			var first := floorf(direction)
			var residual := -yaw+first*TAU/float(asset.frames)
			orientation = Vector2(first,fposmod(first+1.0,float(asset.frames)))
			effect = Vector4(float(asset.columns),direction-first,cos(residual),sin(residual))
		elif item.kind==2:
			var sphere := node.mesh as SphereMesh
			if sphere == null or sphere.radius!=1.0 or sphere.height!=2.0 or sphere.radial_segments!=32 or sphere.rings!=16 or sphere.flip_faces:return _fail("shield geometry changed")
			if node.material_override != view.shield_material or view.shield_material.shader.code.sha256_text()!=catalog.shield_shader:return _fail("shield shader changed")
			span = Vector2.ONE*2.0
			depth_span = scale.y
			effect = Vector4(float(view.shield_material.get_shader_parameter("shield_opacity")),float(view.shield_material.get_shader_parameter("impact_strength")),scale.x/scale.y,scale.z/scale.y)
			var hit: Variant = view.shield_material.get_shader_parameter("hit_direction")
			if hit != null and not Vector3(hit).is_equal_approx(Vector3(-0.45,0.65,-0.6)):return _fail("shield hit direction changed")
		else:
			if not node.mesh is PlaneMesh or node.mesh.orientation!=PlaneMesh.FACE_Y:return _fail("exhaust geometry changed")
			var mat := node.material_override as ShaderMaterial
			if mat == null or mat.shader.code.sha256_text()!=catalog.exhaust_shader:return _fail("exhaust shader changed")
			span = node.mesh.size
			effect = Vector4(float(mat.get_shader_parameter("engine_emission")),float(mat.get_shader_parameter("phase")),0,0)
		span *= Vector2(scale.x,scale.z)/view.WORLD_PER_PIXEL
		var native := maxf(span.x*density.x,span.y*density.y)
		var limit := int(item.asset.size) if item.kind==1 else 1024
		if item.kind!=3 and native>limit:return _fail("asset would exceed native pixel precision")
		var radius := span.length()*0.5
		var rect := Rect2(center-Vector2.ONE*radius,Vector2.ONE*radius*2.0)
		bounds = rect if centers.is_empty() else bounds.merge(rect)
		centers.append(Vector4(center.x,center.y,span.x,span.y))
		params.append(Vector4(0.0,node.global_position.y,depth_low,depth_span))
		assets.append(Vector4(item.kind,color_index,orientation.x,orientation.y))
		effects.append(effect)
	if centers.is_empty() or centers.size()>MAX_ITEMS:return _fail("visible item count outside candidate capacity")
	bounds = bounds.intersection(Rect2(Vector2.ZERO,view.size)).grow(2.0)
	if position!=bounds.position:position=bounds.position
	if size!=bounds.size:size=bounds.size
	_uniform("origin",bounds.position)
	_uniform("extent",bounds.size)
	_uniform("item_count",centers.size())
	_uniform("animation_time",float(view.elapsed))
	centers.resize(MAX_ITEMS);params.resize(MAX_ITEMS);assets.resize(MAX_ITEMS);effects.resize(MAX_ITEMS)
	_uniform("centers",centers);_uniform("params",params);_uniform("assets",assets);_uniform("effects",effects)
	active=true;fallback_reason=""
	if not visible:visible=true
	return true
