extends Node3D
## Four owned structural arcs share one tilted orbital plane. Hidden rear spans
## remain real geometry; the planet depth mask, not a cut in the mesh, occludes them.
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
var _arcs: Dictionary = {}
var _end_caps: Dictionary = {}
var _owned: Array = []
var _ivory: StandardMaterial3D
var _navy: StandardMaterial3D
var _cyan: StandardMaterial3D

static func point(angle: float) -> Vector3:
	return Vector3(RADIUS * cos(angle), -RADIUS * TILT_Y * sin(angle), RADIUS * TILT_Z * sin(angle))

func _ready() -> void:
	_navy = _material(Color("17364b"))
	_ivory = _material(Color("aabcc3"))
	_cyan = _material(Color("4db3bf"))
	for kind in KINDS:
		var root := Node3D.new()
		root.name = kind + "SpineSection"
		add_child(root)
		var bounds: Vector2 = ARC_BOUNDS[kind]
		_add_strip(root, bounds.x, bounds.y, 0.64, 0.0, _navy)
		_add_strip(root, bounds.x, bounds.y, 0.49, 0.025, _ivory)
		_add_strip(root, bounds.x, bounds.y, 0.045, 0.052, _cyan)
		var caps: Array[MeshInstance3D] = []
		for angle in [bounds.x, bounds.y]:
			var cap := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.22, 0.10, 0.22)
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
	var normal := Vector3(0.0, TILT_Z, TILT_Y)
	for index in 32:
		var a := lerpf(begin, finish, float(index) / 32.0)
		var b := lerpf(begin, finish, float(index + 1) / 32.0)
		var a_inner := point(a) * ((RADIUS - width * 0.5) / RADIUS) + normal * lift
		var a_outer := point(a) * ((RADIUS + width * 0.5) / RADIUS) + normal * lift
		var b_inner := point(b) * ((RADIUS - width * 0.5) / RADIUS) + normal * lift
		var b_outer := point(b) * ((RADIUS + width * 0.5) / RADIUS) + normal * lift
		for vertex in [a_inner, b_inner, a_outer, a_outer, b_inner, b_outer]:
			surface.set_normal(normal)
			surface.add_vertex(vertex)
	var mesh := surface.commit()
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)

func configure(owned: Array) -> void:
	_owned = owned.duplicate()
	for kind in KINDS:
		_arcs[kind].visible = kind in _owned
		var index := KINDS.find(kind)
		var caps: Array = _end_caps[kind]
		caps[0].visible = KINDS[(index + KINDS.size() - 1) % KINDS.size()] not in _owned
		caps[1].visible = KINDS[(index + 1) % KINDS.size()] not in _owned

func update_pose(clock: float) -> void:
	# The whole built structure turns around its plane normal, independently of
	# the shader-driven surface and the exploration ship's separate orbit.
	basis = Basis(Vector3(0.0, -TILT_Z, -TILT_Y), clock * 0.045)
