extends RefCounted
## Read-only, lightweight inter-target carriers and persistent beam relations.
const LIGHT := Color("a7fff0")
const CORE := Color("f2fffc")

static func flight(surface:CanvasItem,point:Vector2,direction:Vector2)->void:
	var axis:=direction.normalized() if not direction.is_zero_approx() else Vector2.UP
	surface.draw_line(point-axis*18.0,point,Color(LIGHT,0.5),3.0,true)
	surface.draw_line(point-axis*10.0,point+axis*2.0,CORE,1.4,true)
	surface.draw_circle(point,3.0,LIGHT)

static func link(surface:CanvasItem,source:Vector2,target:Vector2,time:float)->void:
	surface.draw_line(source,target,Color(LIGHT,0.28),4.0,true)
	surface.draw_line(source,target,LIGHT,1.4,true)
	surface.draw_circle(source.lerp(target,fposmod(time*2.0,1.0)),2.3,CORE)
