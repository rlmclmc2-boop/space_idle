extends Node2D
signal damage_received
var _battle
var beam_rows: Array = []
var beam_instances: MultiMeshInstance2D
var beam_material: ShaderMaterial
var contact_layer: Node2D
var damage_mode: String = "all"
var damage_labels: Array = []

func _init(battle) -> void:
	_battle = battle
	process_priority = 1

func _ready() -> void:
	_setup_native_display()

func _exit_tree() -> void:
	_battle.release_presentation()

func _process(_dt: float) -> void:
	if not _battle.presentation_active(): return
	_battle.advance_presentation()
	var receipts: Array = _battle.consume_damage_receipts()
	if not receipts.is_empty(): damage_received.emit()
	for receipt in receipts:
		if damage_mode == "off" or damage_mode == "critical" and not receipt.critical: continue
		if damage_labels.size() >= 48: break
		damage_labels.append({"text": str(receipt.damage), "position": receipt.position,
			"expires": _battle.presentation_clock() + 0.8, "critical": receipt.critical,
			"hostile": receipt.hostile})
	var now: float = _battle.presentation_clock()
	damage_labels = damage_labels.filter(func(label): return label.expires > now)
	contact_layer.queue_redraw()
	queue_redraw()

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	beam_rows.clear()
	if beam_instances != null:
		beam_instances.multimesh.visible_instance_count = 0
	_battle.draw_presentation_flights()
	_upload_beams()
	_battle.draw_player_hull(self, Color("66d9dc"))
	_battle.draw_enemy_overlays(self, font)
	for label in damage_labels:
		var colour := Color("ff8a85") if label.hostile else Color("ffe78f") if label.critical else Color("e6f7f0")
		var lift: float = (label.expires - _battle.presentation_clock()) * 22.0
		draw_string(font, label.position - Vector2(55, 15 + lift), label.text,
			HORIZONTAL_ALIGNMENT_CENTER, 110, 16, colour)
	var hud: Dictionary = _battle.hud_values()
	draw_string(font, Vector2(18, 53), "攻击 %s   来袭 %s" % [hud.attacks, hud.incoming], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("a9c6db"))
	draw_string(font, Vector2(18, 765), "装甲 %s   护盾 %s" % [hud.armour, hud.shield], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("b8ede6"))

func _draw_contacts() -> void:
	_battle.draw_presentation_contacts()

func _setup_native_display() -> void:
	var retained := ShaderMaterial.new()
	retained.shader = load("res://shaders/retained_flights.gdshader")
	var pulse := load("res://assets/weapons/laser-pulse.png") as Texture2D
	if pulse != null:
		retained.set_shader_parameter("pulse_texture", pulse)
	contact_layer = Node2D.new()
	contact_layer.z_index = 2
	contact_layer.draw.connect(_draw_contacts)
	add_child(contact_layer)
	var contacts := ShaderMaterial.new()
	contacts.shader = load("res://shaders/gpu_contacts.gdshader")
	var topology = load("res://scripts/gpu_contact_mesh.gd")
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
	_battle.configure_presentation(retained, [topology.build(0), topology.build(1)], contact_layer.get_canvas_item(),
		contacts, get_canvas_item(), _collect_beams)

func _collect_beams(segments: Array) -> void:
	beam_rows.append_array(segments)

func _upload_beams() -> void:
	if beam_instances == null:
		return
	var mesh: MultiMesh = beam_instances.multimesh
	mesh.instance_count = beam_rows.size()
	mesh.visible_instance_count = beam_rows.size()
	beam_material.set_shader_parameter("clock", fmod(_battle.presentation_clock(), 128.0))
	for i in beam_rows.size():
		var row: Dictionary = beam_rows[i]
		var delta: Vector2 = row.to - row.from
		mesh.set_instance_transform_2d(i, Transform2D(delta.angle(), row.from))
		mesh.set_instance_color(i, Color(delta.length(), -1.0, delta.angle(), 1.0 if row.link else 0.0))
		mesh.set_instance_custom_data(i, Color(1.0, row.power, 0.0, row.charge))
