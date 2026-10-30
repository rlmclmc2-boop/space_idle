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
const SOCKET_HEIGHT := 0.65
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
var _refinery_receiver: Node3D
var _refinery_receiver_vector := Vector3.ZERO

static func plane_normal() -> Vector3:
	return Vector3(0.0, TILT_Z, TILT_Y)

static func point(angle: float) -> Vector3:
	return Vector3(RADIUS * cos(angle), -RADIUS * TILT_Y * sin(angle), RADIUS * TILT_Z * sin(angle))

static func socket_position(angle: float, kind: String) -> Vector3:
	# The refinery upper shell sits inside its real deck node; its old baked
	# floor is gone. Other facility roots keep their existing R5 pose.
	var height := SOCKET_HEIGHT if kind == "auto_explore" else 0.53
	var radial_offset := 0.25 if kind == "auto_explore" else -0.30 if kind == "refinery" else -0.16 if kind == "equipment" else -0.24 if kind == "shipyard" else 0.0
	return point(angle) + point(angle).normalized() * radial_offset + plane_normal() * height

static func refinery_feed_tip() -> Vector3:
	return point(FACILITY_ANGLES["refinery"]) + plane_normal() * 0.47

static func _refinery_unaimed_feed_top() -> Vector3:
	var a: float = FACILITY_ANGLES["refinery"]
	return point(a) * ((RADIUS - 0.12) / RADIUS) + plane_normal() * 0.62

func refinery_feed_top() -> Vector3:
	return _refinery_receiver.position + _refinery_receiver.basis * _refinery_receiver_vector

func aim_refinery_receiver() -> void:
	# The short rigid receiver swivels at its fixed ring socket with the
	# upright service shell. No endpoint selection or section geometry moves.
	var desired: Vector3 = global_transform.basis.inverse() * Vector3(-0.10, 0.13, 0.18)
	var from: Vector3 = _refinery_receiver_vector
	var axis := desired.normalized()
	var aim := Quaternion(from.normalized(), axis)
	var facing: Vector3 = global_transform.basis.inverse() * Vector3.BACK
	var current_up: Vector3 = aim * plane_normal()
	var roll_from := (current_up - axis * current_up.dot(axis)).normalized()
	var roll_to := (facing - axis * facing.dot(axis)).normalized()
	var roll := atan2(axis.dot(roll_from.cross(roll_to)), roll_from.dot(roll_to))
	_refinery_receiver.basis = Basis(Quaternion(axis, roll) * aim).scaled(Vector3.ONE * (desired.length() / from.length()))

func _ready() -> void:
	_navy = _material(Color("152f43"))
	_side = _material(Color("36566a"))
	_cyan = _material(Color("4cb9c2"), true)
	_navy.render_priority = -3
	_side.render_priority = -2
	_deck = _material(Color("fff2df"))
	_deck.set_shader_parameter("albedo_tex", preload("res://assets/planets/orbital_spine/deck-concept-spine.png"))
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
		_add_strip(root, bounds.x, bounds.y, NODE_WIDTH, -0.20, _navy, kind)
		_add_wall(root, bounds.x, bounds.y, NODE_WIDTH * 0.5, -0.42, 0.26, _navy, kind)
		_add_wall(root, bounds.x, bounds.y, -NODE_WIDTH * 0.5, -0.42, 0.26, _navy, kind)
		_add_wall(root, bounds.x, bounds.y, NODE_WIDTH * 0.5 + 0.005, 0.08, 0.18, _side, kind)
		_add_wall(root, bounds.x, bounds.y, NODE_WIDTH * 0.5 + 0.008, -0.22, -0.16, _cyan, kind)
		_add_curved_deck(root, bounds.x, bounds.y, NODE_WIDTH, 0.22, _deck, 0.0, 1.0, kind)
		_add_load_channel(root, bounds.x, bounds.y)
		for rib_index in range(1, 6):
			var rib_angle: float = lerpf(bounds.x, bounds.y, float(rib_index) / 6.0)
			if absf(rib_angle - FACILITY_ANGLES[kind]) > 0.14:
				_add_curved_deck(root, rib_angle - 0.008, rib_angle + 0.008, NODE_WIDTH + 0.03, 0.236, _side, 0.0, 1.0, kind)
		_add_mount(root, kind, FACILITY_ANGLES[kind])
		_joins[kind] = _add_join(root, bounds.y)
		var caps: Array[Node3D] = []
		for angle in [bounds.x, bounds.y]:
			var cap := Node3D.new()
			cap.name = "BuiltSectionTerminal"
			var outward := -1.0 if angle == bounds.x else 1.0
			# A sealed armored cross-section belongs to the built segment alone.
			# The shallow cyan service slit faces the future mating segment.
			for layer in [
				[Vector3(0.63, 0.36, 0.23), Vector3(0, 0.14, outward * 0.04), _navy],
				[Vector3(0.59, 0.17, 0.19), Vector3(0, 0.27, outward * 0.06), _side],
				[Vector3(0.38, 0.055, 0.035), Vector3(0, 0.04, outward * 0.16), _navy],
				[Vector3(0.25, 0.018, 0.04), Vector3(0, 0.04, outward * 0.19), _cyan],
			]:
				var face := MeshInstance3D.new()
				var armor := BoxMesh.new()
				armor.size = layer[0]
				face.mesh = armor
				face.position = layer[1]
				face.material_override = layer[2]
				cap.add_child(face)
			var radial := point(angle).normalized()
			var normal := plane_normal()
			cap.transform = Transform3D(Basis(radial, normal, radial.cross(normal)), point(angle) + normal * 0.125)
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

func _add_load_channel(parent: Node3D, begin: float, finish: float) -> void:
	# A recessed, armored conduit follows the same physical arc as the deck.
	# Its dark floor and raised lips have depth at every phase.
	_add_strip(parent, begin, finish, 0.25, 0.388, _navy)
	_add_wall(parent, begin, finish, -0.125, 0.39, 0.51, _side)
	_add_wall(parent, begin, finish, 0.125, 0.39, 0.51, _side)

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
	return lerpf(_transit_width(angle), NODE_WIDTH, blend)

func _transit_width(angle: float) -> float:
	# The front load path carries the visible heavy deck; the rear transit
	# section is slimmer before it passes behind the globe.
	return lerpf(REAR_TRANSIT_WIDTH, FRONT_TRANSIT_WIDTH, 0.5 + 0.5 * sin(angle))

func _station_saddle_drop(angle: float) -> float:
	# A continuous local trough routes the real section below the station's
	# painted front armor; its keel, walls, conduit and joins descend together.
	var center: float = FACILITY_ANGLES["auto_explore"]
	return 0.30 * smoothstep(center - 0.21, center - 0.07, angle) * (1.0 - smoothstep(center + 0.06, center + 0.20, angle))

func _add_curved_deck(parent: Node3D, begin: float, finish: float, width: float, lift: float, material: Material, v_start: float = 0.0, v_end: float = 1.0, kind: String = "") -> void:
	# A continuous bevelled load-bearing surface, UV mapped to an authored
	# armor tile. Each independent quarter owns its whole physical arc.
	var profile := [
		Vector2(-0.50, 0.04), Vector2(-0.48, 0.11), Vector2(-0.43, 0.18),
		Vector2(-0.34, 0.215), Vector2(0.0, 0.23), Vector2(0.34, 0.215),
		Vector2(0.43, 0.18), Vector2(0.48, 0.11), Vector2(0.50, 0.04),
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
	# The deck's own center sinks to meet the structural conduit; both armor
	# shoulders remain part of the same continuous mesh.
	height -= 0.075 * (1.0 - smoothstep(0.11, 0.18, absf(current.x)))
	if kind != "":
		# Raise the load-bearing shell beside each work floor, leaving a recessed
		# center for the facility rather than resting a separate pad on the ring.
		var node_span := 1.0 - smoothstep(0.10, 0.29, absf(angle - FACILITY_ANGLES[kind]))
		var shoulder := smoothstep(0.19, 0.38, absf(current.x))
		height += 0.15 * node_span * shoulder
	if kind == "refinery":
		var distance := absf(angle - FACILITY_ANGLES[kind])
		var foot_span: float = 1.0 - smoothstep(0.080, 0.18, distance)
		var foot_width: float = 1.0 - smoothstep(0.30, 0.46, absf(current.x))
		var inlet: float = (1.0 - smoothstep(0.023, 0.053, distance)) * (1.0 - smoothstep(0.08, 0.15, absf(current.x - 0.04)))
		height += 0.18 * foot_span * foot_width * (1.0 - inlet) - 0.035 * inlet
	elif kind == "equipment":
		# The load cheeks are raised out of this very deck; the open center
		# remains the ring's own recessed work path through the orange portal.
		var bay_span := 1.0 - smoothstep(0.10, 0.24, absf(angle - FACILITY_ANGLES[kind]))
		var center_path := 1.0 - smoothstep(0.16, 0.32, absf(current.x))
		height += bay_span * (0.13 * (1.0 - center_path) - 0.045 * center_path)
	elif kind == "shipyard":
		# The original deck rises into the cantilevers' one vertical spine.
		var keel_span := 1.0 - smoothstep(0.055, 0.13, absf(angle - FACILITY_ANGLES[kind]))
		var keel_width := 1.0 - smoothstep(0.20, 0.39, absf(current.x + 0.10))
		height += 0.14 * keel_span * keel_width
	height -= _station_saddle_drop(angle)
	surface.add_vertex(point(angle) * ((RADIUS + current.x * width) / RADIUS) + plane_normal() * height)

func _add_strip(parent: Node3D, begin: float, finish: float, width: float, lift: float, material: Material, kind: String = "") -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var normal := plane_normal()
	var steps := maxi(24, ceili((finish - begin) * 96.0))
	for index in steps:
		var a := lerpf(begin, finish, float(index) / float(steps))
		var b := lerpf(begin, finish, float(index + 1) / float(steps))
		var wa := width + (_section_width(kind, a) - NODE_WIDTH if kind != "" else 0.0)
		var wb := width + (_section_width(kind, b) - NODE_WIDTH if kind != "" else 0.0)
		var ai := point(a) * ((RADIUS - wa * 0.5) / RADIUS) + normal * (lift - _station_saddle_drop(a))
		var ao := point(a) * ((RADIUS + wa * 0.5) / RADIUS) + normal * (lift - _station_saddle_drop(a))
		var bi := point(b) * ((RADIUS - wb * 0.5) / RADIUS) + normal * (lift - _station_saddle_drop(b))
		var bo := point(b) * ((RADIUS + wb * 0.5) / RADIUS) + normal * (lift - _station_saddle_drop(b))
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
		for vertex in [pa + normal * (bottom - _station_saddle_drop(a)), pb + normal * (bottom - _station_saddle_drop(b)), pa + normal * (top - _station_saddle_drop(a)), pa + normal * (top - _station_saddle_drop(a)), pb + normal * (bottom - _station_saddle_drop(b)), pb + normal * (top - _station_saddle_drop(b))]:
			surface.set_normal(wall_normal)
			surface.add_vertex(vertex)
	var instance := MeshInstance3D.new()
	instance.mesh = surface.commit()
	instance.material_override = material
	parent.add_child(instance)

func _add_mount(parent: Node3D, kind: String, angle: float) -> void:
	# Each built section owns the facility root on its continuous deck.
	_add_facility_socket(parent, kind, angle)
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

func _add_facility_socket(parent: Node3D, kind: String, angle: float) -> void:
	# The three working facilities carry their load collars in their authored
	# root artwork. The station alone retains its existing circular dock.
	if kind == "auto_explore":
		return
	if kind == "refinery":
		_add_refinery_root(parent, angle)
	# The workshop's own two-mouth structural shell now straddles this deck.

func _add_refinery_root(parent: Node3D, angle: float) -> void:
	# The feed trough and both load cheeks are one ring-owned receiver. Its
	# distal tread meets the fixed deck socket while its upper end enters the
	# open port of the separate camera-facing furnace shell.
	var tip := refinery_feed_tip()
	var upper := _refinery_unaimed_feed_top()
	_refinery_receiver_vector = upper - tip
	_refinery_receiver = Node3D.new()
	_refinery_receiver.name = "RefineryReceiver"
	_refinery_receiver.position = tip
	parent.add_child(_refinery_receiver)
	var tangent := (point(angle + 0.001) - point(angle - 0.001)).normalized()
	var up := plane_normal()
	var belt := SurfaceTool.new()
	belt.begin(Mesh.PRIMITIVE_TRIANGLES)
	for step in 6:
		var t0 := float(step) / 6.0
		var t1 := float(step + 1) / 6.0
		var p0 := tip.lerp(upper, t0) - tip
		var p1 := tip.lerp(upper, t1) - tip
		var l0 := p0 - tangent * 0.100
		var r0 := p0 + tangent * 0.100
		var l1 := p1 - tangent * 0.100
		var r1 := p1 + tangent * 0.100
		_add_receiver_quad(belt, l0, l1, r0, r1, up, t0, t1)
	var tread := MeshInstance3D.new()
	tread.name = "RefineryRootTread"
	tread.mesh = belt.commit()
	tread.material_override = _deck
	_refinery_receiver.add_child(tread)
	for side in [-1.0, 1.0]:
		var rail := SurfaceTool.new()
		var inner_wall := SurfaceTool.new()
		rail.begin(Mesh.PRIMITIVE_TRIANGLES)
		inner_wall.begin(Mesh.PRIMITIVE_TRIANGLES)
		for step in 6:
			var t0 := float(step) / 6.0
			var t1 := float(step + 1) / 6.0
			var p0 := tip.lerp(upper, t0) - tip
			var p1 := tip.lerp(upper, t1) - tip
			var inner0 := p0 + tangent * float(side) * 0.100
			var inner1 := p1 + tangent * float(side) * 0.100
			var outer0 := p0 + tangent * float(side) * 0.145
			var outer1 := p1 + tangent * float(side) * 0.145
			_add_receiver_quad(rail, inner0 + up * 0.145, inner1 + up * 0.145, outer0 + up * 0.145, outer1 + up * 0.145, up, t0, t1)
			_add_receiver_quad(inner_wall, inner0, inner1, inner0 + up * 0.145, inner1 + up * 0.145, tangent * -float(side), t0, t1)
		var rail_mesh := MeshInstance3D.new()
		rail_mesh.name = "RefineryRootCheek" + str(side)
		rail_mesh.mesh = rail.commit()
		rail_mesh.material_override = _deck
		_refinery_receiver.add_child(rail_mesh)
		var wall_mesh := MeshInstance3D.new()
		wall_mesh.name = "RefineryRootInnerWall" + str(side)
		wall_mesh.mesh = inner_wall.commit()
		wall_mesh.material_override = _side
		_refinery_receiver.add_child(wall_mesh)

func _add_receiver_quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, t0: float, t1: float) -> void:
	for entry in [[a, Vector2(0.46, t0)], [b, Vector2(0.46, t1)], [c, Vector2(0.54, t0)], [c, Vector2(0.54, t0)], [b, Vector2(0.46, t1)], [d, Vector2(0.54, t1)]]:
		surface.set_normal(normal)
		surface.set_uv(entry[1])
		surface.add_vertex(entry[0])

func _add_join(parent: Node3D, angle: float) -> Node3D:
	# Covers the armor gap where two independently built sections mate. This
	# collar is owned by the preceding section and appears only after both exist.
	var join := Node3D.new()
	join.name = "SectionJoin"
	parent.add_child(join)
	var joint_width := _transit_width(angle) + 0.02
	# Close the complete load path, including its keel and lit outer wall. A
	# top-only sleeve leaves an obvious open cut at oblique orbital phases.
	_add_strip(join, angle - 0.12, angle + 0.12, joint_width, -0.20, _navy)
	_add_wall(join, angle - 0.12, angle + 0.12, joint_width * 0.5, -0.42, 0.26, _navy)
	_add_wall(join, angle - 0.12, angle + 0.12, -joint_width * 0.5, -0.42, 0.26, _navy)
	_add_wall(join, angle - 0.12, angle + 0.12, joint_width * 0.5 + 0.005, 0.08, 0.18, _side)
	_add_wall(join, angle - 0.12, angle + 0.12, joint_width * 0.5 + 0.008, -0.22, -0.16, _cyan)
	_add_curved_deck(join, angle - 0.12, angle + 0.12, joint_width, 0.232, _sleeve, 0.37, 0.63)
	_add_load_channel(join, angle - 0.12, angle + 0.12)
	return join

func configure(owned: Array) -> void:
	_owned = owned.duplicate()
	for kind in KINDS:
		_arcs[kind].visible = kind in _owned
		var index := KINDS.find(kind)
		_joins[kind].visible = kind in _owned and KINDS[(index + 1) % KINDS.size()] in _owned
		var caps: Array = _end_caps[kind]
		caps[0].visible = kind != "auto_explore" and KINDS[(index + KINDS.size() - 1) % KINDS.size()] not in _owned
		# The refinery shell itself encloses its nearby free end. An exposed
		# terminal there reads as an unrelated block hanging below the furnace.
		caps[1].visible = kind != "refinery" and KINDS[(index + 1) % KINDS.size()] not in _owned

func update_pose(clock: float) -> void:
	basis = Basis(Vector3(0.0, -TILT_Z, -TILT_Y), clock * 0.045)
