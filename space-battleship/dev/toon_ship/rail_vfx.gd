extends RefCounted
## Presentation only. A brief dark-red discharge leaves cyan laser packets readable.
const ELECTRIC := Color("9e2438")
const HOT := Color("d54b58")
var charge_radius := 28.0
var trail_length := 138.0
var trail_width := 28.0
var flash_seconds := 0.09
var impact_seconds := 0.16
var impact_radius := 32.0
var penetration_length := 80.0
func configure(db) -> void:
	for key in ["charge_radius","trail_length","trail_width","flash_seconds","impact_seconds","impact_radius","penetration_length"]:
		set(key,db.weapon_motion_value("rail_"+key,float(get(key))))
func charge(surface:CanvasItem,point:Vector2,direction:Vector2,amount:float,_clock:float)->void:
	if amount<=0:return
	var side:=direction.orthogonal()
	# Small rail contacts fill during the existing charge window; no energy sphere.
	for index in 3:
		var lit:=clampf(amount*3.0-float(index),0.0,1.0)
		var center:=point-direction*charge_radius*(0.9-float(index)*0.28)
		surface.draw_line(center-side*charge_radius*0.17,center+side*charge_radius*0.17,Color(ELECTRIC,lit*0.9),maxf(1.0,trail_width*0.055),true)
func flight(_surface:CanvasItem,_point:Vector2,_direction:Vector2,_clock:float,_origin:Vector2)->void:
	# The authoritative projectile still travels and hits normally. A launch
	# snapshot draws an independent discharge instead of a travelling packet.
	pass
func flash(surface:CanvasItem,point:Vector2,direction:Vector2,age:float,budget:float)->void:
	var lifetime:=minf(flash_seconds,0.045)
	if age<0 or age>=lifetime:return
	var fade:=1.0-age/lifetime
	surface.draw_line(point-direction*4.0,point+direction*14.0,Color(HOT,fade*budget),maxf(1.0,trail_width*0.065),true)
func impact(surface:CanvasItem,point:Vector2,direction:Vector2,age:float,_critical:bool,budget:float)->void:
	var lifetime:=minf(impact_seconds,0.05)
	if age<0 or age>=lifetime:return
	var fade:=1.0-age/lifetime
	var side:=direction.orthogonal()
	for sign in [-1.0,1.0]:
		var tip:Vector2=point+direction*impact_radius*0.2+side*sign*impact_radius*0.22
		surface.draw_line(point,tip,Color(ELECTRIC,fade*budget),maxf(0.8,trail_width*0.035),true)
func afterglow_seconds() -> float:
	return maxf(flash_seconds,impact_seconds*3.5)

func exit_point(origin:Vector2,direction:Vector2,bounds:Vector2)->Vector2:
	var reach := INF
	if direction.x>0.0001:reach=minf(reach,(bounds.x-origin.x)/direction.x)
	elif direction.x<-0.0001:reach=minf(reach,-origin.x/direction.x)
	if direction.y>0.0001:reach=minf(reach,(bounds.y-origin.y)/direction.y)
	elif direction.y<-0.0001:reach=minf(reach,-origin.y/direction.y)
	if not is_finite(reach):return origin
	# Extend beyond the actual clipping rectangle, including the beam half-width.
	return origin+direction*(maxf(0.0,reach)+trail_width)

func penetration(surface:CanvasItem,origin:Vector2,contact:Vector2,_direction:Vector2,age:float,budget:float,bounds:Vector2)->void:
	var lifetime := afterglow_seconds()
	if age<0 or age>=lifetime:return
	var direction := (contact-origin).normalized()
	var end := exit_point(origin,direction,bounds)
	var side := direction.orthogonal()
	var main_lifetime := minf(flash_seconds,0.09)
	if age<main_lifetime:
		var fade := pow(1.0-age/main_lifetime,0.65)
		# A wide straight discharge crosses the hull and leaves the clipping area.
		# Its lifetime is independent of the authoritative travelling projectile.
		surface.draw_line(origin,end,Color(ELECTRIC,fade*budget),maxf(12.0,trail_width),true)
		surface.draw_line(origin,end,Color(HOT,fade*budget*0.85),maxf(4.0,trail_width*0.32),true)
	var kink := minf(trail_width*0.25,origin.distance_to(end)*0.015)
	var points := PackedVector2Array([origin,
		origin.lerp(end,0.25)+side*kink*0.35,
		origin.lerp(end,0.36)-side*kink,
		origin.lerp(end,0.38)+side*kink*0.55,
		origin.lerp(end,0.64)-side*kink*0.25,
		origin.lerp(end,0.67)+side*kink*0.8,
		origin.lerp(end,0.69)-side*kink*0.5,end])
	var fade := pow(1.0-age/lifetime,1.4)
	surface.draw_line(origin,end,Color(ELECTRIC,fade*budget*0.38),maxf(2.0,trail_width*0.22),true)
	surface.draw_polyline(points,Color(HOT,fade*budget*0.85),maxf(1.5,trail_width*0.09),true)
