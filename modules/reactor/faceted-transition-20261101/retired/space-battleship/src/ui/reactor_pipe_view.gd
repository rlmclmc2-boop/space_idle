extends Control
## One physical conduit. Source geometry is shared; endpoints/tangents vary.
const SOURCE_SIZE := Vector2(1187.0, 1326.0)
const VIEW_SIZE := Vector2(808.0, 835.0)
const LUMEN := preload("res://assets/ui/reactor/b01/modular-pipe-lumen.gdshader")
const PortContract = preload("res://src/ui/reactor_port_contract.gd")

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
	assert(PortContract.device(id).has("device_port"))
	for child in get_children(): child.queue_free()
	var spec: Dictionary = PortContract.device(id)
	_shell = _texture_layer("res://assets/ui/reactor/b01/modular-pipe-%s-shell.png" % id,
		Vector2(spec.pipe_shell_rect[0],spec.pipe_shell_rect[1]))
	_lumen = MeshInstance2D.new()
	_lumen.mesh = _arc_mesh(PortContract.route(id),spec)
	_light = ShaderMaterial.new()
	_light.shader = LUMEN
	_lumen.material = _light
	_lumen.visible = false
	add_child(_lumen)
	_front = _texture_layer("res://assets/ui/reactor/b01/modular-pipe-%s-front.png" % id,
		Vector2(spec.pipe_front_rect[0],spec.pipe_front_rect[1]))

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

static func _arc_mesh(route: Array, spec: Dictionary) -> ArrayMesh:
	const STEPS := 96
	var pts := PackedVector2Array()
	var lengths := PackedFloat32Array()
	var length := 0.0
	for i in range(STEPS+1):
		var p := _curve(route, float(i)/STEPS)
		if i > 0: length += p.distance_to(pts[i-1])
		pts.append(p)
		lengths.append(length)
	var axis := Vector2(spec.axis_to_device[0],spec.axis_to_device[1]).normalized()
	for i in range(1,13):
		var p: Vector2 = route[3] + axis*float(spec.insert_depth)*float(i)/12.0
		length += p.distance_to(pts[-1])
		pts.append(p)
		lengths.append(length)
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var scale := VIEW_SIZE / SOURCE_SIZE
	for i in range(pts.size()):
		var prev: Vector2 = pts[maxi(0,i-1)]
		var next: Vector2 = pts[mini(pts.size()-1,i+1)]
		var tangent := (next-prev).normalized()
		var normal := Vector2(-tangent.y,tangent.x)
		for side in [-1.0,1.0]:
			var p: Vector2 = (pts[i]+normal*9.0*side)*scale
			vertices.append(Vector3(p.x,p.y,0.0))
			uvs.append(Vector2(lengths[i]/maxf(length,0.001),(side+1.0)*0.5))
		if i < pts.size()-1:
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
