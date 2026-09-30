extends RefCounted
## One leading head and its continuous wake. Only real contact permits onward decoration.
const ELECTRIC := Color("a999ff")
const HOT := Color("fff5d6")
const GOLD := Color("ffbf54")
static func charge(surface:CanvasItem,point:Vector2,direction:Vector2,amount:float,_clock:float)->void:
	var across:=direction.orthogonal()
	for side in [-1.0,1.0]:
		surface.draw_line(point-direction*20.0+across*side*4.0,point+across*side*4.0,Color(GOLD,amount*0.75),1.6,true)
	surface.draw_circle(point,2.0*amount,Color(HOT,amount))
static func stroke(surface:CanvasItem,origin:Vector2,head:Vector2,fade:float)->void:
	if origin.distance_squared_to(head)<0.1:return
	surface.draw_line(origin,head,Color(GOLD,fade*0.18),16.0,true)
	for index in 8:
		var a:=float(index)/8.0
		var b:=float(index+1)/8.0
		var strength:=lerpf(0.18,1.0,b)*fade
		surface.draw_line(origin.lerp(head,a),origin.lerp(head,b),Color(GOLD,strength*0.85),6.0,true)
		surface.draw_line(origin.lerp(head,a),origin.lerp(head,b),Color(HOT,strength),3.1,true)
	surface.draw_circle(head,2.8,Color(HOT,fade))
static func flight(surface:CanvasItem,point:Vector2,_direction:Vector2,_clock:float,origin:Vector2)->void:
	stroke(surface,origin,point,1.0)
static func flash(surface:CanvasItem,point:Vector2,direction:Vector2,age:float,budget:float)->void:
	var fade:=clampf(1.0-age/0.075,0.0,1.0)*budget
	if fade<=0:return
	surface.draw_line(point-direction*3.0,point+direction*16.0,Color(HOT,fade),4.0,true)
	surface.draw_circle(point,8.0*fade,Color(GOLD,fade*0.25))
	surface.draw_line(point-direction.orthogonal()*6.0,point+direction.orthogonal()*6.0,Color(GOLD,fade),1.4,true)
static func impact(surface:CanvasItem,point:Vector2,direction:Vector2,age:float,_critical:bool,budget:float)->void:
	var fade:=clampf(1.0-age/0.07,0.0,1.0)*budget
	if fade<=0:return
	surface.draw_line(point-direction.orthogonal()*5.0,point+direction.orthogonal()*5.0,Color(HOT,fade),1.4,true)
static func penetration(surface:CanvasItem,origin:Vector2,contact:Vector2,direction:Vector2,age:float,_budget:float,bounds:Vector2)->void:
	if age<0.0 or age>0.18:return
	var reach:=2000.0
	if direction.x>0.0001:reach=minf(reach,(bounds.x-contact.x)/direction.x)
	elif direction.x<-0.0001:reach=minf(reach,-contact.x/direction.x)
	if direction.y>0.0001:reach=minf(reach,(bounds.y-contact.y)/direction.y)
	elif direction.y<-0.0001:reach=minf(reach,(36.0-contact.y)/direction.y)
	var head:=contact+direction*maxf(0.0,reach)*clampf(age/0.01,0.0,1.0)
	stroke(surface,origin,head,pow(clampf(1.0-age/0.075,0.0,1.0),1.2))
	if age>0.012:
		var fade:=clampf(1.0-age/0.18,0.0,1.0)
		var across:=direction.orthogonal()
		for side in [-1.0,1.0]:
			var points:=PackedVector2Array()
			for index in 15:
				var t:=float(index)/14.0
				points.append(origin.lerp(head,t)+across*(side*3.0+sin(float(index)*2.7+side)*3.0)*sin(PI*t))
			surface.draw_polyline(points,Color(Color("9de6ff"),fade*0.60),1.4,true)
