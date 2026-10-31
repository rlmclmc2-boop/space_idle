extends Control
## One physical conduit. Source geometry is shared; endpoints/tangents vary.
const SOURCE_SIZE := Vector2(1187.0, 1326.0)
const VIEW_SIZE := Vector2(808.0, 835.0)
const LUMEN := preload("res://assets/ui/reactor/b01/modular-pipe-lumen.gdshader")
const ROUTES := {
	"weapons": [Vector2(448,249), Vector2(408,220), Vector2(370,195), Vector2(318,208)],
	"defence": [Vector2(741,247), Vector2(789,205), Vector2(848,184), Vector2(916,199)],
	"smelting": [Vector2(463,450), Vector2(410,479), Vector2(360,533), Vector2(313,517)],
	"condensation": [Vector2(729,446), Vector2(776,482), Vector2(819,530), Vector2(889,518)],
}
const PIPE_BOUNDS := {
	"weapons": {"shell":Vector2(311,175), "front":Vector2(310,172)},
	"defence": {"shell":Vector2(722,165), "front":Vector2(719,161)},
	"smelting": {"shell":Vector2(303,425), "front":Vector2(302,420)},
	"condensation": {"shell":Vector2(712,424), "front":Vector2(709,419)},
}

var _shell: Sprite2D
var _front: Sprite2D
var _lumen: MeshInstance2D
var _light: ShaderMaterial
var _load: float = 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = VIEW_SIZE
	set_process(false)

func configure(id: String) -> void:
	assert(ROUTES.has(id))
	for child in get_children(): child.queue_free()
	_shell = _texture_layer("res://assets/ui/reactor/b01/modular-pipe-%s-shell.png" % id, PIPE_BOUNDS[id].shell)
	_lumen = MeshInstance2D.new()
	_lumen.mesh = _arc_mesh(ROUTES[id])
	_light = ShaderMaterial.new()
	_light.shader = LUMEN
	_lumen.material = _light
	_lumen.visible = false
	add_child(_lumen)
	_front = _texture_layer("res://assets/ui/reactor/b01/modular-pipe-%s-front.png" % id, PIPE_BOUNDS[id].front)

func set_workload(value: float) -> void:
	_load = clampf(value, 0.0, 1.0)
	_lumen.visible = _load > 0.0
	_light.set_shader_parameter("load_fraction", _load)

func set_visual_phase(value: float) -> void:
	if _load > 0.0:
		_light.set_shader_parameter("phase", value)

func _texture_layer(path: String, source_position: Vector2) -> Sprite2D:
	var layer := Sprite2D.new()
	layer.texture = load(path)
	layer.centered = false
	layer.position = source_position * VIEW_SIZE / SOURCE_SIZE
	layer.scale = VIEW_SIZE / SOURCE_SIZE
	add_child(layer)
	return layer

static func _curve(p: Array, t: float) -> Vector2:
	var u := 1.0-t
	return p[0]*u*u*u + p[1]*3.0*u*u*t + p[2]*3.0*u*t*t + p[3]*t*t*t

static func _arc_mesh(route: Array) -> ArrayMesh:
	const STEPS := 96
	var pts := PackedVector2Array()
	var lengths := PackedFloat32Array()
	var length := 0.0
	for i in range(STEPS+1):
		var p := _curve(route, float(i)/STEPS)
		if i > 0: length += p.distance_to(pts[i-1])
		pts.append(p)
		lengths.append(length)
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var scale := VIEW_SIZE / SOURCE_SIZE
	for i in range(STEPS+1):
		var prev: Vector2 = pts[maxi(0,i-1)]
		var next: Vector2 = pts[mini(STEPS,i+1)]
		var tangent := (next-prev).normalized()
		var normal := Vector2(-tangent.y,tangent.x)
		for side in [-1.0,1.0]:
			var p: Vector2 = (pts[i]+normal*7.5*side)*scale
			vertices.append(Vector3(p.x,p.y,0.0))
			uvs.append(Vector2(lengths[i]/maxf(length,0.001),(side+1.0)*0.5))
		if i < STEPS:
			var k := i*2
			indices.append_array(PackedInt32Array([k,k+1,k+2,k+1,k+3,k+2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh
