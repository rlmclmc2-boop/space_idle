extends RefCounted
## Stable identity for the existing unshaded procedural ornament meshes.
static func collect(root: Node3D) -> Array[Dictionary]:
	var parts: Array[Dictionary] = []
	for mesh in root.find_children("*","MeshInstance3D",true,false):
		var orbit := root.get_node_or_null("UltimateOrbit")
		if orbit != null and orbit.is_ancestor_of(mesh):continue
		var transform := Transform3D.IDENTITY
		var current: Node3D = mesh
		while current != root:
			transform = current.transform*transform
			current = current.get_parent() as Node3D
		var materials: Array[Material] = []
		for surface in mesh.mesh.get_surface_count():materials.append(mesh.get_active_material(surface))
		parts.append({"source":mesh,"mesh":mesh.mesh,"transform":transform,"materials":materials})
	return parts

static func signature(parts: Array[Dictionary]) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	for part in parts:
		hash.update(var_to_bytes(part.transform))
		for surface in part.mesh.get_surface_count():
			var mat := part.materials[surface] as StandardMaterial3D
			if mat == null or mat.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED or mat.albedo_texture != null or mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:return "unsupported"
			hash.update(var_to_bytes(part.mesh.surface_get_arrays(surface)))
			hash.update(var_to_bytes([mat.albedo_color,mat.emission_enabled,mat.emission,mat.emission_energy_multiplier,mat.cull_mode]))
	return hash.finish().hex_encode()
