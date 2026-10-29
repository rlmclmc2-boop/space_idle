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
	_cyan = _material(Color("4cb9c2"))
	for kind in KINDS:
		var root := Node3D.new()
		root.name = kind + "SpineSection"
		add_child(root)
		var bounds: Vector2 = ARC_BOUNDS[kind]
		# A real thick section: dark keel and side walls remain visible under
		# broad warm armor plates. The central channel belongs to this section.
		_add_strip(root, bounds.x, bounds.y, 0.94, -0.18, _navy)
		_add_wall(root, bounds.x, bounds.y, 0.47, -0.18, 0.08, _side)
		_add_wall(root, bounds.x, bounds.y, -0.47, -0.18, 0.08, _navy)
		_add_strip(root, bounds.x, bounds.y, 0.94, 0.08, _navy)
		for plate_index in 4:
			var start := lerpf(bounds.x, bounds.y, float(plate_index) / 4.0) + 0.018
			var end := lerpf(bounds.x, bounds.y, float(plate_index + 1) / 4.0) - 0.018
			_add_strip(root, start, end, 0.76, DECK_HEIGHT, _armor)
		_add_strip(root, bounds.x, bounds.y, 0.075, DECK_HEIGHT + 0.014, _cyan)
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

func _material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = Color(color, 0.999)
	result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	result.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return result

func _add_strip(parent: Node3D, begin: float, finish: float, width: float, lift: float, material: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var normal := plane_normal()
	for index in 24:
		var a := lerpf(begin, finish, float(index) / 24.0)
		var b := lerpf(begin, finish, float(index + 1) / 24.0)
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
	for index in 32:
		var a := lerpf(begin, finish, float(index) / 32.0)
		var b := lerpf(begin, finish, float(index + 1) / 32.0)
		var pa := point(a) * ((RADIUS + radial) / RADIUS)
		var pb := point(b) * ((RADIUS + radial) / RADIUS)
		for vertex in [pa + normal * bottom, pb + normal * bottom, pa + normal * top, pa + normal * top, pb + normal * bottom, pb + normal * top]:
			surface.add_vertex(vertex)
	var instance := MeshInstance3D.new()
	instance.mesh = surface.commit()
	instance.material_override = material
	parent.add_child(instance)

func _add_mount(parent: Node3D, angle: float) -> void:
	# The facility owns this widened saddle and its two dark load collars.
	# It arrives with the facility even if every other section is unbuilt.
	_add_strip(parent, angle - 0.23, angle + 0.23, 1.48, 0.18, _navy)
	_add_wall(parent, angle - 0.23, angle + 0.23, 0.74, -0.20, 0.38, _side)
	_add_wall(parent, angle - 0.23, angle + 0.23, -0.74, -0.20, 0.38, _navy)
	_add_strip(parent, angle - 0.19, angle + 0.19, 1.30, 0.42, _armor)
	_add_strip(parent, angle - 0.19, angle + 0.19, 0.08, 0.435, _cyan)
	for edge in [angle - 0.23, angle + 0.23]:
		_add_strip(parent, edge - 0.022, edge + 0.022, 1.52, 0.445, _navy)
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

func _add_join(parent: Node3D, angle: float) -> Node3D:
	# Covers the armor gap where two independently built sections mate. This
	# collar is owned by the preceding section and appears only after both exist.
	var join := Node3D.new()
	join.name = "SectionJoin"
	parent.add_child(join)
	_add_strip(join, angle - 0.052, angle + 0.052, 1.04, 0.18, _side)
	_add_strip(join, angle - 0.030, angle + 0.030, 0.76, 0.205, _armor)
	_add_strip(join, angle - 0.032, angle + 0.032, 0.075, 0.220, _cyan)
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
