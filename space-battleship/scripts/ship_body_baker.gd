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


func attach(root: Node3D, key: String) -> void:
	var id := root.get_instance_id()
	if records.has(id) and records[id].key == key: return
	_release_root(id)
	var parts: Array[Dictionary] = []
	if not _collect(root, root, Transform3D.IDENTITY, parts) or parts.is_empty(): return
	if not textures.has(key):
		textures[key] = _create_texture(parts)
		pending.append(key)
		_schedule_finish()
	var entry: Dictionary = textures[key]
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
	records[id] = {"key": key, "parts": parts, "plane": plane, "root": root, "active": false}
	var release := _release_root.bind(id)
	if not root.tree_exiting.is_connected(release): root.tree_exiting.connect(release, CONNECT_ONE_SHOT)
	if entry.ready: _activate(records[id])


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
		parts.append({"source": original, "transform": transform, "materials": materials, "visible": original.visible})
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
	return {"viewport": bake, "scene": scene, "material": material, "center": center,
		"span": camera.size, "users": [], "ready": false}


func invalidate_materials() -> void:
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


func _release_root(id: int) -> void:
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
	pending.clear()
	finish_connected = false
