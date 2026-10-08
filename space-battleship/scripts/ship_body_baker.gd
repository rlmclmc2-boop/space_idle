extends Node
## Per-view, appearance-owned fixed-camera body textures. No gameplay authority.
## Original sockets/transforms survive. Turrets, shield, exhaust and ornaments do not bake.
const BODY_SHADER := preload("res://scripts/baked_ship_body.gdshader")
const BAKE_SIZE := 1024
var source_world: Node3D
var records: Dictionary = {}
var textures: Dictionary = {}
var pending: Array[String] = []
var finish_connected := false
var pixels_per_world := 20.0
var export_mode := false # Set only by the offline art exporter, never gameplay.
var catalog: Dictionary = {}
var source_hashes: Dictionary = {}
var body_roots: Dictionary = {} # Includes unsupported bodies with no bake record.
var shadow_sync_pending := false


func _ready() -> void:
	var path := "res://assets/ships/body_bakes/catalog.json"
	if FileAccess.file_exists(path): catalog = JSON.parse_string(FileAccess.get_file_as_string(path))


func attach(root: Node3D, key: String, refresh := false) -> void:
	var id := root.get_instance_id()
	if records.has(id) and records[id].request == key and not refresh: return
	var parts: Array[Dictionary] = []
	if records.has(id): parts = records[id].parts
	_release_root(id)
	body_roots[id] = root
	var release := _release_root.bind(id)
	if not root.tree_exiting.is_connected(release): root.tree_exiting.connect(release, CONNECT_ONE_SHOT)
	if not root.visibility_changed.is_connected(request_shadow_sync): root.visibility_changed.connect(request_shadow_sync)
	request_shadow_sync()
	if parts.is_empty():
		if not _collect(root, root, Transform3D.IDENTITY, parts) or parts.is_empty(): return
	else:
		# Refresh only the registered body meshes, never newly attached weapons,
		# shields, exhaust or ornaments elsewhere under the same model root.
		for part in parts:
			part.materials.clear()
			for surface in part.source.mesh.get_surface_count(): part.materials.append(part.source.get_active_material(surface))
	var signature := appearance_signature(parts)
	var cache_key := key+":"+signature
	records[id] = {"key": cache_key, "request": key, "parts": parts, "plane": null, "root": root, "active": false}
	if not textures.has(cache_key):
		if export_mode:
			textures[cache_key] = _create_texture(parts)
			pending.append(cache_key)
			_schedule_finish()
		elif catalog.has(signature):
			var asset := _load_asset(catalog[signature])
			if asset.is_empty(): return
			textures[cache_key] = asset
		else:
			return # Unexported appearance stays live; no startup rendering/readback.
	var entry: Dictionary = textures[cache_key]
	entry.users.append(id)
	var plane := MeshInstance3D.new()
	plane.name = "BakedBody"
	plane.set_meta("body_bake_proxy",true)
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE * float(entry.span)
	plane.mesh = quad
	plane.position = entry.center
	plane.material_override = entry.material
	# The alpha-tested plane still casts a live silhouette shadow. Its depth is
	# a flat proxy, not the original volume; this is a visual candidate to review.
	plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	plane.visible = false
	root.add_child(plane)
	records[id].plane = plane
	if entry.ready: _activate(records[id])


func _load_asset(asset: Dictionary) -> Dictionary:
	if not ResourceLoader.exists(str(asset.path)): return {}
	var texture := load(str(asset.path)) as Texture2D
	if texture == null: return {}
	var material := ShaderMaterial.new()
	material.shader = BODY_SHADER
	material.set_shader_parameter("body_texture",texture)
	var center: Array = asset.center
	return {"viewport": null, "scene": null, "material": material,
		"center": Vector3(float(center[0]),float(center[1]),float(center[2])),
		"span": float(asset.span), "users": [], "ready": true}


func appearance_signature(parts: Array[Dictionary]) -> String:
	# Content/material identity, not slot or cosmetic labels. Unknown geometry,
	# shader edits and non-exported settings fail closed to the original meshes.
	var data: Array = []
	for part in parts:
		var original: MeshInstance3D = part.source
		var path: String = str(part.source_path)
		if not source_hashes.has(path): source_hashes[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
		if str(source_hashes[path]).is_empty(): return "unsupported"
		# Imported subresource IDs can differ between machines; authored node names
		# plus the GLB content hash and local transform identify the same geometry.
		data.append([path,source_hashes[path],str(original.name),var_to_str(part.transform)])
		for material in part.materials:
			if not material is ShaderMaterial: return "unsupported"
			data.append(material.shader.code.sha256_text())
			var values: Array[String] = []
			for uniform in material.shader.get_shader_uniform_list():
				var value: Variant = material.get_shader_parameter(uniform.name)
				if value is GradientTexture1D:
					value = [value.width,value.gradient.offsets,value.gradient.colors,value.gradient.interpolation_mode]
				elif value is Resource:
					return "unsupported"
				values.append(str(uniform.name)+"="+var_to_str(value))
			values.sort()
			data.append(values)
	return var_to_str(data).sha256_text()


func _collect(root: Node3D, node: Node, relative: Transform3D, parts: Array[Dictionary]) -> bool:
	# Appearance ornaments include independently rotating rings. Keep them live.
	if node != root and (node.name == &"Appearance" or node.has_meta("body_bake_proxy")): return true
	if node is AnimationPlayer or node is AnimationTree or node is Skeleton3D: return false
	var transform := relative
	if node != root and node is Node3D:
		if node.top_level: return false
		transform = relative * node.transform
	if node is MeshInstance3D:
		var original := node as MeshInstance3D
		if original.mesh == null or original.skin != null: return false
		if original.mesh is ArrayMesh and (original.mesh as ArrayMesh).get_blend_shape_count() > 0: return false
		var materials: Array[Material] = []
		for surface in original.mesh.get_surface_count():
			var material := original.get_active_material(surface)
			if material == null: return false
			materials.append(material)
		parts.append({"source": original, "source_path": root.scene_file_path, "transform": transform, "materials": materials, "visible": original.visible})
	elif node is VisualInstance3D:
		return false
	for child in node.get_children():
		if not _collect(root, child, transform, parts): return false
	return true


func _new_bake_viewport() -> SubViewport:
	var bake := SubViewport.new()
	bake.name = "BodyBake"
	bake.size = Vector2i(BAKE_SIZE, BAKE_SIZE)
	bake.own_world_3d = true
	bake.transparent_bg = true
	bake.msaa_3d = Viewport.MSAA_4X
	bake.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(bake)
	return bake


func _create_texture(parts: Array[Dictionary]) -> Dictionary:
	var bake := _new_bake_viewport()
	var scene := Node3D.new()
	bake.add_child(scene)
	var bounds := AABB()
	var first := true
	for part in parts:
		var original: MeshInstance3D = part.source
		var copy := MeshInstance3D.new()
		copy.mesh = original.mesh
		copy.transform = part.transform
		copy.visible = part.visible
		copy.cast_shadow = original.cast_shadow
		for surface in part.materials.size(): copy.set_surface_override_material(surface, part.materials[surface])
		scene.add_child(copy)
		var transformed: AABB = part.transform * original.get_aabb()
		bounds = transformed if first else bounds.merge(transformed)
		first = false
	for child in source_world.get_children():
		if child is WorldEnvironment or child is DirectionalLight3D:
			scene.add_child(child.duplicate())
	var center := bounds.get_center()
	var span := maxf(bounds.size.x, bounds.size.z) * 1.08
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = maxf(span, 0.1)
	camera.near = 0.1
	camera.far = 110.0
	camera.position = Vector3(center.x, 60.0, center.z)
	camera.rotation_degrees.x = -90.0
	scene.add_child(camera)
	var material := ShaderMaterial.new()
	material.shader = BODY_SHADER
	material.set_shader_parameter("body_texture", bake.get_texture())
	# The image has no volumetric depth. Put its depth proxy at the body bottom
	# so it cannot cover live turret bases mounted within the original hull.
	center.y = bounds.position.y
	return {"viewport": bake, "scene": scene, "material": material, "center": center,
		"span": camera.size, "users": [], "ready": false}


func invalidate_materials() -> void:
	if not export_mode:
		for id in records.keys():
			var record: Dictionary = records[id]
			attach(record.root,record.request,true)
		return
	# Source and bake copies share their appearance materials. Render one new
	# snapshot after parameter writes; never tie this to pose or logical ticks.
	for key in textures:
		var entry: Dictionary = textures[key]
		if not is_instance_valid(entry.viewport):
			entry.viewport = _new_bake_viewport()
			entry.viewport.add_child(entry.scene)
		else:
			entry.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		if not pending.has(str(key)): pending.append(str(key))
	if not pending.is_empty(): _schedule_finish()


func _schedule_finish() -> void:
	if finish_connected: return
	finish_connected = true
	RenderingServer.frame_post_draw.connect(_finish, CONNECT_ONE_SHOT)


func _finish() -> void:
	finish_connected = false
	for key in pending:
		if not textures.has(key): continue
		var entry: Dictionary = textures[key]
		entry.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		# One readback/upload per new appearance, never per pose/frame. The frozen
		# asset then owns an ordinary texture, allowing MSAA/depth/RT buffers to die.
		var pixels: Image = entry.viewport.get_texture().get_image()
		entry.ready = pixels != null and not pixels.is_empty()
		if entry.ready:
			entry.material.set_shader_parameter("body_texture",ImageTexture.create_from_image(pixels))
		entry.viewport.remove_child(entry.scene)
		entry.viewport.queue_free()
		entry.viewport = null
		for id in entry.users:
			if not records.has(id): continue
			if entry.ready:
				_activate(records[id])
			else:
				_restore(records[id])
	pending.clear()
	request_shadow_sync()


func _activate(record: Dictionary) -> void:
	if not is_instance_valid(record.plane): return
	var scale: Vector3 = record.root.global_transform.basis.get_scale().abs()
	var footprint: float = float(textures[record.key].span) * maxf(scale.x,scale.z) * pixels_per_world
	if footprint > BAKE_SIZE:
		_restore(record)
		return
	if record.active: return
	for part in record.parts:
		if is_instance_valid(part.source) and part.source.visible: part.source.visible = false
	if not record.plane.visible: record.plane.visible = true
	record.active = true


func guard_resolution(pixel_density: float) -> void:
	# Large windows/closeups fall back to live geometry rather than magnifying
	# the fixed asset past its native resolution. Does not change RT dimensions.
	pixels_per_world = pixel_density
	for record in records.values():
		if textures.has(record.key) and textures[record.key].ready: _activate(record)
	request_shadow_sync()


func request_shadow_sync() -> void:
	if shadow_sync_pending or not is_inside_tree(): return
	shadow_sync_pending = true
	# Pose, visibility, loadout and appearance can change together. Decide after
	# that batch, rather than toggling a shadow map for each intermediate body.
	_sync_shadow_policy.call_deferred()


func _sync_shadow_policy() -> void:
	shadow_sync_pending = false
	if not is_instance_valid(source_world) or not is_inside_tree(): return
	var light := source_world.get_node_or_null("KeyLight") as DirectionalLight3D
	if light == null: return
	var all_offline := not export_mode
	var has_visible_body := false
	for id in body_roots:
		var root: Node3D = body_roots[id]
		if not is_instance_valid(root) or not root.is_visible_in_tree(): continue
		has_visible_body = true
		# Missing catalog/unsupported geometry must count as live, not disappear
		# from the decision. Resolution fallback sets active=false before this.
		if not records.has(id) or not records[id].active:
			all_offline = false
			break
		var record: Dictionary = records[id]
		if not is_instance_valid(record.plane) or not record.plane.visible or not textures.has(record.key) or not textures[record.key].ready:
			all_offline = false
			break
	var needs_shadows := not (has_visible_body and all_offline)
	# Baked self-shadow remains in the texture. This intentionally omits live
	# turret/ornament self-projection only while every visible body is offline.
	if light.shadow_enabled != needs_shadows: light.shadow_enabled = needs_shadows


func _release_root(id: int) -> void:
	body_roots.erase(id)
	request_shadow_sync()
	if not records.has(id): return
	var record: Dictionary = records[id]
	_restore(record)
	if is_instance_valid(record.plane): record.plane.queue_free()
	if textures.has(record.key):
		var entry: Dictionary = textures[record.key]
		entry.users.erase(id)
		if entry.users.is_empty():
			if is_instance_valid(entry.viewport): entry.viewport.queue_free()
			elif is_instance_valid(entry.scene): entry.scene.free()
			textures.erase(record.key)
	records.erase(id)


func _restore(record: Dictionary) -> void:
	if not record.active: return
	for part in record.parts:
		if is_instance_valid(part.source) and part.source.visible != part.visible: part.source.visible = part.visible
	if is_instance_valid(record.plane) and record.plane.visible: record.plane.visible = false
	record.active = false


func _exit_tree() -> void:
	if RenderingServer.frame_post_draw.is_connected(_finish): RenderingServer.frame_post_draw.disconnect(_finish)
	# Cached bake scenes are detached between changes and need explicit release.
	for id in records.keys(): _release_root(int(id))
	body_roots.clear()
	pending.clear()
	finish_connected = false
	shadow_sync_pending = false
