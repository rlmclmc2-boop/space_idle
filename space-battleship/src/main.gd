extends Node2D
const FleetPanel = preload("res://src/ui/fleet_panel.gd")
const CampaignView = preload("res://src/ui/campaign_view.gd")
const CrewPanel = preload("res://src/ui/crew_panel.gd")
const GalaxyPanel = preload("res://src/ui/galaxy_panel.gd")
const PlanetPanel = preload("res://src/ui/planet_panel.gd")
const EconomyView = preload("res://src/ui/economy_view.gd")
const EquipmentPanel = preload("res://src/ui/equipment_panel.gd")
const ReactorPanel = preload("res://src/ui/reactor_panel.gd")
const EnhancementPanel = preload("res://src/ui/enhancement_panel.gd")
const ResearchPanel = preload("res://src/ui/research_panel.gd")
const Session = preload("res://src/game_session.gd")
const Geometry = preload("res://scripts/ship_geometry_convention.gd")
var session
var kernel
var startup_error: String = ""
var native_display
var beam_rows: Array = []
var beam_instances: MultiMeshInstance2D
var beam_material: ShaderMaterial
var contact_layer: Node2D
var growth_panel: PanelContainer
var growth_status: Label

func _ready() -> void:
	if not ClassDB.class_exists("SpaceCombatKernel"):
		var extension: String = OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION")
		if extension.is_empty():
			startup_error = "请先编译原生模块，再通过 run_game.ps1 启动。"
			return
		var loaded = GDExtensionManager.load_extension(extension)
		if loaded != GDExtensionManager.LOAD_STATUS_OK and loaded != GDExtensionManager.LOAD_STATUS_ALREADY_LOADED:
			startup_error = "原生模块加载失败：" + extension
			return
	session = Session.new()
	var result = session.initialize("res://generated/config.json", Time.get_ticks_usec())
	if not result.ok:
		startup_error = str(result.reason)
		return
	get_window().content_scale_size = Vector2i(int(session.geometry.view_width), int(session.geometry.view_height))
	kernel = session.kernel
	_setup_native_display()
	result = session.campaign_system.start_sortie(1, session.equipment.clear_switch_locks)
	if not result.ok:
		startup_error = str(result.reason)
	else:
		add_child(CampaignView.new(session.campaign_system))
		add_child(EconomyView.new(session.economy, session.economy_display_context, session.refresh_growth))
		_setup_growth_panel()

func _process(dt: float) -> void:
	if session != null and startup_error.is_empty():
		session.frame(dt, DisplayServer.window_is_focused())
		if native_display != null:
			native_display.advance_visuals()
			for event in session.last_events:
				if int(event.kind) in [0, 1]:
					native_display.record_contact(0 if event.get("hostile", false) else 1, event.position, event.direction,
						float(event.clock), int(event.kind) == 0, bool(event.critical), int(event.type))
			native_display.prune_contacts(float(kernel.presentation_clock()), false)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if session == null or not startup_error.is_empty():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		session.set_pause("user", not session.pause_reasons.has("user"))

func _draw() -> void:
	draw_rect(get_viewport_rect(), Color("071423"))
	var font: Font = ThemeDB.fallback_font
	if not startup_error.is_empty():
		draw_string(font, Vector2(18, 45), startup_error, HORIZONTAL_ALIGNMENT_LEFT, 536, 14, Color("ffb4a6"))
		return
	if session == null or kernel == null:
		return
	beam_rows.clear()
	if beam_instances != null:
		beam_instances.multimesh.visible_instance_count = 0
	if native_display != null:
		var prepared = native_display.prepare_flights(Vector2.ZERO)
		native_display.draw_flights(prepared, Vector2.ZERO)
		_upload_beams()
		native_display.draw_contacts(contact_layer.get_canvas_item(), float(kernel.presentation_clock()), true)
	var player_point := Vector2(float(session.geometry.player_x), float(session.geometry.player_y))
	var player_hull: PackedVector2Array = Geometry.transform_hull(session.models[session.campaign_system.selected_ship()].hull, player_point, session.player_dimensions, 0.0)
	if player_hull.size() >= 3:
		draw_colored_polygon(player_hull, Color("66d9dc"))
	var enemies: Array = kernel.enemy_views()
	for index in enemies.size():
		var actor: Dictionary = enemies[index]
		if actor.get("dead", false) or index >= session.enemy_hulls.size():
			continue
		var hull: PackedVector2Array = session.enemy_hulls[index]
		if hull.size() >= 3:
			draw_colored_polygon(hull, Color("ce6978"))
		draw_string(font, Vector2(float(actor.x) - 24, float(actor.y) + 35), str(actor.hp), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("f1d9dc"))
	var history: Dictionary = kernel.read_history()
	draw_string(font, Vector2(18, 53), "攻击 %s   来袭 %s" % [history.attacks, history.incoming], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("a9c6db"))
	var player: Dictionary = kernel.player_view()
	draw_string(font, Vector2(18, 765), "装甲 %s   护盾 %s" % [player.armour, player.shield], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("b8ede6"))
	var statistics: PackedStringArray = []
	for source in session.damage_statistics:
		var entry: Dictionary = session.damage_statistics[source]
		var total = session.amount_api.apply("add", [entry.shield, entry.health])
		var text = session.amount_api.apply("to_display", [total.value])
		statistics.append(str(source) + " " + str(text.text))
	if not statistics.is_empty():
		draw_string(font, Vector2(18, 825), "伤害 " + "  ".join(statistics), HORIZONTAL_ALIGNMENT_LEFT, 536, 12, Color("c1d5f0"))
	draw_string(font, Vector2(18, 920), "空格暂停 · G 驻守 · 点击掉落领取", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("91a9c0"))
	if not session.last_error.is_empty():
		draw_string(font, Vector2(18, 850), session.last_error, HORIZONTAL_ALIGNMENT_LEFT, 536, 14, Color("ffb4a6"))

func _setup_native_display() -> void:
	native_display = ClassDB.instantiate("SpaceCombatPresentation")
	var retained := ShaderMaterial.new()
	retained.shader = load("res://shaders/retained_flights.gdshader")
	var pulse := Image.load_from_file("res://assets/weapons/laser-pulse.png")
	if pulse != null and not pulse.is_empty():
		retained.set_shader_parameter("pulse_texture", ImageTexture.create_from_image(pulse))
	native_display.configure_logical_coordinates(true)
	native_display.configure_retained_gpu(retained)
	contact_layer = Node2D.new()
	contact_layer.z_index = 2
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

func _command_button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	parent.add_child(button)
	button.pressed.connect(func():
		var result: Dictionary = action.call()
		var reason: String = str(result.get("reason", result.get("error", "操作失败")))
		var labels := {"NoChange": "没有变更", "InsufficientResources": "资源不足", "NativeConfigurationRejected": "配装或属性不满足条件"}
		growth_status.text = "完成" if result.get("ok", false) else str(result.get("message", labels.get(reason, reason)))
		)
	return button

func _setup_growth_panel() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var open := Button.new()
	open.text = "成长与配装"
	open.position = Vector2(18, 80)
	layer.add_child(open)
	growth_panel = PanelContainer.new()
	growth_panel.position = Vector2(12, 122)
	growth_panel.size = Vector2(410, 615)
	growth_panel.visible = false
	layer.add_child(growth_panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(400, 600)
	growth_panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 380
	scroll.add_child(box)
	growth_status = Label.new()
	box.add_child(growth_status)
	open.pressed.connect(func(): growth_panel.visible = not growth_panel.visible)
	box.add_child(EquipmentPanel.new(session.equipment, session.equipment_inputs, session.economy.affordable,
		session.economy.payment, session.publish_equipment_levels, session.publish_equipment_refit, _command_button))
	box.add_child(FleetPanel.new(session.campaign_system, session.commit_ship_refit, _command_button))
	var reactor_panel = ReactorPanel.new(session.reactor_system, session.reactor_inputs, session.economy.can_pay, session.publish_reactor, _command_button)
	box.add_child(reactor_panel)
	var research_panel = ResearchPanel.new(session.research, _command_button)
	box.add_child(research_panel)
	box.add_child(EnhancementPanel.new(session.enhancement, session.enhancement_inputs,
		session.economy.affordable, session.publish_enhancement, _command_button))
	box.add_child(CrewPanel.new(session.crew_system, session.planet_system, session.galaxy_system, session.coordinate_assignment, _command_button))
	box.add_child(GalaxyPanel.new(session.galaxy_system))
	box.add_child(PlanetPanel.new(session.planet_system, session.coordinate_planet_cancel, session.publish_world, _command_button))
