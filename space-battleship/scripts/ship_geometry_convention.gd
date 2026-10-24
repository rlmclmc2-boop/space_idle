extends RefCounted
## Session assembly supplies data; these calculations do not read scenes or UI.

static func formation_positions(slots: Array, definitions: Dictionary, rules: Dictionary, explicit = null) -> Dictionary:
	var result: Dictionary = {}
	if explicit != null:
		for slot in slots.size():
			if slots[slot] != null:
				result[slot] = Vector2(float(explicit[slot][0]), float(explicit[slot][1]))
		return result
	var members: Array = []
	for slot in slots.size():
		if slots[slot] != null:
			var id: int = int(slots[slot])
			members.append({"slot": slot, "id": id, "size": int(definitions[id].size)})
	members.sort_custom(func(a, b):
		if a.size != b.size: return a.size > b.size
		if a.id != b.id: return a.id < b.id
		return a.slot < b.slot)
	var columns: int = int(rules.formation_columns)
	var rows: int = ceili(float(members.size()) / columns)
	var row_positions: Array = JSON.parse_string(str(rules.formation_row_y))
	var cursor: int = 0
	for row in rows:
		var count: int = mini(columns, ceili(float(members.size() - cursor) / (rows - row)))
		var berths: Array = range(count)
		berths.sort_custom(func(a, b):
			var left: float = absf(float(a) - (count - 1) * 0.5)
			var right: float = absf(float(b) - (count - 1) * 0.5)
			return left < right if left != right else a < b)
		var y: float = float(rules.formation_single_row_y) if rows == 1 else float(row_positions[row])
		var spacing: float = minf(float(rules.formation_max_spacing), float(rules.formation_span) / maxi(1, count - 1))
		for berth in berths:
			result[int(members[cursor].slot)] = Vector2(float(rules.formation_center_x) + (float(berth) - (count - 1) * 0.5) * spacing, y)
			cursor += 1
	return result

static func normalized_hull(image: Image) -> PackedVector2Array:
	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(image, 0.0)
	var points := PackedVector2Array()
	var size := Vector2(image.get_size())
	for polygon in bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO, image.get_size()), 0.0):
		for point in polygon:
			points.append(point / size - Vector2(0.5, 0.5))
	# One convex authored silhouette, shared unchanged with the display consumer.
	var hull: PackedVector2Array = Geometry2D.convex_hull(points)
	if hull.size() > 1 and hull[0] == hull[hull.size() - 1]:
		hull.resize(hull.size() - 1)
	return hull

static func transform_hull(normalized: PackedVector2Array, origin: Vector2, dimensions: Vector2, angle: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in normalized:
		result.append(origin + (point * dimensions).rotated(angle))
	return result

static func mount_position(art: Dictionary, slot: int, origin: Vector2, dimensions: Vector2, angle: float = 0.0) -> Vector2:
	var index: int = int(art.slot_map[slot])
	var point: Array = art.hardpoints[index].pos
	return origin + (Vector2(float(point[0]), float(point[1])) * dimensions).rotated(angle)

static func enemy_width(size: int, final: bool, members: int, base_art_scale: float, canvas_height: float, visual_scale: float, variance: float, rules: Dictionary) -> float:
	var tier: float = float(rules.enemy_final_tier) if final else float(rules.enemy_large_tier) if size >= 4 else 1.0 + (size - 1) * float(rules.enemy_size_growth)
	var limit: float = float(rules.enemy_final_width_limit) if final else float(rules.enemy_large_width_limit) if size >= 4 else float(rules.enemy_ordinary_width_limit)
	var scale_range: Array = JSON.parse_string(str(rules.enemy_scale_variance))
	var base: float = minf(limit / (float(rules.enemy_depth_scale_max) * float(scale_range[1])), canvas_height * float(rules.enemy_canvas_span_multiplier) * base_art_scale * float(rules.enemy_base_scale) * tier)
	var width: float = base * visual_scale * variance
	return minf(width, float(rules.enemy_dense_width_cap)) if members >= 4 else width

## Target anchors are the XZ bounds centre of the authored body. Apply this
## transform to the complete assembly, including its imported socket chains.
static func body_center(row:Dictionary)->Vector3:
	var low:Array=row.godot_aabb_min;var high:Array=row.godot_aabb_max
	return Vector3((float(low[0])+float(high[0]))*0.5,0.0,(float(low[2])+float(high[2]))*0.5)

static func centered_transform(basis:Basis,anchor:Vector3,row:Dictionary)->Transform3D:
	return Transform3D(basis,anchor-basis*body_center(row))

# The Frigate's sole authored mount sits behind its bow. Shift the entire
# weapon assembly (mesh, pivot and real muzzle) forward together so the wide
# cannon discharge leaves the hull instead of starting inside it.
static func weapon_mount_offset(ship_key:String,slot:int)->Vector3:
	return Vector3(0,0,-1.0) if ship_key=="Frigate" and slot==0 else Vector3.ZERO

# Shared pure fit for the approved flat hull. The live scene and the logical
# battle pose must derive the same mount position after display-only fitting.
static func approved_body_fit(opaque:Rect2,mesh_size:Vector2,base_position:Vector3,viewport_size:Vector2,rendered_height:float,rendered_position:Vector2,model_span:float)->Dictionary:
	var ratio:=opaque.size.x/opaque.size.y
	var art_scale:=1.0
	if ratio>1.3:art_scale=clampf(viewport_size.x*0.15/(rendered_height*ratio),1.0,1.35)
	var safe:=Rect2(Vector2(12,12),viewport_size-Vector2(24,64))
	var body:=Vector2(ratio,1.0)*rendered_height*art_scale
	art_scale*=minf(1.0,minf(safe.size.x/body.x,safe.size.y/body.y))
	body=Vector2(ratio,1.0)*rendered_height*art_scale
	var center:=Vector2(clampf(rendered_position.x,safe.position.x+body.x*0.5,safe.end.x-body.x*0.5),clampf(rendered_position.y,safe.position.y+body.y*0.5,safe.end.y-body.y*0.5))
	var local_per_pixel:=model_span/rendered_height
	return {"scale":art_scale,"position":base_position+Vector3(center.x-rendered_position.x,0,center.y-rendered_position.y)*local_per_pixel,"mesh_size":mesh_size}

static func approved_mount_position(fit:Dictionary,point:Array)->Vector3:
	var mesh_size:Vector2=fit.mesh_size
	var scale:float=fit.scale
	return Vector3(fit.position)+Vector3(float(point[0])*mesh_size.x,0.08,float(point[1])*mesh_size.y)*scale
