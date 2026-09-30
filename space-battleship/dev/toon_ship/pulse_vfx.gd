extends RefCounted
## Presentation only: a finite energy packet, never a beam or stored flight ribbon.
const CYAN := Color("55def2")
const WHITE := Color("eaffff")
static func flight(surface:CanvasItem,point:Vector2,direction:Vector2)->void:
	var nose:=point+direction*6.0
	var tail:=point-direction*8.0
	# Fixed spatial length is independent of frame rate and projectile speed.
	surface.draw_line(point-direction*22.0,tail,Color(CYAN,0.24),2.2,true)
	surface.draw_line(tail,nose,Color(CYAN,0.22),7.0,true)
	surface.draw_line(tail,nose,CYAN,3.6,true)
	surface.draw_circle(nose,1.8,CYAN)
	surface.draw_line(point,nose,WHITE,2.0,true)
static func flash(surface:CanvasItem,point:Vector2,direction:Vector2,age:float)->void:
	var fade:=clampf(1.0-age/0.075,0.0,1.0)
	var across:=direction.orthogonal()
	surface.draw_colored_polygon(PackedVector2Array([point-across*3.5*fade,point+direction*11.0*fade,point+across*3.5*fade,point-direction*2.0]),Color(CYAN,fade*0.8))
	surface.draw_line(point,point+direction*7.0*fade,Color(WHITE,fade),2.2,true)
static func impact(surface:CanvasItem,point:Vector2,direction:Vector2,age:float,critical:bool)->void:
	var t:=clampf(age/0.13,0.0,1.0)
	var fade:=1.0-t
	var size:float=(4.0+5.0*t)*(1.15 if critical else 1.0)
	var across:=direction.orthogonal()
	# A compact transverse contact shape and three fixed shards, no huge bloom.
	surface.draw_line(point-across*size,point+across*size,Color(CYAN,fade*0.9),2.0*fade+0.5,true)
	surface.draw_circle(point,2.3*fade,Color(WHITE,fade))
	for sign_value in [-1.0,0.0,1.0]:
		var axis:Vector2=(-direction+across*sign_value*0.8).normalized()
		surface.draw_line(point+axis*(2.0+size*0.3),point+axis*(3.0+size),Color(CYAN,fade*0.65),1.3,true)
