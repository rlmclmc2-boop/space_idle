extends RefCounted
## Separate actual body/protection, meter and caption footprints. An AABB is
## only a broad-phase filter; empty space between parts cannot reject a layout.
static func rectangle(rect:Rect2)->PackedVector2Array:
	return PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])

static func parts(scene,enemy:Dictionary,centre:Vector2,angle:float)->Array[Dictionary]:
	var width:float=scene.enemy_render_width(enemy)
	var packet:Dictionary=scene.enemy_recognition_geometry(enemy)
	var scale_value:float=scene.enemy_recognition_screen_scale()
	var shield:bool=float(enemy.max_shield)>0
	var hull_visible:bool=int(enemy.armourType) in [1,2]
	var repair:bool=shield and float(enemy.shieldRecovery)>0
	var typed_shield:bool=shield and int(enemy.shieldType) in [0,1,2]
	var outline:=PackedVector2Array()
	if hull_visible or repair or typed_shield:outline=packet.inner
	# Include the full- and empty-shield layers, since shield settlement must not
	# create a new collision with an adjacent ship's meters or caption.
	if typed_shield and hull_visible and int(enemy.armourType)!=int(enemy.shieldType):outline=packet.outer
	if typed_shield and int(enemy.shieldType)==1 and int(enemy.size)>=4:
		outline=packet.front if hull_visible and int(enemy.armourType)!=int(enemy.shieldType) else packet.single_front
	var body:PackedVector2Array=outline if not outline.is_empty() else Geometry2D.convex_hull(packet.audit_points)
	var world:=PackedVector2Array()
	for point in body:world.append(centre+Vector2(point).rotated(PI+angle))
	var result:Array[Dictionary]=[]
	var padding:=2.0/scale_value
	var expanded:Array[PackedVector2Array]=Geometry2D.offset_polygon(world,padding)
	for polygon in expanded:result.append({"kind":"body/protection","polygon":polygon})
	assert(scene.has_method("enemy_status_layout"),"Actual battlefield status layout provider is required")
	var layout:Dictionary=scene.enemy_status_layout(enemy,centre,width,angle,outline)
	result.append({"kind":"health","polygon":rectangle(layout.health.grow(padding))})
	if shield:result.append({"kind":"shield","polygon":rectangle(layout.shield.grow(padding))})
	if scene.game.is_boss_encounter():
		result.append({"kind":"boss caption","polygon":rectangle(layout.caption_bounds.grow(padding))})
	if not outline.is_empty() and shield:
		var empty_outline:PackedVector2Array=packet.inner if hull_visible or repair else PackedVector2Array()
		var empty_layout:Dictionary=scene.enemy_status_layout(enemy,centre,width,angle,empty_outline)
		result.append({"kind":"health after shield","polygon":rectangle(empty_layout.health.grow(padding))})
		result.append({"kind":"shield after shield","polygon":rectangle(empty_layout.shield.grow(padding))})
		if scene.game.is_boss_encounter():result.append({"kind":"caption after shield","polygon":rectangle(empty_layout.caption_bounds.grow(padding))})
	return result

static func swept_parts(scene,enemy:Dictionary,centre:Vector2)->Array[Dictionary]:
	var limit:=deg_to_rad(float(scene.battle_visual.enemy_rotation_variance)+float(scene.battle_visual.enemy_idle_rotation))
	var points_by_kind:Dictionary={}
	for angle in [-limit,0.0,limit,scene.enemy_render_angle(enemy)]:
		for part in parts(scene,enemy,centre,float(angle)):
			if not points_by_kind.has(part.kind):points_by_kind[part.kind]=PackedVector2Array()
			points_by_kind[part.kind].append_array(part.polygon)
	var result:Array[Dictionary]=[]
	for kind in points_by_kind:result.append({"kind":kind,"polygon":Geometry2D.convex_hull(points_by_kind[kind])})
	return result

static func overlap(a:PackedVector2Array,b:PackedVector2Array)->bool:
	var ra:=Rect2(a[0],Vector2.ZERO)
	var rb:=Rect2(b[0],Vector2.ZERO)
	for p in a:ra=ra.expand(p)
	for p in b:rb=rb.expand(p)
	if not ra.intersects(rb):return false
	return not Geometry2D.intersect_polygons(a,b).is_empty()
