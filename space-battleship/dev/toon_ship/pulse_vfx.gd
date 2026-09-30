extends RefCounted
## Presentation only: compact faceted packets, directional kick and crisp contact.
const CYAN := Color("42edee")
const BLUE := Color("398bdf")
const WHITE := Color("f1ffff")
static func flight(surface:CanvasItem,point:Vector2,direction:Vector2)->void:
	var across:=direction.orthogonal()
	# Fixed geometry never links successive frames into a beam.
	var nose:=point+direction*9.0
	var back:=point-direction*11.0
	var shell:=PackedVector2Array([nose,point+across*4.5,back,point-across*4.5])
	surface.draw_line(back,nose,Color(BLUE,0.20),12.0,true)
	surface.draw_colored_polygon(shell,CYAN)
	surface.draw_colored_polygon(PackedVector2Array([nose,point+direction*1.0+across*2.2,back+direction*5.0,point+direction*1.0-across*2.2]),WHITE)
	for side in [-1.0,1.0]:
		surface.draw_line(back+across*side*2.0,point-direction*25.0+across*side*3.0,Color(BLUE,0.7),1.8,true)
	# A short transverse energy ridge distinguishes the packet from a tracer.
	surface.draw_line(point+direction*2.0-across*5.0,point+direction*2.0+across*5.0,Color(CYAN,0.8),1.2,true)
static func flash(surface:CanvasItem,point:Vector2,direction:Vector2,age:float)->void:
	var t:=clampf(age/0.075,0.0,1.0)
	var fade:=1.0-t
	var across:=direction.orthogonal()
	var kick:=point-direction*(3.0*sin(t*PI))
	# Local muzzle kick contracts while the packet departs. No hull transform changes.
	surface.draw_colored_polygon(PackedVector2Array([kick-direction*2.0,kick+direction*15.0*fade+across*4.0*fade,kick+direction*9.0*fade,kick+direction*15.0*fade-across*4.0*fade]),Color(CYAN,fade))
	surface.draw_line(kick-across*(4.0+3.0*t),kick+across*(4.0+3.0*t),Color(BLUE,fade*0.9),2.3,true)
	surface.draw_line(kick,kick+direction*11.0*fade,Color(WHITE,fade),3.0*fade+0.5,true)
static func impact(surface:CanvasItem,point:Vector2,direction:Vector2,age:float,critical:bool)->void:
	var t:=clampf(age/0.13,0.0,1.0)
	var fade:=1.0-t
	var size:float=(4.0+10.0*t)*(1.15 if critical else 1.0)
	var across:=direction.orthogonal()
	var diamond:=PackedVector2Array([point+direction*size*0.65,point+across*size,point-direction*size*0.65,point-across*size,point+direction*size*0.65])
	surface.draw_polyline(diamond,Color(CYAN,fade*0.9),2.0*fade+0.5,true)
	if t<0.45:
		surface.draw_colored_polygon(PackedVector2Array([point+direction*5.0,point+across*4.0,point-direction*5.0,point-across*4.0]),Color(WHITE,fade))
	for index in 4:
		var axis:=(-direction).rotated((-1.5+float(index))*0.7)
		var start:=point+axis*(4.0+8.0*t)
		var finish:=point+axis*(8.0+14.0*t)
		surface.draw_line(start,finish,Color(CYAN if index%2==0 else BLUE,fade),1.8,true)
