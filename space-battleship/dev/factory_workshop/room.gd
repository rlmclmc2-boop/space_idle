extends Control
## Static workshop geometry. Drawn once; only the machine has an animation clock.
var draws := 0
func _draw() -> void:
	draws+=1
	# Recessed work cell, asymmetric side access, high service gantry.
	draw_rect(Rect2(0,0,854,730),Color("101e2b"))
	draw_rect(Rect2(0,0,854,116),Color("1a2d3c"))
	draw_line(Vector2(0,116),Vector2(854,116),Color("354b5a"),2)
	draw_polygon(PackedVector2Array([Vector2(0,476),Vector2(854,476),Vector2(854,730),Vector2(0,730)]),PackedColorArray([Color("182d3a")]))
	draw_polygon(PackedVector2Array([Vector2(58,117),Vector2(186,117),Vector2(276,580),Vector2(10,580)]),PackedColorArray([Color("162935")]))
	draw_polygon(PackedVector2Array([Vector2(672,117),Vector2(776,117),Vector2(844,580),Vector2(580,580)]),PackedColorArray([Color("162935")]))
	# Dark inset mounting floor, no freestanding showroom pedestal.
	var floor_shape:=PackedVector2Array([Vector2(176,535),Vector2(618,535),Vector2(728,632),Vector2(89,632)])
	draw_colored_polygon(floor_shape,Color("223b48"))
	floor_shape.append(floor_shape[0])
	draw_polyline(floor_shape,Color("46636d"),2,true)
	for pair in [[Vector2(179,534),Vector2(212,534)],[Vector2(585,534),Vector2(618,534)],[Vector2(96,631),Vector2(146,631)],[Vector2(677,631),Vector2(727,631)]]:
		draw_line(pair[0],pair[1],Color("77c5c5"),3,true)
	# Overhead rail ends above the work cell, never links separate technologies.
	draw_rect(Rect2(65,106,717,15),Color("0b1721"))
	draw_rect(Rect2(95,104,651,3),Color("516874"))
	for x in [135,688]:
		draw_rect(Rect2(x,98,44,29),Color("334c5b"))
		draw_rect(Rect2(x+8,125,28,11),Color("92aaa9"))
		draw_rect(Rect2(x+11,136,22,3),Color("b8e1db"))
	# Service entry at lower left; parked AI dock is a local physical cue.
	draw_rect(Rect2(18,632,72,66),Color("1d3341"))
	for i in 3:
		draw_rect(Rect2(28+i*19,651,12,24),Color("314a59"))
		draw_line(Vector2(30+i*19,682),Vector2(38+i*19,682),Color("75b9bd"),2)
	draw_line(Vector2(90,671),Vector2(235,671),Color("39515d"),2)
	for x in range(250,640,30):draw_line(Vector2(x,690),Vector2(x+13,690),Color("344b59"),2)
	for y in [185,292,399]:
		draw_rect(Rect2(21,y,10,63),Color("213847"))
		draw_rect(Rect2(22,y+5,3,23),Color("629198"))
		draw_rect(Rect2(823,y,10,63),Color("213847"))
		draw_rect(Rect2(829,y+5,3,23),Color("629198"))
