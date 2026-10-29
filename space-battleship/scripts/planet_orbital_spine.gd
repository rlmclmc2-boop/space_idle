extends Node3D
## Four owned, load-bearing orbital sections share one tilted plane. Their rear
## geometry continues behind the planet's depth mask instead of ending there.
const KINDS := ["auto_explore", "refinery", "equipment", "shipyard"]
const ARC_BOUNDS := {
	"auto_explore": Vector2(PI, PI * 1.5),
	"refinery": Vector2(PI * 1.5, TAU),
	"equipment": Vector2(0.0, PI * 0.5),
	"shipyard": Vector2(PI * 0.5, PI),
}
const FACILITY_ANGLES := {
	"auto_explore": PI * 1.09,
	"refinery": TAU - 0.25,
	"equipment": 0.42,
	"shipyard": PI - 0.42,
}
const RADIUS := 4.5
const TILT_Y := 0.72
const TILT_Z := 0.694
const DECK_HEIGHT := 0.16
const SOCKET_HEIGHT := 0.65
var _arcs: Dictionary = {}
var _end_caps: Dictionary = {}
var _joins: Dictionary = {}
var _owned: Array = []
var _navy: StandardMaterial3D
var _side: StandardMaterial3D
var _armor: StandardMaterial3D
var _cyan: StandardMaterial3D
var _deck: StandardMaterial3D

static func plane_normal() -> Vector3:
	return Vector3(0.0, TILT_Z, TILT_Y)

static func point(angle: float) -> Vector3:
	return Vector3(RADIUS * cos(angle), -RADIUS * TILT_Y * sin(angle), RADIUS * TILT_Z * sin(angle))

static func socket_position(angle: float) -> Vector3:
	return point(angle) + plane_normal() * SOCKET_HEIGHT

func _ready() -> void:
	_navy = _material(Color("152f43"))
	_side = _material(Color("36566a"))
	_armor = _material(Color("d4d0c0"))
	_cyan = _material(Color("4cb9c2"), true)
	_deck = _material(Color.WHITE)
	_deck.albedo_texture = preload("res://assets/planets/orbital_spine/deck-albedo.png")
	_deck.roughness = 0.68
	_deck.metallic = 0.10
	_deck.emission_enabled = true
	_deck.emission_texture = _deck.albedo_texture
	_deck.emission = Color.WHITE
	_deck.emission_energy_multiplier = 0.45
	for kind in KINDS:
		var root := Node3D.new()
		root.name = kind + "SpineSection"
		add_child(root)
		var bounds: Vector2 = ARC_BOUNDS[kind]
		# A real thick section: dark keel and side walls remain visible under
		# broad warm armor plates. The central channel belongs to this section.
		_add_strip(root, bounds.x, bounds.y, 1.06, -0.18, _navy)
		_add_wall(root, bounds.x, bounds.y, 0.53, -0.18, 0.05, _side)
		_add_wall(root, bounds.x, bounds.y, -0.53, -0.18, 0.05, _navy)
		_add_wall(root, bounds.x, bounds.y, 0.535, -0.035, 0.005, _cyan)
		_add_curved_deck(root, bounds.x, bounds.y, 1.06, 0.0, _deck)
		var rib_angle := (bounds.x + bounds.y) * 0.5
		_add_curved_deck(root, rib_angle - 0.024, rib_angle + 0.024, 1.09, 0.016, _side)
		_add_mount(root, FACILITY_ANGLES[kind])
		_joins[kind] = _add_join(root, bounds.y)
		var caps: Array[MeshInstance3D] = []
		for angle in [bounds.x, bounds.y]:
			var cap := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.22, 0.20, 0.22)
			cap.mesh = box
			cap.material_override = _navy
			cap.position = point(angle)
			root.add_child(cap)
			caps.append(cap)
		_arcs[kind] = root
		_end_caps[kind] = caps
		root.visible = false

func _material(color: Color, unshaded: bool = false) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = Color(color, 0.999)
	result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	result.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if unshaded else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	result.roughness = 0.72
	result.metallic = 0.08
	return result

func _add_curved_deck(parent: Node3D, begin: float, finish: float, width: float, lift: float, material: Material, v_start: float = 0.0, v_end: float = 1.0) -> void:
	# A continuous bevelled load-bearing surface, UV mapped to an authored
	# armor tile. Each independent quarter owns its whole physical arc.
	var profile := [
		Vector2(-0.50, 0.04), Vector2(-0.48, 0.11), Vector2(-0.43, 0.18),
		Vector2(-0.34, 0.215), Vector2(0.0, 0.23), Vector2(0.34, 0.215),
		Vector2(0.43, 0.18), Vector2(0.48, 0.11), Vector2(0.50, 0.04),
	]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := maxi(48, ceili((finish - begin) * 96.0))
	for index in steps:
		var t0 := float(index) / float(steps)
		var t1 := float(index + 1) / float(steps)
		var a := lerpf(begin, finish, t0)
		var b := lerpf(begin, finish, t1)
		for band in profile.size() - 1:
			_deck_vertex(surface, profile, band, a, t0, width, lift, v_start, v_end)
			_deck_vertex(surface, profile, band, b, t1, width, lift, v_start, v_end)
			_deck_vertex(surface, profile, band + 1, a, t0, width, lift, v_start, v_end)
			_deck_vertex(surface, profile, band + 1, a, t0, width, lift, v_start, v_end)
			_deck_vertex(surface, profile, band, b, t1, width, lift, v_start, v_end)
			_deck_vertex(surface, profile, band + 1, b, t1, width, lift, v_start, v_end)
	var instance := MeshInstance3D.new()
	instance.mesh = surface.commit()
	instance.material_override = material
	parent.add_child(instance)

func _deck_vertex(surface: SurfaceTool, profile: Array, index: int, angle: float, t: float, width: float, lift: float, v_start: float, v_end: float) -> void:
	var current: Vector2 = profile[index]
	var before: Vector2 = profile[maxi(0, index - 1)]
	var after: Vector2 = profile[mini(profile.size() - 1, index + 1)]
	var slope := (after.y - before.y) / ((after.x - before.x) * width)
	var radial := point(angle).normalized()
	var normal := (plane_normal() - radial * slope).normalized()
	surface.set_normal(normal)
	surface.set_uv(Vector2(current.x + 0.5, lerpf(v_start, v_end, t)))
	surface.add_vertex(point(angle) * ((RADIUS + current.x * width) / RADIUS) + plane_normal() * (lift + current.y))

func _add_strip(parent: Node3D, begin: float, finish: float, width: float, lift: float, material: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var normal := plane_normal()
	var steps := maxi(24, ceili((finish - begin) * 96.0))
	for index in steps:
		var a := lerpf(begin, finish, float(index) / float(steps))
		var b := lerpf(begin, finish, float(index + 1) / float(steps))
		var ai := point(a) * ((RADIUS - width * 0.5) / RADIUS) + normal * lift
		var ao := point(a) * ((RADIUS + width * 0.5) / RADIUS) + normal * lift
		var bi := point(b) * ((RADIUS - width * 0.5) / RADIUS) + normal * lift
		var bo := point(b) * ((RADIUS + width * 0.5) / RADIUS) + normal * lift
		for vertex in [ai, bi, ao, ao, bi, bo]:
			surface.set_normal(normal)
			surface.add_vertex(vertex)
	var instance := MeshInstance3D.new()
	instance.mesh = surface.commit()
	instance.material_override = material
	parent.add_child(instance)

func _add_wall(parent: Node3D, begin: float, finish: float, radial: float, bottom: float, top: float, material: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var normal := plane_normal()
	var steps := maxi(24, ceili((finish - begin) * 96.0))
	for index in steps:
		var a := lerpf(begin, finish, float(index) / float(steps))
		var b := lerpf(begin, finish, float(index + 1) / float(steps))
		var pa := point(a) * ((RADIUS + radial) / RADIUS)
		var pb := point(b) * ((RADIUS + radial) / RADIUS)
		var wall_normal := (pa + pb).normalized() * signf(radial)
		for vertex in [pa + normal * bottom, pb + normal * bottom, pa + normal * top, pa + normal * top, pb + normal * bottom, pb + normal * top]:
			surface.set_normal(wall_normal)
			surface.add_vertex(vertex)
	var instance := MeshInstance3D.new()
	instance.mesh = surface.commit()
	instance.material_override = material
	parent.add_child(instance)

func _add_mount(parent: Node3D, angle: float) -> void:
	# The facility owns this widened saddle and its two dark load collars.
	# It arrives with the facility even if every other section is unbuilt.
	_add_strip(parent, angle - 0.23, angle + 0.23, 1.48, -0.20, _navy)
	_add_wall(parent, angle - 0.23, angle + 0.23, 0.74, -0.20, 0.26, _side)
	_add_wall(parent, angle - 0.23, angle + 0.23, -0.74, -0.20, 0.26, _navy)
	_add_wall(parent, angle - 0.23, angle + 0.23, 0.745, 0.05, 0.09, _cyan)
	_add_curved_deck(parent, angle - 0.23, angle + 0.23, 1.48, 0.22, _deck, 0.28, 0.72)
	for edge in [angle - 0.23, angle + 0.23]:
		_add_strip(parent, edge - 0.018, edge + 0.018, 1.52, 0.44, _side)
	var pedestal := MeshInstance3D.new()
	var drum := CylinderMesh.new()
	drum.top_radius = 0.36
	drum.bottom_radius = 0.42
	drum.height = 0.20
	pedestal.mesh = drum
	pedestal.material_override = _navy
	pedestal.position = point(angle) + plane_normal() * 0.52
	pedestal.basis = Basis(Quaternion(Vector3.UP, plane_normal()))
	parent.add_child(pedestal)
	# One restrained amber status light makes the saddle read as equipment,
	# without introducing another buildable node.
	var lamp := MeshInstance3D.new()
	var lens := SphereMesh.new()
	lens.radius = 0.055
	lens.height = 0.11
	lamp.mesh = lens
	lamp.material_override = _material(Color("d5a661"), true)
	lamp.position = point(angle) * ((RADIUS + 0.57) / RADIUS) + plane_normal() * 0.48
	parent.add_child(lamp)

func _add_join(parent: Node3D, angle: float) -> Node3D:
	# Covers the armor gap where two independently built sections mate. This
	# collar is owned by the preceding section and appears only after both exist.
	var join := Node3D.new()
	join.name = "SectionJoin"
	parent.add_child(join)
	_add_strip(join, angle - 0.052, angle + 0.052, 1.04, 0.18, _side)
	_add_strip(join, angle - 0.030, angle + 0.030, 0.76, 0.205, _armor)
	_add_strip(join, angle - 0.032, angle + 0.032, 0.075, 0.220, _cyan)
	var coupling := MeshInstance3D.new()
	var drum := CylinderMesh.new()
	drum.top_radius = 0.22
	drum.bottom_radius = 0.29
	drum.height = 0.14
	coupling.mesh = drum
	coupling.material_override = _side
	coupling.position = point(angle) + plane_normal() * 0.29
	coupling.basis = Basis(Quaternion(Vector3.UP, plane_normal()))
	join.add_child(coupling)
	var indicator := MeshInstance3D.new()
	var disk := CylinderMesh.new()
	disk.top_radius = 0.115
	disk.bottom_radius = 0.115
	disk.height = 0.025
	indicator.mesh = disk
	indicator.material_override = _cyan
	indicator.position = point(angle) + plane_normal() * 0.38
	indicator.basis = coupling.basis
	join.add_child(indicator)
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
