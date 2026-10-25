extends Node2D
var _battle
var kernel
var native_display
var beam_rows: Array = []
var beam_instances: MultiMeshInstance2D
var beam_material: ShaderMaterial
var contact_layer: Node2D

func _init(battle) -> void:
	_battle = battle
	kernel = battle.native_owner()
	process_priority = 1

func _ready() -> void:
	_setup_native_display()

func _process(_dt: float) -> void:
	if not _battle.presentation_active(): return
	if native_display != null:
		native_display.advance_visuals()
		for event in _battle.events():
			if int(event.kind) in [0, 1]:
				native_display.record_contact(0 if event.get("hostile", false) else 1, event.position, event.direction,
					float(event.clock), int(event.kind) == 0, bool(event.critical), int(event.type))
		native_display.prune_contacts(float(kernel.presentation_clock()))
		contact_layer.queue_redraw()
	queue_redraw()

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	beam_rows.clear()
	if beam_instances != null:
		beam_instances.multimesh.visible_instance_count = 0
	if native_display != null:
		var prepared = native_display.prepare_flights(Vector2.ZERO)
		native_display.draw_flights(prepared, Vector2.ZERO)
		_upload_beams()
	var player_hull: PackedVector2Array = _battle.player_hull()
	if player_hull.size() >= 3:
		draw_colored_polygon(player_hull, Color("66d9dc"))
	var enemies: Array = kernel.enemy_views()
	var hulls: Array = _battle.enemy_hulls()
	for index in enemies.size():
		var actor: Dictionary = enemies[index]
		if actor.get("dead", false) or index >= hulls.size():
			continue
		var hull: PackedVector2Array = hulls[index]
		if hull.size() >= 3:
			draw_colored_polygon(hull, Color("ce6978"))
		draw_string(font, Vector2(float(actor.x) - 24, float(actor.y) + 35), str(actor.hp), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("f1d9dc"))
	var history: Dictionary = kernel.read_history()
	draw_string(font, Vector2(18, 53), "攻击 %s   来袭 %s" % [history.attacks, history.incoming], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("a9c6db"))
	var player: Dictionary = kernel.player_view()
	draw_string(font, Vector2(18, 765), "装甲 %s   护盾 %s" % [player.armour, player.shield], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("b8ede6"))

func _draw_contacts() -> void:
	if native_display != null:
		native_display.draw_contacts(float(kernel.presentation_clock()))

func _setup_native_display() -> void:
	native_display = ClassDB.instantiate("SpaceCombatPresentation")
	var retained := ShaderMaterial.new()
	retained.shader = load("res://shaders/retained_flights.gdshader")
	var pulse := Image.load_from_file("res://assets/weapons/laser-pulse.png")
	if pulse != null and not pulse.is_empty():
		retained.set_shader_parameter("pulse_texture", ImageTexture.create_from_image(pulse))
	native_display.configure_retained_gpu(retained)
	contact_layer = Node2D.new()
	contact_layer.z_index = 2
	contact_layer.draw.connect(_draw_contacts)
	add_child(contact_layer)
	var contacts := ShaderMaterial.new()
	contacts.shader = load("res://shaders/gpu_contacts.gdshader")
	var topology = load("res://scripts/gpu_contact_mesh.gd")
	native_display.configure_contact_gpu([topology.build(0), topology.build(1)], contact_layer.get_canvas_item(), contacts)
	beam_material = ShaderMaterial.new()
	beam_material.shader = load("res://shaders/retained_beams.gdshader")
	var mesh := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3(1, 1, 0), Vector3.ZERO, Vector3(1, 1, 0), Vector3.UP])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.ZERO, Vector2.ONE, Vector2.DOWN])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.custom_aabb = AABB(Vector3(-8192, -8192, -1), Vector3(16384, 16384, 2))
	beam_instances = MultiMeshInstance2D.new()
	beam_instances.z_index = 1
	beam_instances.material = beam_material
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_2D
	instances.use_colors = true
	instances.use_custom_data = true
	instances.mesh = mesh
	beam_instances.multimesh = instances
	add_child(beam_instances)
	native_display.configure_surface(kernel, get_canvas_item(), _collect_beams)

func _collect_beams(segments: Array) -> void:
	beam_rows.append_array(segments)

func _upload_beams() -> void:
	if beam_instances == null:
		return
	var mesh: MultiMesh = beam_instances.multimesh
	mesh.instance_count = beam_rows.size()
	mesh.visible_instance_count = beam_rows.size()
	beam_material.set_shader_parameter("clock", fmod(float(kernel.presentation_clock()), 128.0))
	for i in beam_rows.size():
		var row: Dictionary = beam_rows[i]
		var delta: Vector2 = row.to - row.from
		mesh.set_instance_transform_2d(i, Transform2D(delta.angle(), row.from))
		mesh.set_instance_color(i, Color(delta.length(), -1.0, delta.angle(), 1.0 if row.link else 0.0))
		mesh.set_instance_custom_data(i, Color(1.0, row.power, 0.0, row.charge))
