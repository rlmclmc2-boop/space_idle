extends RefCounted
## Localized rail discharge. No RNG, gameplay state or stored flight history.
const ELECTRIC := Color("a999ff")
const HOT := Color("fff5d6")
const GOLD := Color("ffbf54")
static func arc(surface:CanvasItem,point:Vector2,direction:Vector2,length:float,width:float,phase:float,color:Color)->void:
	var across:=direction.orthogonal()
	var points:=PackedVector2Array()
	for index in 8:
		var t:=float(index)/7.0
		points.append(point+direction*length*t+across*sin(t*19.0+phase)*width*sin(t*PI))
	surface.draw_polyline(points,color,1.7,true)
static func charge(surface:CanvasItem,point:Vector2,direction:Vector2,amount:float,clock:float)->void:
	var across:=direction.orthogonal()
	for side in [-1.0,1.0]:
		var start:Vector2=point-direction*22.0+across*side*6.0
		arc(surface,start,direction,23.0,2.5*amount,clock*18.0+side,Color(ELECTRIC,amount*0.8))
		surface.draw_line(start,point+across*side*4.0,Color(GOLD,amount*0.65),1.7,true)
	surface.draw_circle(point,2.5*amount,Color(HOT,amount))
static func flight(surface:CanvasItem,point:Vector2,direction:Vector2,clock:float)->void:
	var tail:=point-direction*66.0
	surface.draw_line(tail,point,Color(ELECTRIC,0.13),15.0,true)
	surface.draw_line(point-direction*44.0,point+direction*10.0,Color(GOLD,0.38),7.0,true)
	surface.draw_line(point-direction*32.0,point+direction*10.0,HOT,3.3,true)
	arc(surface,tail,direction,66.0,4.5,clock*23.0,Color(ELECTRIC,0.8))
	var across:=direction.orthogonal()
	surface.draw_colored_polygon(PackedVector2Array([point-direction*11.0,point-across*4.0,point+direction*13.0,point+across*4.0]),HOT)
static func flash(surface:CanvasItem,point:Vector2,direction:Vector2,age:float,budget:float)->void:
	var t:=clampf(age/0.20,0.0,1.0)
	var fade:=pow(1.0-t,2.0)*budget
	var across:=direction.orthogonal()
	# Bright first 50 ms core; the expanding split ring then clears quickly.
	var core:=clampf(1.0-age/0.055,0.0,1.0)
	surface.draw_circle(point,18.0*core,Color(GOLD,core*0.2*budget))
	if core>0.001:surface.draw_colored_polygon(PackedVector2Array([point-direction*7.0,point-across*9.0*core,point+direction*(20.0+24.0*core),point+across*9.0*core]),Color(HOT,fade))
	for side in [-1.0,1.0]:
		arc(surface,point+across*side*5.0,direction,32.0+18.0*t,5.0,side+age*35.0,Color(ELECTRIC,fade))
		surface.draw_line(point+across*side*(5.0+19.0*t)-direction*5.0,point+across*side*(8.0+24.0*t)+direction*9.0,Color(GOLD,fade),2.0,true)
static func impact(surface:CanvasItem,point:Vector2,direction:Vector2,age:float,critical:bool,budget:float)->void:
	var t:=clampf(age/0.30,0.0,1.0)
	var fade:=pow(1.0-t,1.5)*budget
	var radius:float=(5.0+24.0*t)*(1.12 if critical else 1.0)
	var across:=direction.orthogonal()
	surface.draw_circle(point,12.0*(1.0-t),Color(GOLD,fade*0.1))
	var ring:=PackedVector2Array()
	for index in 33:
		var angle:=TAU*float(index)/32.0
		ring.append(point+across*cos(angle)*radius+direction*sin(angle)*radius*0.40)
	surface.draw_polyline(ring,Color(ELECTRIC,fade),2.5*(1.0-t)+0.6,true)
	surface.draw_line(point-across*(8.0+16.0*t),point+across*(8.0+16.0*t),Color(HOT,fade),3.0*(1.0-t)+0.5,true)
	for index in 9:
		var angle:=TAU*float(index)/9.0+0.19
		var axis:=Vector2.from_angle(angle)
		var reach:=radius*(0.75+0.45*float(index%3))
		surface.draw_line(point+axis*reach*0.55,point+axis*reach,Color(GOLD,fade),2.0,true)
	var core:=clampf(1.0-age/0.065,0.0,1.0)
	surface.draw_circle(point,7.0*core,Color(HOT,core*budget))

static func penetration(surface:CanvasItem,origin:Vector2,contact:Vector2,direction:Vector2,age:float,budget:float,bounds:Vector2)->void:
	# Triggered ONLY by the existing real impact. The outgoing streak is decoration,
	# not a projectile or an extra hit. The battle CanvasItem clips it at the edge.
	if age<0.0 or age>0.14:return
	var reach:=2000.0
	if direction.x>0.0001:reach=minf(reach,(bounds.x-contact.x)/direction.x)
	elif direction.x<-0.0001:reach=minf(reach,-contact.x/direction.x)
	if direction.y>0.0001:reach=minf(reach,(bounds.y-contact.y)/direction.y)
	elif direction.y<-0.0001:reach=minf(reach,(36.0-contact.y)/direction.y) # Clear overlapping battlefield header.
	reach=maxf(0.0,reach)
	var extension:=clampf(age/0.035,0.0,1.0)
	var end:=contact+direction*reach*extension
	var fade:=pow(clampf(1.0-age/0.14,0.0,1.0),1.6)*budget
	# One violent white-gold strike, then a thin ionized scar. No sustained beam.
	surface.draw_line(origin,end,Color(ELECTRIC,fade*0.11),14.0,true)
	surface.draw_line(origin,end,Color(GOLD,fade*0.48),5.0,true)
	surface.draw_line(origin,end,Color(HOT,minf(1.0,fade*1.6)),2.3,true)
	var across:=direction.orthogonal()
	for index in 5:
		var point:=contact+direction*reach*float(index+1)/6.0*extension
		var side:=1.0 if index%2==0 else -1.0
		surface.draw_line(point-direction*9.0+across*side*3.5,point+direction*5.0,Color(ELECTRIC,fade*0.65),1.3,true)
