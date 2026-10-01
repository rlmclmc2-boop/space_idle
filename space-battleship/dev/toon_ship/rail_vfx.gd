extends RefCounted
## Electric discharge, not a persistent optical beam. Every shape belongs to one real shot.
const ELECTRIC := Color("78cfff")
const HOT := Color("eaffff")
static func noise(seed:int,channel:int)->float:
	var n:=posmod(seed*7919+channel*104729,2147483647)
	n=(n^(n<<13))&0x7fffffff
	return float(posmod(n*48271,2147483647))/2147483647.0
static func jagged(a:Vector2,b:Vector2,seed:int,width:float,count:int=12)->PackedVector2Array:
	var direction:Vector2=(b-a).normalized()
	var across:=direction.orthogonal()
	var points:=PackedVector2Array()
	for index in count+1:
		var t:=float(index)/float(count)
		var envelope:=minf(1.0,minf(t,1.0-t)*5.0)
		var along:=t if index in [0,count] else t+(noise(seed,index+71)-0.5)*0.45/float(count)
		points.append(a.lerp(b,along)+across*(noise(seed,index)*2.0-1.0)*width*envelope)
	return points
static func charge(surface:CanvasItem,point:Vector2,direction:Vector2,amount:float,clock:float)->void:
	if amount<=0:return
	var side:=direction.orthogonal()
	var seed:=int(clock*14.0)+int(point.x)*7
	# Cross-rail arcs visibly bridge the two metal sides of the barrel.
	for index in 3:
		var center:=point-direction*(5.0+float(index)*6.0)
		var bridge:=jagged(center-side*4.8,center+side*4.8,seed+index*19,2.6,5)
		surface.draw_polyline(bridge,Color(ELECTRIC,amount*0.9),1.7,true)
		surface.draw_circle(center+side*(noise(seed,index+8)-0.5)*9.0,1.0,Color(HOT,amount))
static func discharge(surface:CanvasItem,origin:Vector2,end:Vector2,age:float,seed:int)->void:
	if age<0.0 or age>0.18 or origin.distance_squared_to(end)<1.0:return
	var fade:=pow(1.0-age/0.18,1.25)
	var phase:=0 if age<0.05 else 1
	var points:=jagged(origin,end,seed+phase*53,13.0,14)
	var direction:Vector2=(end-origin).normalized()
	var across:=direction.orthogonal()
	# The core exists for less than a rendered frame; the dominant shape is electric.
	if age<0.022:
		surface.draw_line(origin,end,Color(HOT,0.8),1.4,true)
		surface.draw_polyline(points,Color(ELECTRIC,0.20),10.0,true)
		surface.draw_polyline(points,ELECTRIC,3.8,true)
		surface.draw_polyline(points,HOT,1.2,true)
	else:
		# Broken corona segments remain after passage; never a long fading laser.
		for start in [1,5,9]:
			var piece:=PackedVector2Array([points[start],points[start+1],points[start+2],points[start+3]])
			surface.draw_polyline(piece,Color(ELECTRIC,fade*0.85),2.0,true)
	for index in [3,6,9,11]:
		var side:float=-1.0 if index%2==0 else 1.0
		var reach:=22.0+noise(seed,index+31)*30.0
		var tip:Vector2=points[index]+across*side*reach+direction*(noise(seed,index+41)-0.5)*26.0
		var branch:=jagged(points[index],tip,seed+index*17,7.0,5)
		surface.draw_polyline(branch,Color(ELECTRIC,fade*0.8),1.7,true)
		if age<0.075:
			var fork:Vector2=branch[2]+across*side*14.0-direction*12.0
			surface.draw_polyline(jagged(branch[2],fork,seed+index*29,3.0,3),Color(HOT,fade*0.65),1.0,true)
static func flight(surface:CanvasItem,point:Vector2,_direction:Vector2,clock:float,origin:Vector2)->void:
	discharge(surface,origin,point,0.0,int(origin.x*17.0+clock*19.0))
static func flash(surface:CanvasItem,point:Vector2,direction:Vector2,age:float,budget:float)->void:
	if age>0.09:return
	var fade:=clampf(1.0-age/0.09,0.0,1.0)*budget
	for index in 3:
		var tip:=point+direction.rotated(float(index-1)*0.65)*(12.0+float(index)*3.0)
		surface.draw_polyline(jagged(point,tip,index+17,4.0,4),Color(ELECTRIC,fade),1.8,true)
static func impact(surface:CanvasItem,point:Vector2,direction:Vector2,age:float,_critical:bool,budget:float)->void:
	if age>0.10:return
	var fade:=clampf(1.0-age/0.10,0.0,1.0)*budget
	for side in [-1.0,1.0]:
		var tip:Vector2=point+direction.orthogonal()*side*14.0-direction*6.0
		surface.draw_polyline(jagged(point,tip,int(side)+41,5.0,4),Color(HOT,fade),1.8,true)
static func penetration(surface:CanvasItem,origin:Vector2,contact:Vector2,direction:Vector2,age:float,_budget:float,bounds:Vector2)->void:
	var reach:=2000.0
	if direction.x>0.0001:reach=minf(reach,(bounds.x-contact.x)/direction.x)
	elif direction.x<-0.0001:reach=minf(reach,-contact.x/direction.x)
	if direction.y>0.0001:reach=minf(reach,(bounds.y-contact.y)/direction.y)
	elif direction.y<-0.0001:reach=minf(reach,(36.0-contact.y)/direction.y)
	var end:=contact+direction*maxf(0.0,reach)
	discharge(surface,origin,end,age,int(origin.x*19.0+contact.x*7.0+contact.y))
