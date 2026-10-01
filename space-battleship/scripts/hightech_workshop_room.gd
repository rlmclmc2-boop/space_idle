extends Control
## Static room; machine-local grounding draws once with its owning work cell.
# Anchor is the real source-image sole, not the edge of its transparent canvas.
const MACHINE_LAYOUTS := {
	"furnace": {"scale":1.78,"sole":Vector2(0.50,0.933)},
	"focus": {"scale":1.60,"sole":Vector2(0.50,0.936)},
	"armour": {"scale":1.58,"sole":Vector2(0.50,0.964)},
	"crystal": {"scale":1.76,"sole":Vector2(0.50,0.897)}
}
const GROUND := Vector2(427,610)
var draws := 0

class Grounding extends Control:
	var contour := PackedVector2Array()
	func _draw() -> void:
		var center := Vector2.ZERO
		for point in contour:center+=point
		center/=maxi(1,contour.size())
		# Tiny layered penumbra, clipped visually by the opaque machine above it.
		for layer in [3,2,1,0]:
			var edge := PackedVector2Array()
			for point in contour:
				edge.append(center+(point-center)*Vector2(1.0+layer*0.012,1.0+layer*0.025)+Vector2(0,1.1+layer*0.6))
			draw_colored_polygon(edge,Color(0.025,0.055,0.075,0.065 if layer>0 else 0.25))

static func layout(shape: String, pending := false) -> Dictionary:
	if pending:return {"position":Vector2(176,118),"scale":Vector2.ONE*1.68}
	var spec: Dictionary=MACHINE_LAYOUTS.get(shape,MACHINE_LAYOUTS.furnace)
	return {"position":GROUND-spec.sole*296.0*spec.scale,"scale":Vector2.ONE*spec.scale}

static func add_grounding(machine: Control, shape: String) -> Control:
	var grounding:=Grounding.new()
	grounding.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var outline:=PackedVector2Array()
	if shape=="armour":
		# The press is three-quarter view: its left and right feet are not level.
		outline=PackedVector2Array([Vector2(0.03,0.805),Vector2(0.12,0.765),Vector2(0.77,0.816),Vector2(0.973,0.833),Vector2(0.974,0.869),Vector2(0.884,0.899),Vector2(0.865,0.947),Vector2(0.79,0.965),Vector2(0.701,0.945),Vector2(0.654,0.912),Vector2(0.237,0.822),Vector2(0.169,0.842),Vector2(0.035,0.819)])
	elif shape=="focus":
		# Separate broad front feet flank the higher circular middle plinth.
		outline=PackedVector2Array([Vector2(0.065,0.871),Vector2(0.15,0.823),Vector2(0.84,0.818),Vector2(0.937,0.868),Vector2(0.925,0.904),Vector2(0.852,0.936),Vector2(0.735,0.915),Vector2(0.674,0.879),Vector2(0.347,0.882),Vector2(0.3,0.917),Vector2(0.211,0.932),Vector2(0.094,0.906)])
	else:
		var center:=Vector2(0.5,0.894) if shape=="furnace" else Vector2(0.5,0.856)
		var radius:=Vector2(0.383,0.041) if shape=="furnace" else Vector2(0.321,0.043)
		for i in 48:
			var angle:=TAU*float(i)/48.0
			outline.append(center+Vector2(cos(angle),sin(angle))*radius)
	for point in outline:grounding.contour.append(point*296.0)
	machine.add_child(grounding)
	machine.move_child(grounding,0)
	return grounding

func soft_pool(center: Vector2, radius: Vector2) -> void:
	# Vertex-alpha falloff avoids a hard floor decal or a new render pass.
	var points:=PackedVector2Array([center])
	var colors:=PackedColorArray([Color(0.64,0.76,0.73,0.055)])
	for i in 49:
		var angle:=TAU*float(i)/48.0
		points.append(center+Vector2(cos(angle),sin(angle))*radius)
		colors.append(Color(0.64,0.76,0.73,0))
	for i in range(1,49):
		draw_polygon(PackedVector2Array([points[0],points[i],points[i+1]]),PackedColorArray([colors[0],colors[i],colors[i+1]]))

func _draw() -> void:
	draws+=1
	draw_rect(Rect2(0,0,854,730),Color("101e2b"))
	draw_rect(Rect2(0,0,854,116),Color("1a2d3c"))
	draw_line(Vector2(0,116),Vector2(854,116),Color("354b5a"),2)
	# Continuous floor, without a second, incompatible perspective platform.
	draw_polygon(PackedVector2Array([Vector2(0,445),Vector2(854,445),Vector2(854,730),Vector2(0,730)]),PackedColorArray([Color("142733"),Color("142733"),Color("1b3340"),Color("1b3340")]))
	# Both emitters point inward into the work cell, with soft floor landings.
	for light in [{"x":151.0,"target":Vector2(315,571)},{"x":704.0,"target":Vector2(539,571)}]:
		var x: float=light.x
		var target: Vector2=light.target
		draw_polygon(PackedVector2Array([Vector2(x-9,144),Vector2(x+9,144),target+Vector2(134,30),target+Vector2(-134,30)]),PackedColorArray([Color(0.71,0.84,0.80,0.055),Color(0.71,0.84,0.80,0.055),Color(0.71,0.84,0.80,0),Color(0.71,0.84,0.80,0)]))
		soft_pool(target,Vector2(191,69))
	# Recessed rail with short yokes and recognisable shaded light housings.
	draw_rect(Rect2(65,106,717,15),Color("0b1721"))
	draw_rect(Rect2(95,104,651,3),Color("516874"))
	for x in [151.0,704.0]:
		draw_line(Vector2(x,109),Vector2(x,124),Color("66818c"),5,true)
		var shell:=StyleBoxFlat.new()
		shell.bg_color=Color("263f4d")
		shell.border_color=Color("789294")
		shell.set_border_width_all(1)
		shell.set_corner_radius_all(5)
		draw_style_box(shell,Rect2(x-19,121,38,22))
		draw_line(Vector2(x-13,139),Vector2(x+13,139),Color("c3d9c9"),4,true)
		draw_line(Vector2(x-9,142),Vector2(x+9,142),Color("f2f1d6"),2,true)
	# Service entry stays outside the device footprint and progress readout.
	draw_rect(Rect2(18,632,72,66),Color("1d3341"))
	for i in 3:
		draw_rect(Rect2(28+i*19,651,12,24),Color("314a59"))
		draw_line(Vector2(30+i*19,682),Vector2(38+i*19,682),Color("75b9bd"),2)
	draw_line(Vector2(90,671),Vector2(185,671),Color("39515d"),2)
	for x in range(250,640,30):draw_line(Vector2(x,690),Vector2(x+13,690),Color("344b59"),2)
	for y in [185,292,399]:
		draw_rect(Rect2(21,y,10,63),Color("213847"))
		draw_rect(Rect2(22,y+5,3,23),Color("629198"))
		draw_rect(Rect2(823,y,10,63),Color("213847"))
		draw_rect(Rect2(829,y+5,3,23),Color("629198"))
