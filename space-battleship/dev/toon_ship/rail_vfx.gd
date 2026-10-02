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
	# The authoritative projectile still travels and hits normally. Its contact
	# draws the complete discharge once, instead of a visible travelling packet.
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
func penetration(surface:CanvasItem,origin:Vector2,contact:Vector2,direction:Vector2,age:float,budget:float,bounds:Vector2)->void:
	var lifetime:=minf(impact_seconds,0.075)
	if age<0 or age>=lifetime:return
	var reach:=penetration_length
	if direction.x>0.0001:reach=minf(reach,(bounds.x-contact.x)/direction.x)
	elif direction.x<-0.0001:reach=minf(reach,-contact.x/direction.x)
	if direction.y>0.0001:reach=minf(reach,(bounds.y-contact.y)/direction.y)
	elif direction.y<-0.0001:reach=minf(reach,(36.0-contact.y)/direction.y)
	var end:=contact+direction*maxf(0.0,reach)
	var side:=(end-origin).normalized().orthogonal()
	var kink:=minf(trail_width*0.3,origin.distance_to(end)*0.022)
	# Fixed irregular bends: stable for this short afterimage, no combat RNG.
	var points:=PackedVector2Array([origin,
		origin.lerp(end,0.25)+side*kink*0.35,
		origin.lerp(end,0.36)-side*kink,
		origin.lerp(end,0.38)+side*kink*0.55,
		origin.lerp(end,0.64)-side*kink*0.25,
		origin.lerp(end,0.67)+side*kink*0.8,
		origin.lerp(end,0.69)-side*kink*0.5,end])
	var fade:=pow(1.0-age/lifetime,2)
	surface.draw_polyline(points,Color(ELECTRIC,fade*budget),maxf(1.0,trail_width*0.085),true)
	surface.draw_polyline(points,Color(HOT,fade*budget*0.8),maxf(0.65,trail_width*0.027),true)
