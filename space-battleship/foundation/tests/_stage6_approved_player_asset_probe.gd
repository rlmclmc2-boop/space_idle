extends SceneTree
const Art = preload("res://scripts/approved_weapon_art.gd")
const PLAYERS := ["Frigate", "Destroyer", "Cruiser", "Battleship", "Heavy_Battleship"]
const HEIGHTS := [133.042, 151.470, 213.792, 242.216, 291.788]
func _initialize() -> void:
	call_deferred("_run")
func _check(condition: bool, reason: String) -> bool:
	if condition: return true
	printerr("APPROVED_PLAYER_ASSET_FAILED " + reason)
	quit(1)
	return false
func _run() -> void:
	var ships: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ship_weapon_visuals.json")).ships
	var weapons: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Art.MANIFEST_PATH)).weapons
	var reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art_sources/fleet-20261019/split-report.json")).hulls
	var checks: int = 0
	var maximum_error: float = 0.0
	for index in PLAYERS.size():
		var key: String = PLAYERS[index]
		var hull: Dictionary = ships[key]
		var texture: Texture2D = load(str(hull.texture))
		if not _check(FileAccess.get_sha256(str(hull.texture)) == str(reference[key].sha256), "approved hull pixels " + key): return
		if not _check(not hull.has("geometry_texture") and hull.hardpoints.size() == index + 1 and hull.slot_map.size() == index + 1, "approved mount budget or old geometry reference " + key): return
		var image: Image = texture.get_image()
		for mount in hull.hardpoints:
			var pos := Vector2(float(mount.pos[0]), float(mount.pos[1]))
			var pixel := Vector2i((pos + Vector2(0.5, 0.5)) * Vector2(image.get_size()))
			if not _check(image.get_pixelv(pixel).a > 0.0, "mount outside visible hull " + key): return
			var seat: Vector2 = Vector2(286, 520) + pos * float(HEIGHTS[index])
			for weapon in weapons:
				var row: Dictionary = weapons[weapon]
				var gun: Texture2D = load(str(row.texture))
				if not _check(FileAccess.get_sha256(str(row.texture)) == str(row.sha256), "approved turret pixels " + str(weapon)): return
				for direction in [-PI * 0.5, -PI * 0.5 - PI / 3.0, -PI * 0.5 + PI / 3.0]:
					var pose: Dictionary = Art.player_pose(str(weapon), row, gun.get_size(), seat, direction, HEIGHTS[index], hull)
					if not _check(pose.ports.size() == (2 if weapon == "missile" else 1), "lost muzzle ordinal " + str(weapon)): return
					# Recreate the approved 2943101f PlaneMesh transform independently.
					var anchor := Vector2(float(row.anchor[0]), float(row.anchor[1]))
					var ppm := Vector2(float(row.pixels_per_model[0]), float(row.pixels_per_model[1]))
					var mesh_size: Vector2 = gun.get_size() / ppm
					var offset: Vector2 = (gun.get_size() * 0.5 - anchor) / ppm
					var enlarged: float = float(row.visual_scale)
					var plane := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * enlarged), Vector3(offset.x * enlarged, 0.12, offset.y * enlarged))
					var root_scale: float = HEIGHTS[index] / float(hull.model_span) * float(hull.weapon_scale)
					var assembly := Basis.from_euler(Vector3(0, -(direction + PI * 0.5), 0)).scaled(Vector3.ONE * root_scale)
					for ordinal in row.emission_pixels.size():
						var port: Array = row.emission_pixels[ordinal]
						var local := Vector3((float(port[0]) / gun.get_width() - 0.5) * mesh_size.x, 0, (float(port[1]) / gun.get_height() - 0.5) * mesh_size.y)
						var world: Vector3 = assembly * (plane * local)
						var expected: Vector2 = seat + Vector2(world.x, world.z)
						var error: float = expected.distance_to(pose.ports[ordinal])
						maximum_error = maxf(maximum_error, error)
						if not _check(error < 0.0001, "approved pivot/muzzle projection " + key + "/" + str(weapon)): return
					var source_aspect: float = gun.get_width() / float(gun.get_height())
					if not _check(absf(pose.dimensions.x / pose.dimensions.y - source_aspect) < 0.00001, "weapon aspect distorted"): return
					checks += 1
	print("APPROVED_PLAYER_FIVE_HULLS_STATIC_TURRET_PORTS_AND_SCALE_OK poses=", checks, " max_projection_error=", maximum_error)
	quit(0)
