extends RefCounted
## Presentation only. Never settles shields, selects targets, or changes combat entities.
const GEOMETRY := preload("res://scripts/enemy_protection_geometry.gd")
const N := preload("res://scripts/growth_number.gd")
const PHYSICAL := Color("ffaf61")
const ENERGY := Color("64b5ff")
var hull_profiles: Dictionary = {}
var hull_scans := 0
var envelope_builds := 0

func hull_profile(texture: Texture2D) -> PackedVector2Array:
	var id := texture.get_instance_id()
	if not hull_profiles.has(id):
		hull_profiles[id]=Geometry2D.convex_hull(GEOMETRY.alpha_boundary(texture.get_image()))
		hull_scans+=1
	return hull_profiles[id]

func descriptors(components: Array) -> Array:
	var mounts: Array = []
	for component in components:
		var point: Dictionary=component.hardpoint
		var weapon_class := str(component.profile.get("visual_class",""))
		var shape := "physical" if component.damage_type==2 and weapon_class=="gun" else "energy" if component.damage_type==1 and weapon_class=="energy" else "legacy"
		var role: String=component.mode()
		var limit := deg_to_rad(float(point.get("rotation_limit",0)))*(1.0 if role=="main" else 0.2 if role=="secondary" else 0.0)
		mounts.append({"pos":Vector2(float(point.pos[0]),float(point.pos[1])*2.0),"class_scale":float({"small":0.7,"medium":0.9,"large":1.1}.get(str(point.get("visual_size_class","small")),0.7)),"base":-PI/2+deg_to_rad(float(point.get("base_rotation",0))),"limit":limit,"muzzle":Vector2(component.profile.get("muzzle",[[0.22,0]])[0][0],component.profile.get("muzzle",[[0.22,0]])[0][1]),"shape":shape,"mode":role})
	return mounts

func mount_corners(mount: Dictionary, width: float, min_width: float) -> PackedVector2Array:
	var old_width := width*0.42*float(mount.class_scale)
	var port := Vector2(mount.muzzle)*old_width
	var points := PackedVector2Array()
	if mount.shape=="legacy":
		var half := Vector2(0.26,0.21) if mount.mode=="bay" else Vector2(0.22,0.145)
		for p in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:points.append(p*half*old_width)
		var radius := maxf(0.65,old_width*0.06)
		for p in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:points.append(port+p*radius)
	else:
		var nominal := maxf(min_width,old_width)
		var physical: bool=mount.shape=="physical"
		var face := 0.64 if physical else 0.45
		for p in GEOMETRY.weapon_bounds(nominal,physical):points.append(port+Vector2(p.y-face*nominal,-p.x))
	return points

func swept_mount(points: PackedVector2Array, mount: Dictionary, width: float, min_width: float) -> void:
	var origin := Vector2(mount.pos)*width
	var limit := float(mount.limit)
	var base := float(mount.base)
	var normals := [Vector2(1,0),Vector2(-1,0),Vector2(0.8,1),Vector2(-0.8,1),Vector2(0.8,-1),Vector2(-0.8,-1)]
	for corner in mount_corners(mount,width,min_width):
		for aim in [-limit,limit]:points.append(origin+corner.rotated(base+aim))
		# Include exact support extrema of each corner's allowed arc for all six edges.
		for normal in normals:
			var aim := wrapf(Vector2(normal).angle()-corner.angle()-base,-PI,PI)
			if aim>=-limit and aim<=limit:points.append(origin+corner.rotated(base+aim))

func geometry(texture: Texture2D, width: float, mounts: Array, repair: bool, cache: Dictionary, scale_value: float) -> Dictionary:
	var scale_safe := maxf(0.1,scale_value)
	var bucket := ceili(width*scale_safe/2.0)
	var low := maxf(0.1,float(bucket-1)*2.0/scale_safe)
	var high := float(bucket)*2.0/scale_safe
	var gap := float(ProjectSettings.get_setting("visuals/enemy_protection_gap_pixels",2.0))/scale_safe
	var layer_gap := float(ProjectSettings.get_setting("visuals/enemy_protection_layer_gap_pixels",2.5))/scale_safe
	var signature := [texture.get_instance_id(),bucket,scale_safe,gap,layer_gap,repair,mounts]
	if cache.get("recognition_signature",[])==signature:return cache.recognition_geometry
	var profile := hull_profile(texture)
	var min_width := 15.0/scale_safe
	var points := PackedVector2Array()
	var widths: Array[float]=[low,high]
	for mount in mounts:
		var crossing := min_width/(0.42*float(mount.class_scale))
		if crossing>low and crossing<high and not widths.has(crossing):widths.append(crossing)
	for sample_width in widths:
		for point in profile:points.append(point*sample_width)
		for mount in mounts:swept_mount(points,mount,sample_width,min_width)
		if repair:
			for i in 3:
				var a := -PI/2+float(i)*TAU/3
				var center := Vector2(cos(a)*sample_width*0.45,sin(a)*sample_width*0.55)
				for p in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:points.append(center+p*sample_width*0.075)
	var hull_stroke := maxf(1.1/scale_safe,high*0.020)
	var shield_stroke := maxf(1.3/scale_safe,high*0.026)
	var inner := GEOMETRY.fit(points,gap+shield_stroke*0.5+0.5/scale_safe)
	var outer := GEOMETRY.fit(inner,layer_gap+shield_stroke+0.5/scale_safe)
	var front := GEOMETRY.fit(outer,layer_gap+shield_stroke+0.5/scale_safe)
	var single_front := GEOMETRY.fit(inner,layer_gap+shield_stroke+0.5/scale_safe)
	var result := {"inner":inner,"outer":outer,"front":front,"single_front":single_front,"hull_stroke":hull_stroke,"shield_stroke":shield_stroke,"scale":scale_safe,"audit_points":points}
	cache.recognition_signature=signature.duplicate(true)
	cache.recognition_geometry=result
	envelope_builds+=1
	return result

func state(enemy: Dictionary, shield_clock: float, paused: bool, cache: Dictionary) -> Dictionary:
	var alive := N.compare(enemy.get("hp",0),0)>0
	var capacity = enemy.get("max_shield",0)
	var amount = enemy.get("shield",0)
	var has_shield := N.compare(capacity,0)>0
	var active := alive and has_shield and N.compare(amount,0)>0
	var repair := has_shield and float(enemy.get("shieldRecovery",0))>0
	var fraction := clampf(N.ratio(amount,capacity),0,1) if active else 0.0
	var ready := shield_clock>=float(enemy.get("shield_hit_at",shield_clock))+float(enemy.get("shieldDelay",0))
	var eligible := active and repair and fraction<1 and ready
	var recovering := bool(cache.get("recognition_recovering",false))
	if not eligible:recovering=false
	elif shield_clock>float(cache.get("recognition_shield_clock",shield_clock)):
		recovering=N.compare(amount,cache.get("recognition_shield_amount",amount))>0
	if not cache.has("recognition_shield_clock") or shield_clock!=float(cache.recognition_shield_clock) or N.compare(amount,cache.recognition_shield_amount)!=0 or recovering!=bool(cache.recognition_recovering):
		cache.recognition_shield_clock=shield_clock
		cache.recognition_shield_amount=amount.duplicate(true) if amount is Dictionary else amount
		cache.recognition_recovering=recovering
	return {"alive":alive,"active":active,"repair":repair,"fraction":fraction,"recovering":recovering and not paused,"show_hull":not active or int(enemy.get("armourType",0))!=int(enemy.get("shieldType",0))}

func closed(surface: CanvasItem, outline: PackedVector2Array, color: Color, stroke: float) -> void:
	var path := outline.duplicate()
	path.append(path[0])
	surface.draw_polyline(path,color,stroke,true)

func draw_protection(surface: CanvasItem, enemy: Dictionary, width: float, packet: Dictionary, status: Dictionary, shield_clock: float) -> PackedVector2Array:
	if not status.alive:return PackedVector2Array()
	var hull_type := int(enemy.get("armourType",0))
	var shield_type := int(enemy.get("shieldType",0))
	var hull_visible: bool=status.show_hull and hull_type in [1,2]
	if not hull_visible and not status.repair and not (status.active and shield_type in [1,2]):return PackedVector2Array()
	var outline: PackedVector2Array=packet.inner
	if hull_visible:closed(surface,outline,Color(PHYSICAL if hull_type==2 else ENERGY,0.8),packet.hull_stroke)
	if status.active and shield_type in [1,2]:
		outline=packet.outer if hull_visible else packet.inner
		var color := PHYSICAL if shield_type==2 else ENERGY
		if status.repair:
			for i in 6:
				var a := outline[(i+2)%6]
				var b := outline[(i+3)%6]
				surface.draw_line(a.lerp(b,0.08),a.lerp(b,0.92),Color(color,0.18),packet.shield_stroke,true)
				var fill := clampf(float(status.fraction)*6-float(i),0,1)
				if fill>0:surface.draw_line(a.lerp(b,0.08),a.lerp(b,0.08+0.84*fill),Color(color,0.9),packet.shield_stroke,true)
		else:closed(surface,outline,Color(color,0.65),packet.shield_stroke)
		if shield_type==1 and int(enemy.size)>=4:
			var front: PackedVector2Array=packet.front if hull_visible else packet.single_front
			surface.draw_polyline(PackedVector2Array([front[5],front[0],front[1]]),Color(ENERGY,0.85),packet.shield_stroke,true)
			outline=front
	if status.repair:
		var color := PHYSICAL if shield_type==2 else ENERGY
		for i in 3:
			var a := -PI/2+float(i)*TAU/3
			var center := Vector2(cos(a)*width*0.45,sin(a)*width*0.55)
			surface.draw_rect(Rect2(center-Vector2.ONE*width*0.075,Vector2.ONE*width*0.15),Color("303c45"))
			surface.draw_rect(Rect2(center-Vector2.ONE*width*0.05,Vector2.ONE*width*0.10),Color(color,0.85 if status.active else 0.22),false,maxf(1.0/packet.scale,width*0.02))
			if status.recovering:
				var toward := -center.normalized()
				var pulse := fposmod(shield_clock*1.4+float(i)*0.33,1.0)
				var p := center+toward*width*(0.12+0.17*pulse)
				var cross := toward.orthogonal()*width*0.035
				surface.draw_polyline(PackedVector2Array([p-toward*width*0.045+cross,p,p-toward*width*0.045-cross]),Color(color,1.0-pulse*0.55),maxf(1.0/packet.scale,width*0.025),true)
	return outline

func draw_weapon(surface: CanvasItem, pos: Vector2, pose: Dictionary, damage_type: int, scale_value: float) -> void:
	var physical := damage_type==2
	var w := maxf(15.0/maxf(0.1,scale_value),float(pose.width))
	var face := 0.64 if physical else 0.45
	var shift := Vector2(pose.port)-Vector2(face*w,0)
	surface.draw_set_transform(pos+Vector2(pose.origin)+shift.rotated(pose.angle),float(pose.angle)-PI/2)
	surface.draw_rect(Rect2(-w*0.24,-w*0.22,w*0.48,w*0.42),Color("36424b"))
	if physical:
		surface.draw_rect(Rect2(-w*0.16,-w*0.15,w*0.32,w*0.84),Color("ac886a"))
		surface.draw_rect(Rect2(-w*0.23,w*0.48,w*0.46,w*0.25),Color("6e594a"))
		surface.draw_rect(Rect2(-w*0.15,w*0.57,w*0.30,w*0.14),Color("080d13"))
	else:
		for side in [-1,1]:
			var fork := PackedVector2Array([Vector2(side*w*0.17,-w*0.18),Vector2(side*w*0.60,-w*0.08),Vector2(side*w*0.60,w*0.45),Vector2(side*w*0.41,w*0.45),Vector2(side*w*0.41,w*0.07),Vector2(side*w*0.17,0)])
			surface.draw_colored_polygon(fork,Color("aabfc6"))
			surface.draw_line(Vector2(side*w*0.49,w*0.20),Vector2(side*w*0.49,w*0.44),ENERGY,maxf(1,w*0.10),true)
		surface.draw_rect(Rect2(-w*0.13,w*0.02,w*0.26,w*0.16),ENERGY)
	surface.draw_set_transform(Vector2.ZERO)

func draw_projectile(surface: CanvasItem, pos: Vector2, angle: float, damage_type: int, core: bool) -> void:
	var heading := Vector2.from_angle(angle)
	if not core:
		surface.draw_line(pos-heading*15,pos,Color(PHYSICAL if damage_type==2 else ENERGY,0.16),1.0,true)
	elif damage_type==2:
		surface.draw_line(pos-heading*9,pos-heading*1,Color(PHYSICAL,0.5),1.5,true)
		surface.draw_line(pos,pos+heading*8,PHYSICAL,3.5,true)
		surface.draw_line(pos+heading*5,pos+heading*8,Color("ffe5bf"),2.0,true)
	else:
		surface.draw_line(pos-heading*9,pos+heading*9,ENERGY,2.0,true)
		surface.draw_line(pos-heading*7,pos+heading*7,Color("d8f3ff"),1.0,true)

func draw_contact(surface: CanvasItem, pos: Vector2, axis: Vector2, age: float, damage_type: int, launch: bool) -> void:
	var fade := clampf(1.0-age/0.12,0,1)
	var physical := damage_type==2
	var color := Color(PHYSICAL if physical else ENERGY,fade)
	var side := axis.orthogonal()
	if launch:
		if physical:surface.draw_line(pos-axis*2,pos+axis*4,color,2.5,true)
		else:
			for sign_value in [-1,1]:surface.draw_line(pos+side*sign_value*2,pos+axis*4,color,1.0,true)
		return
	var radius := 3.0+4.0*(1.0-fade)
	if physical:surface.draw_arc(pos,radius,0,TAU,12,color,1.2,true)
	else:
		surface.draw_line(pos-side*radius,pos+side*radius,color,1.2,true)
		surface.draw_line(pos-axis*radius*0.6,pos+axis*radius*0.6,color,1.0,true)
