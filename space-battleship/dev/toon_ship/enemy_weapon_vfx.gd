extends RefCounted
## Only the two weapon families currently equipped by enemy rows. Read-only art.
const AMBER:=Color("d7a25a")
const RED:=Color("c77155")
const DARK:=Color("583e38")
static func flight(surface:CanvasItem,p:Vector2,axis:Vector2,key:String)->void:
	var side:=axis.orthogonal()
	if key=="cannon":
		# Broad blunt slug, with a dark rim and a short separated wake.
		surface.draw_colored_polygon(PackedVector2Array([p+axis*6,p+axis*3+side*3.5,p-axis*6+side*3.5,p-axis*6-side*3.5,p+axis*3-side*3.5]),DARK)
		surface.draw_line(p-axis*4,p+axis*3,AMBER,4.0,true)
		surface.draw_line(p-axis*10,p-axis*15,Color(RED,0.45),2.0,true)
	else:
		# Slim finite laser dash with forked tail; no sustained beam or bloom.
		surface.draw_line(p-axis*10,p+axis*7,RED,2.5,true)
		surface.draw_line(p-axis*3,p+axis*6,AMBER,1.0,true)
		for sign_value in [-1,1]:surface.draw_line(p-axis*9,p-axis*14+side*sign_value*2,Color(RED,0.65),1.0,true)
static func impact(surface:CanvasItem,p:Vector2,axis:Vector2,age:float,key:String)->void:
	var fade:=clampf(1.0-age/0.12,0.0,1.0)
	var side:=axis.orthogonal()
	var radius:=3.0+4.0*(1.0-fade)
	if key=="cannon":surface.draw_arc(p,radius,0,TAU,12,Color(AMBER,fade*0.8),1.2,true)
	else:surface.draw_line(p-side*radius,p+side*radius,Color(RED,fade),1.5,true)
	for sign_value in [-1,1]:surface.draw_line(p+side*sign_value*radius,p+side*sign_value*(radius+3)-axis*3,Color(AMBER,fade*0.7),1.0,true)
