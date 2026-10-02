extends RefCounted
## Presentation only. Warm, bounded main-cannon strokes leave cyan laser packets readable.
const ELECTRIC := Color("ffb65c")
const HOT := Color("fff3cf")
var charge_radius := 20.0
var trail_length := 138.0
var trail_width := 10.0
var flash_seconds := 0.09
var impact_seconds := 0.16
var impact_radius := 24.0
var penetration_length := 80.0
func configure(db) -> void:
	for key in ["charge_radius","trail_length","trail_width","flash_seconds","impact_seconds","impact_radius","penetration_length"]:
		set(key,db.weapon_motion_value("rail_"+key,float(get(key))))
func charge(surface:CanvasItem,point:Vector2,direction:Vector2,amount:float,clock:float)->void:
	if amount<=0:return
	var side:=direction.orthogonal()
	# The three broad rail cells fill towards the muzzle; no combat RNG or particles.
	for index in 3:
		var lit:=clampf(amount*3.0-float(index),0.0,1.0)
		var center:=point-direction*charge_radius*(0.9-float(index)*0.28)
		surface.draw_line(center-side*charge_radius*0.23,center+side*charge_radius*0.23,Color(ELECTRIC,lit*0.9),trail_width*0.26,true)
	var radius:=charge_radius*lerpf(1.0,0.35,amount)
	for index in 2:
		var angle:=clock*1.8+float(index)*PI
		surface.draw_arc(point,radius,angle,angle+PI*0.7,12,Color(ELECTRIC,amount*0.85),trail_width*0.22,true)
	surface.draw_circle(point,trail_width*(0.12+amount*0.2),Color(HOT,amount*0.9))
func flight(surface:CanvasItem,point:Vector2,direction:Vector2,_clock:float,origin:Vector2)->void:
	# A capped tail follows the projectile. Never redraw the whole travelled path.
	var length:=minf(origin.distance_to(point),trail_length)
	if length<0.1:return
	var side:=direction.orthogonal()
	var nose:=point+direction*trail_width
	var shoulder:=point-direction*minf(length*0.35,trail_width*2.0)
	var back:=point-direction*length
	surface.draw_colored_polygon(PackedVector2Array([nose,shoulder+side*trail_width*0.5,back,shoulder-side*trail_width*0.5]),ELECTRIC)
	surface.draw_line(back.lerp(point,0.32),nose,Color(HOT,0.95),trail_width*0.3,true)
func flash(surface:CanvasItem,point:Vector2,direction:Vector2,age:float,budget:float)->void:
	if age<0 or age>=flash_seconds:return
	var fade:=1.0-age/flash_seconds
	surface.draw_line(point-direction*trail_width*0.6,point+direction*trail_width*4.4,Color(ELECTRIC,fade*budget),trail_width*(0.3+fade*0.7),true)
	surface.draw_line(point,point+direction*trail_width*3.0,Color(HOT,fade),trail_width*0.35,true)
	var side:=direction.orthogonal()*charge_radius*(0.4+0.3*(1.0-fade))
	surface.draw_line(point-side,point+side,Color(ELECTRIC,fade*budget),trail_width*0.22,true)
func impact(surface:CanvasItem,point:Vector2,direction:Vector2,age:float,_critical:bool,budget:float)->void:
	if age<0 or age>=impact_seconds:return
	var t:=age/impact_seconds
	var fade:=1.0-t
	var radius:=impact_radius*(0.3+t*0.7)
	var side:=direction.orthogonal()
	# Local broken shock arcs communicate mass without an opaque explosion disc.
	for sign in [-1.0,1.0]:
		var angle: float=direction.angle()+sign*PI*0.5
		surface.draw_arc(point,radius,angle-0.6,angle+0.6,10,Color(ELECTRIC,fade*budget),trail_width*(0.1+fade*0.16),true)
		surface.draw_line(point+side*sign*radius*0.5,point+side*sign*radius-direction*radius*0.4,Color(HOT,fade),trail_width*0.16,true)
	if t<0.3:surface.draw_circle(point,trail_width*0.45*(1.0-t),Color(HOT,fade))
func penetration(surface:CanvasItem,_origin:Vector2,contact:Vector2,direction:Vector2,age:float,budget:float,bounds:Vector2)->void:
	if age<0 or age>=impact_seconds:return
	var reach:=penetration_length
	if direction.x>0.0001:reach=minf(reach,(bounds.x-contact.x)/direction.x)
	elif direction.x<-0.0001:reach=minf(reach,-contact.x/direction.x)
	if direction.y>0.0001:reach=minf(reach,(bounds.y-contact.y)/direction.y)
	elif direction.y<-0.0001:reach=minf(reach,(36.0-contact.y)/direction.y)
	var fade:=pow(1.0-age/impact_seconds,2)
	var end:=contact+direction*maxf(0.0,reach)
	surface.draw_line(contact,end,Color(ELECTRIC,fade*budget),trail_width*0.65,true)
	surface.draw_line(contact,end,Color(HOT,fade),trail_width*0.2,true)
