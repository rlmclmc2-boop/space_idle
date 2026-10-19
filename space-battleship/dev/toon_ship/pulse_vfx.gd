extends RefCounted
## Presentation only: compact faceted packets, directional kick and crisp contact.
const BOLT := preload("res://assets/weapons/fleet_20261019/pulse-bolt.png")
const CYAN := Color("42edee")
const BLUE := Color("398bdf")
const WHITE := Color("f1ffff")
static func accent(base:Color,tint:Color)->Color:
	return base if tint.a<=0 else base.lerp(Color(tint.r,tint.g,tint.b,base.a),0.72*tint.a)
static func flight(surface:CanvasItem,point:Vector2,direction:Vector2,tint:Color=Color(1,1,1,0))->void:
	var color:=Color.WHITE if tint.a<=0 else Color.WHITE.lerp(Color(tint.r,tint.g,tint.b,1),0.35*tint.a)
	surface.draw_set_transform(point,direction.angle()+PI*0.5)
	surface.draw_texture_rect(BOLT,Rect2(Vector2(-7,-17),Vector2(14,34)),false,color)
	surface.draw_set_transform(Vector2.ZERO)

static func flash(surface:CanvasItem,point:Vector2,direction:Vector2,age:float)->void:
	# Fire events live for 0.14 s, but this flash is already transparent at 0.075 s.
	if not is_finite(age) or age>=0.075 or not point.is_finite() or not direction.is_finite() or direction.is_zero_approx():return
	var t:=clampf(age/0.075,0.0,1.0)
	var fade:=1.0-t
	var across:=direction.orthogonal()
	var kick:=point-direction*(3.0*sin(t*PI))
	# Local muzzle kick contracts while the packet departs. No hull transform changes.
	# The concave four-point flash has a known two-triangle split. Submit it
	# directly so near-expiry float-rounded vertices never enter ear clipping.
	var back:=kick-direction*2.0
	var center:=kick+direction*9.0*fade
	_flash_triangle(surface,back,kick+direction*15.0*fade+across*4.0*fade,center,Color(CYAN,fade))
	_flash_triangle(surface,back,center,kick+direction*15.0*fade-across*4.0*fade,Color(CYAN,fade))
	surface.draw_line(kick-across*(4.0+3.0*t),kick+across*(4.0+3.0*t),Color(BLUE,fade*0.9),2.3,true)
	surface.draw_line(kick,kick+direction*11.0*fade,Color(WHITE,fade),3.0*fade+0.5,true)
static func _flash_triangle(surface:CanvasItem,a:Vector2,b:Vector2,c:Vector2,color:Color)->void:
	# Zero/subpixel area can occur even before expiry after screen-coordinate rounding.
	if absf((b-a).cross(c-a))<=0.00001:return
	surface.draw_primitive(PackedVector2Array([a,b,c]),PackedColorArray([color]),PackedVector2Array())
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
