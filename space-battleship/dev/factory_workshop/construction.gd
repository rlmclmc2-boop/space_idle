extends "res://scripts/hightech_construction.gd"
## Lightweight workshop trial: existing 23-stage art, only local welding FX.
## No room redraw, full-screen scan, particles, or independent progress clock.
func setup(key: String) -> void:
	super.setup(key)
	art_material.set_shader_parameter("blueprint_opacity",0.32)

func draw_effects(layer: Control) -> void:
	if research_pending or (assigned<=0 and completed<=0):return
	if completed>0:
		# Brief inspection sweep, constrained to the device footprint.
		var sweep_y:=260.0-(1.25-completed)*180.0
		layer.draw_line(Vector2(54,sweep_y),Vector2(242,sweep_y),Color("9ddad6"),1.3,true)
		return
	if fraction>=1:return
	for i in mini(3,assigned):
		var pos:=worker_positions[i]
		var target:=work_target(i)
		var weld:=worker_welding(i)
		if weld:layer.draw_line(pos,target,Color("eab473"),0.9,true)
		# A solid service drone with a restrained warm working tip.
		layer.draw_style_box(drone_shell(),Rect2(pos-Vector2(5,3),Vector2(10,6)))
		layer.draw_line(pos-Vector2(7,0),pos-Vector2(4,0),Color("79cecf"),1.5,true)
		layer.draw_line(pos+Vector2(4,0),pos+Vector2(7,0),Color("79cecf"),1.5,true)
		if weld:
			layer.draw_circle(target,1.6,Color("ffc983"))
			if sin(phase*9+i)>0:layer.draw_line(target-Vector2(2,2),target+Vector2(2,2),Color("fff1c9"),0.9,true)

static var drone_style: StyleBoxFlat
static func drone_shell() -> StyleBoxFlat:
	if drone_style==null:
		drone_style=StyleBoxFlat.new()
		drone_style.bg_color=Color("dce2dc")
		drone_style.border_color=Color("152b3b")
		drone_style.set_border_width_all(1)
		drone_style.set_corner_radius_all(2)
	return drone_style
