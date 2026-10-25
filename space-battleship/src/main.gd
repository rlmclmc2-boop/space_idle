extends Node2D
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
var world_status: VBoxContainer
var world_labels: Dictionary = {}
var world_crew_picker: OptionButton
var world_assignment_picker: OptionButton
var world_mode_picker: OptionButton
var growth_status: Label
var ship_picker: OptionButton
var research_panel
var reactor_panel

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
	result = session.start_sortie(1)
	if not result.ok:
		startup_error = str(result.reason)
	else:
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
	if world_status != null and growth_panel.visible:
		_flush_display_changes()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if session == null or not startup_error.is_empty():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		session.set_pause("user", not session.pause_reasons.has("user"))
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_G:
		session.set_guard(not session.guard.enabled, int(session.guard.death_option))

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
	var player_hull: PackedVector2Array = Geometry.transform_hull(session.models[session.selected_ship].hull, player_point, session.player_dimensions, 0.0)
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
	var state: Dictionary = session.campaign
	draw_string(font, Vector2(18, 28), "关卡 %s · %s · %.0f" % [state.stage, state.state, state.distance], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("ecf5ff"))
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
		var labels := {"GalaxyUnavailable": "星系尚未开放", "UnknownPlanet": "尚未选择星球", "HyperspaceCrewReserved": "船员仍被超空间任务占用", "CrewAssignmentUnavailable": "岗位暂不可用", "CrewLocked": "船员尚未解锁", "CrewTargetOccupied": "目标人数已满", "PlanetLocked": "星球尚未开放", "PlanetStationRequired": "需先领取空间站", "PlanetBuildingUnavailable": "建筑当前不可派遣施工", "PlanetBuildingNotReady": "建筑尚未完工", "CrewJobLocked": "岗位尚未开放", "NoChange": "没有变更", "InsufficientResources": "资源不足", "ShipLocked": "舰体尚未解锁", "NativeConfigurationRejected": "配装或属性不满足条件"}
		growth_status.text = "完成" if result.get("ok", false) else str(result.get("message", labels.get(reason, reason)))
		)
	return button

func _row(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	parent.add_child(row)
	return row

func _caption(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	parent.add_child(label)

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
	open.pressed.connect(func():
		growth_panel.visible = not growth_panel.visible
		if growth_panel.visible:
			_refresh_ship_choices()
			_refresh_world_pickers()
			session.take_display_changes())
	box.add_child(EquipmentPanel.new(session.equipment, session.equipment_inputs, session.economy.affordable,
		session.economy.payment, session.publish_equipment_levels, session.publish_equipment_refit, _command_button))
	session.ship_changed.connect(_refresh_ship_choices)
	ship_picker = OptionButton.new()
	box.add_child(ship_picker)
	_command_button(box, "更换舰体", func(): return session.change_ship(str(ship_picker.get_item_metadata(ship_picker.selected))))
	reactor_panel = ReactorPanel.new(session.reactor_system, session.reactor_inputs, session.economy.can_pay, session.publish_reactor, _command_button)
	box.add_child(reactor_panel)
	research_panel = ResearchPanel.new(session.research, _command_button)
	box.add_child(research_panel)
	box.add_child(EnhancementPanel.new(session.enhancement, session.enhancement_inputs,
		session.economy.affordable, session.publish_enhancement, _command_button))
	_setup_world_controls(box)
	_refresh_ship_choices()
	_refresh_world_pickers()

func _refresh_ship_choices() -> void:
	ship_picker.clear()
	for key in session.ship_definitions:
		var index: int = ship_picker.item_count
		ship_picker.add_item(str(session.ship_definitions[key].des))
		ship_picker.set_item_metadata(index, key)
		ship_picker.set_item_disabled(index, not session.unlocked("ship", key))
		if key == session.selected_ship: ship_picker.select(index)

const CREW_JOB_NAMES := {"equipment_upgrade": "装备升级", "hightech_scientists": "科研", "jewel_auto": "强化", "reactor_upgrade": "反应炉"}

func _picker_value(picker: OptionButton, fallback = ""):
	return fallback if picker == null or picker.selected < 0 else picker.get_item_metadata(picker.selected)

func _setup_world_controls(box: Control) -> void:
	_caption(box, "船员与星球")
	_caption(box, "随进度逐步开放星球与星系。")
	world_status = VBoxContainer.new()
	box.add_child(world_status)
	world_crew_picker = OptionButton.new()
	box.add_child(world_crew_picker)
	world_assignment_picker = OptionButton.new()
	box.add_child(world_assignment_picker)
	world_mode_picker = OptionButton.new()
	for mode in ["1", "10", "max"]:
		world_mode_picker.add_item("装备自动购买 " + mode.to_upper())
		world_mode_picker.set_item_metadata(world_mode_picker.item_count - 1, mode)
	box.add_child(world_mode_picker)
	_command_button(box, "派遣所选船员", func():
		var assignment: Dictionary = _picker_value(world_assignment_picker, {"kind": "", "target": ""})
		return session.assign_crew(str(_picker_value(world_crew_picker)), assignment.kind, assignment.target, str(_picker_value(world_mode_picker, "1"))))
	_command_button(box, "撤回所选船员", func(): return session.assign_crew(str(_picker_value(world_crew_picker)), "", ""))
	box.add_child(GalaxyPanel.new(session.galaxy_system))
	session.galaxy_system.availability_changed.connect(_refresh_world_assignments)
	box.add_child(PlanetPanel.new(session.planet_system, session.coordinate_planet_cancel, session.publish_world, _command_button))
	session.planet_system.assignment_options_changed.connect(_refresh_construction_choices)
	session.planet_system.availability_changed.connect(_refresh_world_assignments)
	_command_button(box, "刷新世界列表", func():
		_refresh_world_pickers()
		return {"ok": true})

func _world_assignment(label: String, kind: String, target: String, previous: Dictionary) -> void:
	var value := {"kind": kind, "target": target}
	var index: int = world_assignment_picker.item_count
	world_assignment_picker.add_item(label)
	world_assignment_picker.set_item_metadata(index, value)
	if value == previous:
		world_assignment_picker.select(index)

func _refresh_world_pickers() -> void:
	if world_crew_picker == null:
		return
	var selected: String = str(_picker_value(world_crew_picker))
	var show_levels: bool = session.unlocked("feature", "crew_level")
	world_crew_picker.clear()
	for id in session.crew_definitions:
		if not session.unlocked("crew", id): continue
		var index: int = world_crew_picker.item_count
		var crew_label: String = str(session.crew_definitions[id].name)
		if show_levels:
			crew_label += " · Lv." + str(session.crew_progress[id].level)
		world_crew_picker.add_item(crew_label)
		world_crew_picker.set_item_metadata(index, id)
		if id == selected: world_crew_picker.select(index)
	_refresh_world_assignments()
	_refresh_world_status()

func _refresh_world_assignments() -> void:
	var previous: Dictionary = _picker_value(world_assignment_picker, {})
	world_assignment_picker.clear()
	for job in CREW_JOB_NAMES:
		_world_assignment(CREW_JOB_NAMES[job], "system_job", job, previous)
	for option in session.planet_system.assignment_options():
		_world_assignment(option.label, option.kind, option.target, previous)
	for option in session.galaxy_system.assignment_options():
		_world_assignment(option.label, option.kind, option.target, previous)

func _refresh_construction_choices(ids: Array) -> void:
	var previous: Dictionary = _picker_value(world_assignment_picker, {})
	for index in range(world_assignment_picker.item_count - 1, -1, -1):
		var value: Dictionary = world_assignment_picker.get_item_metadata(index)
		if value.kind == "planet_build" and str(value.target).get_slice(":", 0) in ids: world_assignment_picker.remove_item(index)
	for option in session.planet_system.assignment_options(ids, true):
		_world_assignment(option.label, option.kind, option.target, previous)

func _status_label(kind: String, id: String, text: String) -> void:
	var key: String = kind + ":" + id
	if not world_labels.has(key):
		var label := Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		world_status.add_child(label)
		world_labels[key] = label
	world_labels[key].text = text

func _refresh_world_status(changes: Dictionary = {}) -> void:
	if changes.is_empty(): changes = {"crew": session.crew_progress}
	var show_levels: bool = session.unlocked("feature", "crew_level")
	for id in changes.get("crew", {}):
		if not session.unlocked("crew", id): continue
		var member: Dictionary = session.crew_progress[id]
		var job: String = str(CREW_JOB_NAMES.get(member.target, member.target)) if member.kind == "system_job" else str({"": "空闲", "planet_explore": "星球探索", "planet_build": "星球施工", "galaxy": "星系工程"}.get(member.kind, member.kind))
		var text: String = "%s · %s" % [session.crew_definitions[id].name, job]
		if show_levels:
			var experience = session.amount_api.apply("to_display", [member.exp])
			text = "%s Lv.%d · %s · 经验 %s" % [session.crew_definitions[id].name, int(member.level), job, experience.text]
		_status_label("crew", str(id), text)

func _flush_display_changes() -> void:
	var changes: Dictionary = session.take_display_changes()
	if changes.is_empty(): return
	if changes.has("unlocks"):
		_refresh_ship_choices()
		_refresh_world_pickers()
		return
	if changes.has("crew"):
		for index in world_crew_picker.item_count:
			var id: String = str(world_crew_picker.get_item_metadata(index))
			if not changes.crew.has(id): continue
			world_crew_picker.set_item_text(index, str(session.crew_definitions[id].name) + (" · Lv." + str(session.crew_progress[id].level) if session.unlocked("feature", "crew_level") else ""))
	_refresh_world_status(changes)
