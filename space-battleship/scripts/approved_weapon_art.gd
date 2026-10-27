extends RefCounted
## Approved static turret projection, from the final 2943101f manifest.
## Source pixels face up; forward_angle uses ordinary 2D direction radians.
const MANIFEST_PATH := "res://assets/weapons/fleet_20261019/manifest.json"

static func pose(key: String, row: Dictionary, texture_size: Vector2, pivot: Vector2,
		forward_angle: float, model_pixels_per_unit: float, weapon_scale: float) -> Dictionary:
	var source_ppm := Vector2(float(row.pixels_per_model[0]), float(row.pixels_per_model[1]))
	var anchor := Vector2(float(row.anchor[0]), float(row.anchor[1]))
	var scale: Vector2 = Vector2.ONE / source_ppm * model_pixels_per_unit * weapon_scale * float(row.visual_scale)
	var rotation: float = forward_angle + PI * 0.5
	var local_ports := PackedVector2Array()
	var ports := PackedVector2Array()
	for pixel in row.emission_pixels:
		var local: Vector2 = (Vector2(float(pixel[0]), float(pixel[1])) - anchor) * scale
		local_ports.append(local)
		ports.append(pivot + local.rotated(rotation))
	return {"key": key, "pivot": pivot, "angle": rotation,
		"rect": Rect2(-anchor * scale, texture_size * scale), "dimensions": texture_size * scale,
		"local_ports": local_ports, "ports": ports, "muzzle": ports[0]}

static func player_pose(key: String, row: Dictionary, texture_size: Vector2, pivot: Vector2,
		forward_angle: float, rendered_height: float, hull: Dictionary) -> Dictionary:
	return pose(key, row, texture_size, pivot, forward_angle,
		rendered_height / float(hull.model_span), float(hull.weapon_scale))
