extends Node3D
## Four owned, load-bearing orbital sections share one tilted plane. Their rear
## geometry continues behind the planet's depth mask instead of ending there.
const KINDS := ["auto_explore", "refinery", "equipment", "shipyard"]
const ARC_BOUNDS := {
	"auto_explore": Vector2(PI * 1.075, PI * 1.24),
	"refinery": Vector2(PI * 1.24, TAU - 0.16),
	"equipment": Vector2(-0.16, PI * 0.5),
	"shipyard": Vector2(PI * 0.5, PI * 1.075),
}
const FACILITY_ANGLES := {
	"auto_explore": PI * 1.09,
	"refinery": TAU - 0.25,
	"equipment": 0.78,
	"shipyard": PI - 0.78,
}
const RADIUS := 4.5
const REAR_TRANSIT_WIDTH := 0.42
const FRONT_TRANSIT_WIDTH := 0.70
const NODE_WIDTH := 1.30
const TILT_Y := 0.66
const TILT_Z := 0.751
const DECK_HEIGHT := 0.16
const SOCKET_HEIGHT := 0.59
var _arcs: Dictionary = {}
var _end_caps: Dictionary = {}
var _joins: Dictionary = {}
var _owned: Array = []
var _navy: ShaderMaterial
var _side: ShaderMaterial
var _cyan: ShaderMaterial
var _deck: ShaderMaterial
var _sleeve: ShaderMaterial
var _all_materials: Array[ShaderMaterial] = []

static func plane_normal() -> Vector3:
	return Vector3(0.0, TILT_Z, TILT_Y)

static func point(angle: float) -> Vector3:
	return Vector3(RADIUS * cos(angle), -RADIUS * TILT_Y * sin(angle), RADIUS * TILT_Z * sin(angle))

static func socket_position(angle: float, kind: String) -> Vector3:
	# The refinery upper shell sits inside its real deck node. The station
	# bears closer to the ring center so its port no longer hangs beyond the
	# owned side wall; the through passage remains open at both ends.
	var height := SOCKET_HEIGHT if kind == "auto_explore" else 0.53
	var radial_offset := 0.12 if kind == "auto_explore" else -0.30 if kind == "refinery" else -0.16 if kind == "equipment" else -0.24 if kind == "shipyard" else 0.0
	return point(angle) + point(angle).normalized() * radial_offset + plane_normal() * height

func _ready() -> void:
	_navy = _material(Color("152f43"))
	_side = _material(Color("36566a"))
	_cyan = _material(Color("4cb9c2"), true)
	_navy.render_priority = -3
	_side.render_priority = -2
	_deck = _material(Color("fff2df"))
	_deck.set_shader_parameter("albedo_tex", preload("res://assets/planets/orbital_spine/deck-armor-continuous.png"))
	_deck.set_shader_parameter("textured", true)
	_sleeve = _deck.duplicate()
	_sleeve.render_priority = 1
	_all_materials.append(_sleeve)
	for kind in KINDS:
		var root := Node3D.new()
		root.name = kind + "SpineSection"
		add_child(root)
		var bounds: Vector2 = ARC_BOUNDS[kind]
		# A real thick section: dark keel and side walls remain visible under
		# broad warm armor plates. The central channel belongs to this section.
		_add_section_hull(root, bounds.x, bounds.y, NODE_WIDTH, kind)
		_add_curved_deck(root, bounds.x, bounds.y, NODE_WIDTH, 0.22, _deck, 0.0, 1.0, kind)
		for rib_index in range(1, 6):
			var rib_angle: float = lerpf(bounds.x, bounds.y, float(rib_index) / 6.0)
			if absf(rib_angle - FACILITY_ANGLES[kind]) > 0.14:
				# Carry each deck seam around the real owned pressure box; the
				# transverse clamp interrupts the inset power line at the same cut.
				_add_curved_deck(root, rib_angle - 0.008, rib_angle + 0.008, NODE_WIDTH + 0.03, 0.236, _side, 0.0, 1.0, kind)
				for side in [-1.0, 1.0]:
					_add_wall(root, rib_angle - 0.008, rib_angle + 0.008,
						side * (NODE_WIDTH * 0.5 + 0.018), -0.38, 0.27, _side, kind)
		_add_mount(root, kind, FACILITY_ANGLES[kind])
		_joins[kind] = _add_join(root, bounds.y, kind)
		var caps: Array[Node3D] = []
		for angle in [bounds.x, bounds.y]:
			var cap := Node3D.new()
			cap.name = "BuiltSectionTaperedTerminal"
			var outward := -1.0 if angle == bounds.x else 1.0
			_add_tapered_terminal(cap, angle, outward)
			root.add_child(cap)
			caps.append(cap)
		_arcs[kind] = root
		_end_caps[kind] = caps
		root.visible = false

func _material(color: Color, unshaded: bool = false) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = preload("res://scripts/planet_spine_opaque.gdshader")
	result.set_shader_parameter("tint", color)
	result.set_shader_parameter("luminous", unshaded)
	_all_materials.append(result)
	return result

func _add_tapered_terminal(parent: Node3D, angle: float, outward: float) -> void:
	# Continue the actual orbital cross-section before tapering it to a small
	# closed pressure nose. Nothing is placed underneath or atop a flat cut.
	var top_mesh := SurfaceTool.new()
	var side_mesh := SurfaceTool.new()
	var bottom_mesh := SurfaceTool.new()
	var light_mesh := SurfaceTool.new()
	for surface in [top_mesh, side_mesh, bottom_mesh, light_mesh]:
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var start_width := _transit_width(angle)
	var nose_span := 0.09
	var nose_width := 0.32
	var nose_top := 0.27
	var nose_edge := 0.19
	var nose_bottom := -0.17
	for step in 8:
		var t0 := float(step) / 8.0
		var t1 := float(step + 1) / 8.0
		var a := angle + outward * nose_span * t0
		var b := angle + outward * nose_span * t1
		var wa := lerpf(start_width, nose_width, smoothstep(0.0, 1.0, t0))
		var wb := lerpf(start_width, nose_width, smoothstep(0.0, 1.0, t1))
		var ta := lerpf(0.43, nose_top, t0)
		var tb := lerpf(0.43, nose_top, t1)
		var ea := lerpf(0.26, nose_edge, t0)
		var eb := lerpf(0.26, nose_edge, t1)
		var ba := lerpf(-0.40, nose_bottom, t0)
		var bb := lerpf(-0.40, nose_bottom, t1)
		var ai := point(a) * ((RADIUS - wa * 0.5) / RADIUS)
		var am := point(a) * ((RADIUS - wa * 0.15) / RADIUS)
		var ap := point(a) * ((RADIUS + wa * 0.15) / RADIUS)
		var ao := point(a) * ((RADIUS + wa * 0.5) / RADIUS)
		var bi := point(b) * ((RADIUS - wb * 0.5) / RADIUS)
		var bm := point(b) * ((RADIUS - wb * 0.15) / RADIUS)
		var bp := point(b) * ((RADIUS + wb * 0.15) / RADIUS)
		var bo := point(b) * ((RADIUS + wb * 0.5) / RADIUS)
		var up := plane_normal()
		_add_terminal_quad(top_mesh, ai + up * ea, bi + up * eb, am + up * ta, bm + up * tb, up, t0, t1)
		_add_terminal_quad(top_mesh, am + up * ta, bm + up * tb, ap + up * ta, bp + up * tb, up, t0, t1)
		_add_terminal_quad(top_mesh, ap + up * ta, bp + up * tb, ao + up * ea, bo + up * eb, up, t0, t1)
		_add_terminal_quad(bottom_mesh, ai + up * ba, bi + up * bb, ao + up * ba, bo + up * bb, -up, t0, t1)
		for side in [-1.0, 1.0]:
			var pa := ai if side < 0 else ao
			var pb := bi if side < 0 else bo
			var outward_normal: Vector3 = point(a).normalized() * float(side)
			_add_terminal_quad(side_mesh, pa + up * ba, pb + up * bb, pa + up * ea, pb + up * eb, outward_normal, t0, t1)
			var la := 0.04
			var lb := 0.04
			_add_terminal_quad(light_mesh, pa + up * la, pb + up * lb, pa + up * (la + 0.035), pb + up * (lb + 0.035), outward_normal, t0, t1)
	var end_angle := angle + outward * nose_span
	var end_center := point(end_angle)
	var radial := end_center.normalized()
	var up := plane_normal()
	var end_normal := (point(end_angle + 0.001) - point(end_angle - 0.001)).normalized() * outward
	var face := SurfaceTool.new()
	face.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_terminal_quad(face, end_center - radial * nose_width * 0.5 + up * nose_bottom, end_center + up * nose_bottom, end_center - radial * nose_width * 0.5 + up * nose_edge, end_center + up * nose_top, end_normal, 0.0, 1.0)
	_add_terminal_quad(face, end_center + up * nose_bottom, end_center + radial * nose_width * 0.5 + up * nose_bottom, end_center + up * nose_top, end_center + radial * nose_width * 0.5 + up * nose_edge, end_normal, 0.0, 1.0)
	for spec in [[top_mesh, _deck], [side_mesh, _side], [bottom_mesh, _navy], [light_mesh, _cyan], [face, _side]]:
		var instance := MeshInstance3D.new()
		instance.mesh = (spec[0] as SurfaceTool).commit()
		instance.material_override = spec[1]
		parent.add_child(instance)

func _add_terminal_quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, t0: float, t1: float) -> void:
	for entry in [[a, Vector2(0.0, t0)], [b, Vector2(0.0, t1)], [c, Vector2(1.0, t0)], [c, Vector2(1.0, t0)], [b, Vector2(0.0, t1)], [d, Vector2(1.0, t1)]]:
		surface.set_normal(normal)
		surface.set_uv(entry[1])
		surface.add_vertex(entry[0])

func _add_section_hull(parent: Node3D, begin: float, finish: float, width: float, kind: String = "") -> void:
	# One shared cross-section runs through every owned arc and completed join.
	# The lit inset is set into its armored wall, above the structural keel.
	# A second underside closes the lower pressure box all the way to each
	# independent end plane; the upper blue light remains recessed above it.
	_add_strip(parent, begin, finish, width, -0.40, _side, kind)
	for side in [-1.0, 1.0]:
		_add_wall(parent, begin, finish, side * width * 0.5, -0.40, -0.18, _navy, kind)
		_add_wall(parent, begin, finish, side * (width * 0.5 + 0.003), -0.38, -0.30, _side, kind)
	_add_strip(parent, begin, finish, width, -0.18, _navy, kind)
	for side in [-1.0, 1.0]:
		_add_wall(parent, begin, finish, side * width * 0.5, -0.18, 0.26, _navy, kind)
		_add_wall(parent, begin, finish, side * (width * 0.5 + 0.004), -0.28, 0.01, _side, kind)
		_add_wall(parent, begin, finish, side * (width * 0.5 + 0.005), -0.02, 0.26, _side, kind)
		_add_wall(parent, begin, finish, side * (width * 0.5 + 0.008), 0.015, 0.055, _cyan, kind)

func set_body_scale(scale: Vector3) -> void:
	for material in _all_materials:
		material.set_shader_parameter("body_scale", scale)

func set_stellar_field(tint: Color, strength: float) -> void:
	# The existing deck's inward lip acts as a restrained thermal boundary.
	# No extra ring or facility is added, and nonstellar decks keep their finish.
	for material in [_deck, _sleeve]:
		material.set_shader_parameter("stellar_field_tint", Vector3(tint.r, tint.g, tint.b))
		material.set_shader_parameter("stellar_field_strength", strength)

func _section_width(kind: String, angle: float) -> float:
	# The same real cross-section grows out of the transit spine at each owned
	# work node, then returns to a narrow section before any independent join.
	var distance := absf(angle - FACILITY_ANGLES[kind])
	var t := clampf((distance - 0.08) / 0.16, 0.0, 1.0)
	var blend := 1.0 - t * t * (3.0 - 2.0 * t)
	if kind == "refinery":
		# The furnace sits close to its next independent section. Its near
		# shoulder must return to transit width at the actual mating plane.
		blend *= smoothstep(0.0, 0.10, ARC_BOUNDS[kind].y - angle)
	# The station's pressure cheeks need less overhanging side wall than the
	# wider furnace and open industrial bays.
	var node_width := 1.10 if kind == "auto_explore" else NODE_WIDTH
	return lerpf(_transit_width(angle), node_width, blend)

func _transit_width(angle: float) -> float:
	# The front load path carries the visible heavy deck; the rear transit
	# section is slimmer before it passes behind the globe.
	return lerpf(REAR_TRANSIT_WIDTH, FRONT_TRANSIT_WIDTH, 0.5 + 0.5 * sin(angle))

func _shoulder_lift(kind: String, angle: float) -> float:
	if kind == "": return 0.0
	var distance := absf(angle - FACILITY_ANGLES[kind])
	var lift := 0.15 * (1.0 - smoothstep(0.10, 0.29, distance))
	if kind == "refinery":
		lift *= smoothstep(0.0, 0.085, ARC_BOUNDS[kind].y - angle)
	return lift

func _station_section_rise(kind: String, angle: float) -> float:
	if kind != "auto_explore": return 0.0
	# The pressure box returns to the common section at each independent cut.
	# Under the station its side wall rises into the bearing cheeks themselves,
	# keeping a real enclosed lower box without a dangling dark slab.
	var bounds: Vector2 = ARC_BOUNDS[kind]
	var inlet := smoothstep(0.0, 0.06, angle - bounds.x)
	var outlet := smoothstep(0.0, 0.08, bounds.y - angle)
	var center: float = FACILITY_ANGLES[kind] + 0.05
	var node := 1.0 - smoothstep(0.11, 0.26, absf(angle - center))
	return 0.18 * inlet * outlet * node

func _add_curved_deck(parent: Node3D, begin: float, finish: float, width: float, lift: float, material: Material, v_start: float = 0.0, v_end: float = 1.0, kind: String = "") -> void:
	# A continuous bevelled load-bearing surface, UV mapped to an authored
	# armor tile. Each independent quarter owns its whole physical arc.
	var profile := [
		Vector2(-0.50, 0.04), Vector2(-0.47, 0.12), Vector2(-0.40, 0.21),
		Vector2(-0.29, 0.24), Vector2(-0.14, 0.22), Vector2(-0.10, 0.17),
		Vector2(0.0, 0.15), Vector2(0.10, 0.17), Vector2(0.14, 0.22),
		Vector2(0.29, 0.24), Vector2(0.40, 0.21), Vector2(0.47, 0.12),
		Vector2(0.50, 0.04),
	]
	if kind in ["refinery", "equipment", "shipyard"]:
		var coarse: Array = profile
		var dense: Array[Vector2] = []
		for index in 41:
			var x: float = -0.5 + float(index) / 40.0
			for band in coarse.size() - 1:
				var left: Vector2 = coarse[band]
				var right: Vector2 = coarse[band + 1]
				if x <= right.x:
					dense.append(Vector2(x, lerpf(left.y, right.y, inverse_lerp(left.x, right.x, x))))
					break
		profile = dense
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := maxi(48, ceili((finish - begin) * (256.0 if kind in ["refinery", "equipment", "shipyard"] else 96.0)))
	for index in steps:
		var t0 := float(index) / float(steps)
		var t1 := float(index + 1) / float(steps)
		var a := lerpf(begin, finish, t0)
		var b := lerpf(begin, finish, t1)
		var wa := width + (_section_width(kind, a) - NODE_WIDTH if kind != "" else 0.0)
		var wb := width + (_section_width(kind, b) - NODE_WIDTH if kind != "" else 0.0)
		for band in profile.size() - 1:
			_deck_vertex(surface, profile, band, a, t0, wa, lift, v_start, v_end, kind)
			_deck_vertex(surface, profile, band, b, t1, wb, lift, v_start, v_end, kind)
			_deck_vertex(surface, profile, band + 1, a, t0, wa, lift, v_start, v_end, kind)
			_deck_vertex(surface, profile, band + 1, a, t0, wa, lift, v_start, v_end, kind)
			_deck_vertex(surface, profile, band, b, t1, wb, lift, v_start, v_end, kind)
			_deck_vertex(surface, profile, band + 1, b, t1, wb, lift, v_start, v_end, kind)
	var instance := MeshInstance3D.new()
	instance.mesh = surface.commit()
	instance.material_override = material
	parent.add_child(instance)

func _deck_vertex(surface: SurfaceTool, profile: Array, index: int, angle: float, t: float, width: float, lift: float, v_start: float, v_end: float, kind: String) -> void:
	var current: Vector2 = profile[index]
	var before: Vector2 = profile[maxi(0, index - 1)]
	var after: Vector2 = profile[mini(profile.size() - 1, index + 1)]
	var slope := (after.y - before.y) / ((after.x - before.x) * width)
	var radial := point(angle).normalized()
	var normal := (plane_normal() - radial * slope).normalized()
	surface.set_normal(normal)
	surface.set_uv(Vector2(current.x + 0.5, lerpf(v_start, v_end, t)))
	var height := lift + current.y
	# The recessed passage is cut into the same armor extrusion. Its center
	# texture and flanking shoulders carry through each independent section.
	if kind != "":
		# Raise the load-bearing shell beside each work floor, leaving a recessed
		# center for the facility rather than resting a separate pad on the ring.
		var shoulder := smoothstep(0.19, 0.38, absf(current.x))
		height += _shoulder_lift(kind, angle) * shoulder
	if kind == "refinery":
		var refinery_end_blend := smoothstep(0.0, 0.085, ARC_BOUNDS[kind].y - angle)
		var distance := absf(angle - FACILITY_ANGLES[kind])
		var foot_span: float = 1.0 - smoothstep(0.080, 0.18, distance)
		var foot_width: float = 1.0 - smoothstep(0.30, 0.46, absf(current.x))
		var inlet: float = (1.0 - smoothstep(0.023, 0.053, distance)) * (1.0 - smoothstep(0.08, 0.15, absf(current.x - 0.04)))
		height += (0.18 * foot_span * foot_width * (1.0 - inlet) - 0.035 * inlet) * refinery_end_blend
	elif kind == "equipment":
		# The load cheeks are raised out of this very deck; the open center
		# remains the ring's own recessed work path through the orange portal.
		var bay_span := 1.0 - smoothstep(0.10, 0.24, absf(angle - FACILITY_ANGLES[kind]))
		var center_path := 1.0 - smoothstep(0.16, 0.32, absf(current.x))
		var front_lip := smoothstep(0.27, 0.47, current.x)
		height += bay_span * (0.06 * (1.0 - center_path) - 0.16 * center_path - 0.12 * front_lip)
	elif kind == "shipyard":
		# The original deck rises into the cantilevers' one vertical spine.
		var keel_span := 1.0 - smoothstep(0.055, 0.13, absf(angle - FACILITY_ANGLES[kind]))
		var keel_width := 1.0 - smoothstep(0.20, 0.39, absf(current.x + 0.10))
		height += 0.14 * keel_span * keel_width
	surface.add_vertex(point(angle) * ((RADIUS + current.x * width) / RADIUS) + plane_normal() * height)

func _add_strip(parent: Node3D, begin: float, finish: float, width: float, lift: float, material: Material, kind: String = "") -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var normal := plane_normal()
	var steps := maxi(24, ceili((finish - begin) * 96.0))
	for index in steps:
		var a := lerpf(begin, finish, float(index) / float(steps))
		var b := lerpf(begin, finish, float(index + 1) / float(steps))
		var section_a := _station_section_rise(kind, a) if lift < 0.0 else 0.0
		var section_b := _station_section_rise(kind, b) if lift < 0.0 else 0.0
		var wa := width + (_section_width(kind, a) - NODE_WIDTH if kind != "" else 0.0)
		var wb := width + (_section_width(kind, b) - NODE_WIDTH if kind != "" else 0.0)
		var ai := point(a) * ((RADIUS - wa * 0.5) / RADIUS) + normal * (lift + section_a)
		var ao := point(a) * ((RADIUS + wa * 0.5) / RADIUS) + normal * (lift + section_a)
		var bi := point(b) * ((RADIUS - wb * 0.5) / RADIUS) + normal * (lift + section_b)
		var bo := point(b) * ((RADIUS + wb * 0.5) / RADIUS) + normal * (lift + section_b)
		for vertex in [ai, bi, ao, ao, bi, bo]:
			surface.set_normal(normal)
			surface.add_vertex(vertex)
	var instance := MeshInstance3D.new()
	instance.mesh = surface.commit()
	instance.material_override = material
	parent.add_child(instance)

func _add_wall(parent: Node3D, begin: float, finish: float, radial: float, bottom: float, top: float, material: Material, kind: String = "") -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var normal := plane_normal()
	var steps := maxi(24, ceili((finish - begin) * 96.0))
	for index in steps:
		var a := lerpf(begin, finish, float(index) / float(steps))
		var b := lerpf(begin, finish, float(index + 1) / float(steps))
		var ra := signf(radial) * (absf(radial) + (_section_width(kind, a) - NODE_WIDTH) * 0.5) if kind != "" else radial
		var rb := signf(radial) * (absf(radial) + (_section_width(kind, b) - NODE_WIDTH) * 0.5) if kind != "" else radial
		var pa := point(a) * ((RADIUS + ra) / RADIUS)
		var pb := point(b) * ((RADIUS + rb) / RADIUS)
		var wall_normal := (pa + pb).normalized() * signf(radial)
		var lift_a := _shoulder_lift(kind, a)
		var lift_b := _shoulder_lift(kind, b)
		var lower_a := bottom + (lift_a if material == _cyan else 0.0)
		var lower_b := bottom + (lift_b if material == _cyan else 0.0)
		var upper_a := top + lift_a
		var upper_b := top + lift_b
		var section_a := _station_section_rise(kind, a)
		var section_b := _station_section_rise(kind, b)
		lower_a += section_a
		lower_b += section_b
		if top < 0.10:
			upper_a += section_a
			upper_b += section_b
		for vertex in [pa + normal * lower_a, pb + normal * lower_b, pa + normal * upper_a, pa + normal * upper_a, pb + normal * lower_b, pb + normal * upper_b]:
			surface.set_normal(wall_normal)
			surface.add_vertex(vertex)
	var instance := MeshInstance3D.new()
	instance.mesh = surface.commit()
	instance.material_override = material
	parent.add_child(instance)

func _add_mount(parent: Node3D, kind: String, angle: float) -> void:
	# One restrained amber status light makes the socket read as equipment,
	# without introducing another buildable node.
	var lamp := MeshInstance3D.new()
	var lens := SphereMesh.new()
	lens.radius = 0.055
	lens.height = 0.11
	lamp.mesh = lens
	lamp.material_override = _material(Color("d5a661"), true)
	lamp.position = point(angle) * ((RADIUS + 0.57) / RADIUS) + plane_normal() * 0.48
	parent.add_child(lamp)

func _add_join(parent: Node3D, angle: float, kind: String) -> Node3D:
	# Covers the armor gap where two independently built sections mate. This
	# collar is owned by the preceding section and appears only after both exist.
	var join := Node3D.new()
	join.name = "SectionJoin"
	parent.add_child(join)
	var joint_width := _transit_width(angle) + 0.02
	# Close the complete load path, including its keel and lit outer wall. A
	# top-only sleeve leaves an obvious open cut at oblique orbital phases.
	_add_section_hull(join, angle - 0.12, angle + 0.12, joint_width)
	# The refinery deck now returns to the exact mating height. Its two owned
	# top surfaces meet there, so a second raised sleeve would cover that
	# shared plane with a visible white step. The bottom load collar remains.
	if kind != "refinery":
		_add_curved_deck(join, angle - 0.12, angle + 0.12, joint_width, 0.232, _sleeve, 0.37, 0.63)
	return join

func configure(owned: Array) -> void:
	_owned = owned.duplicate()
	for kind in KINDS:
		_arcs[kind].visible = kind in _owned
		var index := KINDS.find(kind)
		_joins[kind].visible = kind in _owned and KINDS[(index + 1) % KINDS.size()] in _owned
		var caps: Array = _end_caps[kind]
		caps[0].visible = KINDS[(index + KINDS.size() - 1) % KINDS.size()] not in _owned
		caps[1].visible = KINDS[(index + 1) % KINDS.size()] not in _owned

func update_pose(clock: float) -> void:
	basis = Basis(Vector3(0.0, -TILT_Z, -TILT_Y), clock * 0.045)
