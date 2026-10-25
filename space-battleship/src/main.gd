extends Node2D
const Session = preload("res://src/game_session.gd")
const Geometry = preload("res://scripts/ship_geometry_convention.gd")
var session
var kernel
var startup_error: String = ""
var native_display
var projectile_visuals: Array = []
var particles: Array = []
var beam_rows: Array = []
var beam_instances: MultiMeshInstance2D
var beam_material: ShaderMaterial
var contact_layer: Node2D
var growth_panel: PanelContainer
var world_status: Label
var world_crew_picker: OptionButton
var world_assignment_picker: OptionButton
var world_mode_picker: OptionButton
var world_planet_picker: OptionButton
var world_building_picker: OptionButton
var growth_status: Label
var upgrade_price: Label
var slot_picker: OptionButton
var equipment_picker: OptionButton
var ship_picker: OptionButton
var research_picker: OptionButton
var module_picker: OptionButton
var allocation_input: LineEdit
var effect_picker: OptionButton
var branch_node: SpinBox
var branch_choice: OptionButton
const EFFECT_IDS := ["proficiency", "repeat", "critical", "adaptation", "memory", "deferred"]
const EFFECT_NAMES := ["熟练", "连发", "暴击", "适应", "记忆材料", "延迟伤害"]

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
	# Mode is chosen by the entry once. Display code only reads kernel data.
	if kernel.set_compact_laser_births(true) < 0:
		startup_error = "原生显示初始化失败"
		return
	_setup_native_display()
	result = session.start_sortie(1)
	if not result.ok:
		startup_error = str(result.reason)
	else:
		_setup_growth_panel()

func _process(dt: float) -> void:
	if session != null and startup_error.is_empty():
		session.frame(dt, DisplayServer.window_is_focused())
		if native_display != null:
			native_display.advance_visuals(dt)
			for event in session.last_events:
				if int(event.kind) in [0, 1]:
					native_display.record_contact(0 if event.get("hostile", false) else 1, event.position, event.direction,
						float(event.clock), int(event.kind) == 0, bool(event.critical), int(event.type))
			native_display.prune_contacts(float(kernel.presentation_clock()), false)
	if world_status != null and growth_panel.visible:
		_refresh_world_status()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if session == null or not startup_error.is_empty():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		session.set_pause("user", not session.pause_reasons.has("user"))
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_G:
		session.set_guard(not session.guard.enabled, int(session.guard.death_option))
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for id in session.drops.keys():
			var row: Dictionary = session.drops[id]
			if event.position.distance_to(Vector2(float(row.x), float(row.y))) <= 18.0:
				session.collect_drop(str(id))
				break

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
		var prepared = native_display.prepare_flights([], Vector2.ZERO)
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
	for row in session.drops.values():
		draw_circle(Vector2(float(row.x), float(row.y)), 5.0, Color("ffe195") if str(row.id) != "jewel" else Color("a2afff"))
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
	var balances: PackedStringArray = []
	for resource in session.wallet:
		var text = session.amount_api.apply("to_display", [session.wallet[resource]])
		balances.append(str(resource) + ": " + str(text.text))
	draw_string(font, Vector2(18, 795), "   ".join(balances), HORIZONTAL_ALIGNMENT_LEFT, 536, 14, Color("ffe195"))
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
	native_display.configure_surface(kernel, get_canvas_item(), projectile_visuals, particles,
		_prepare_projectile_flight, _draw_projectile_foreground_flight,
		restore_native_laser_visuals, prepare_native_laser_display, _advance_projectile_visual_record)

func _prepare_projectile_flight(shot: Dictionary, index: Dictionary, offset: Vector2) -> Dictionary:
	if shot.get("dead", false) or shot.get("await_target", false):
		return {}
	var serial: int = int(shot.get("serial", 0))
	var visual: Dictionary = index.get(serial, {})
	var lease = shot.get("motion_lease")
	var point: Vector2 = lease.position() if lease != null else shot.get("launch_point", Vector2.ZERO)
	if visual.is_empty():
		var direction: Vector2 = lease.direction() if lease != null else shot.get("direction", Vector2.UP)
		visual = native_display.create_visual(shot, direction.angle(), int(shot.get("mount", 0)), point, point, 0.0)
		projectile_visuals.append(visual)
		native_display.register_visual(shot, visual, projectile_visuals.size() - 1)
	return {"shot": shot, "visual": visual, "pos": point + offset, "budget": 1}

func _draw_projectile_foreground_flight(flight: Dictionary, _offset: Vector2) -> void:
	var shot: Dictionary = flight.shot
	if not shot.get("beam", false):
		return
	var target: Dictionary = shot.get("target", {})
	if target.is_empty() or target.get("dead", false):
		return
	var origin: Vector2 = shot.get("launch_point", flight.pos)
	var point := Vector2(float(target.get("x", origin.x)), float(target.get("y", origin.y)))
	var age: float = float(shot.get("elapsed", 0.0))
	var row: Dictionary = shot.get("weapon", {})
	var ramp: float = float(row.get("para1", 1.0))
	var charge: float = float(row.get("para3", 0.0))
	var active: bool = int(shot.get("ticks", 0)) > 0
	var power: float = clampf(maxf(0.0, age - charge) / ramp, 0.0, 1.0) if ramp > 0 else 1.0
	beam_rows.append({"from": origin, "to": point, "power": power, "charge": -1.0 if active else clampf(age / maxf(charge, 0.001), 0.0, 1.0), "link": false})
	var instance: Dictionary = shot.get("attack_instance", {})
	var chain: Dictionary = instance.get("chain", {})
	for link in chain.get("links", []):
		var linked: Dictionary = link.get("target", {})
		if link.get("broken", false) or linked.is_empty() or linked.get("dead", false):
			continue
		beam_rows.append({"from": point, "to": Vector2(float(linked.x), float(linked.y)), "power": power, "charge": -1.0 if active else 0.0, "link": true})

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

func _advance_projectile_visual_record(visual: Dictionary, dt: float) -> void:
	visual.age = float(visual.get("age", 0.0)) + dt

func restore_native_laser_visuals() -> void:
	projectile_visuals.clear()

func prepare_native_laser_display(_compatibility: bool) -> bool:
	return true

func _command_button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	parent.add_child(button)
	button.pressed.connect(func():
		var result: Dictionary = action.call()
		var reason: String = str(result.get("reason", result.get("error", "操作失败")))
		var labels := {"GalaxyUnavailable": "星系尚未开放", "UnknownPlanet": "尚未选择星球", "HyperspaceCrewReserved": "船员仍被超空间任务占用", "CrewAssignmentUnavailable": "岗位暂不可用", "CrewLocked": "船员尚未解锁", "CrewTargetOccupied": "目标人数已满", "PlanetLocked": "星球尚未开放", "PlanetStationRequired": "需先领取空间站", "PlanetBuildingUnavailable": "建筑当前不可派遣施工", "PlanetBuildingNotReady": "建筑尚未完工", "CrewJobLocked": "岗位尚未开放", "NoChange": "没有变更", "InsufficientResources": "资源不足", "EquipmentSwitchLocked": "换装冷却尚未结束", "EquipmentLocked": "装备尚未解锁", "EnhancementLocked": "强化尚未解锁", "EnhancementBranchLocked": "强化分支尚未开放", "ReactorLocked": "反应炉尚未解锁", "ReactorModuleLocked": "反应炉模块尚未开放", "ResearchLocked": "科研前置条件未满足", "EvolutionMaterialLocked": "进化材料尚未开放", "ShipLocked": "舰体尚未解锁", "NativeConfigurationRejected": "配装或属性不满足条件"}
		growth_status.text = "完成" if result.get("ok", false) else str(labels.get(reason, reason))
		_refresh_growth_pickers())
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
		if growth_panel.visible: _refresh_growth_pickers())
	_caption(box, "槽位升级（换装备保留等级）")
	slot_picker = OptionButton.new()
	box.add_child(slot_picker)
	slot_picker.item_selected.connect(func(_index): _populate_equipment_picker())
	upgrade_price = Label.new()
	box.add_child(upgrade_price)
	var upgrades := _row(box)
	_command_button(upgrades, "+1", func(): return session.buy_levels(_selected_slot(), 1))
	_command_button(upgrades, "+10", func(): return session.buy_levels(_selected_slot(), 10))
	_command_button(upgrades, "MAX", func(): return session.buy_max_levels(_selected_slot()))
	_command_button(upgrades, "全体 +1", func(): return session.buy_all_levels(1))
	equipment_picker = OptionButton.new()
	box.add_child(equipment_picker)
	_command_button(box, "更换所选装备", func(): return session.equip_slot(_selected_slot(), str(equipment_picker.get_item_metadata(equipment_picker.selected))))
	ship_picker = OptionButton.new()
	box.add_child(ship_picker)
	_command_button(box, "更换舰体", func(): return session.change_ship(str(ship_picker.get_item_metadata(ship_picker.selected))))
	_caption(box, "反应炉")
	var reactor_buttons := _row(box)
	_command_button(reactor_buttons, "购买 1 级", func(): return session.buy_reactor())
	_command_button(reactor_buttons, "平均分配", func(): return session.distribute_reactor())
	var allocation := _row(box)
	module_picker = OptionButton.new()
	var module_names := ["武器", "防御", "炼铁", "碎片凝聚"]
	var modules: PackedStringArray = str(session.parameters.reactorModules).split(",")
	for i in modules.size():
		module_picker.add_item(module_names[i])
		module_picker.set_item_metadata(i, modules[i])
	allocation.add_child(module_picker)
	allocation_input = LineEdit.new()
	allocation_input.placeholder_text = "分配能源"
	allocation_input.custom_minimum_size.x = 120
	allocation.add_child(allocation_input)
	_command_button(allocation, "分配", func():
		var quantity = session.amount_api.apply("from_decimal", [allocation_input.text])
		return session.allocate_reactor(str(module_picker.get_item_metadata(module_picker.selected)), quantity.value) if quantity.ok else quantity)
	_caption(box, "AI 科研（切换保留各项工作量）")
	research_picker = OptionButton.new()
	box.add_child(research_picker)
	for key in session.research_definitions:
		var index: int = research_picker.item_count
		research_picker.add_item(str(session.research_definitions[key].name))
		research_picker.set_item_metadata(index, key)
	_command_button(box, "选择研究", func(): return session.select_research(str(research_picker.get_item_metadata(research_picker.selected))))
	for resource in ["1", "2"]:
		var investment := _row(box)
		_caption(investment, "铁/秒" if resource == "1" else "铀/秒")
		var input := LineEdit.new()
		input.text = "0"
		input.custom_minimum_size.x = 140
		investment.add_child(input)
		_command_button(investment, "设置投入", func():
			var quantity = session.amount_api.apply("from_decimal", [input.text])
			return session.set_research_investment(resource, quantity.value) if quantity.ok else quantity)
	var automatic := _row(box)
	var toggle := CheckBox.new()
	toggle.text = "自动投入"
	automatic.add_child(toggle)
	var ratio := SpinBox.new()
	ratio.min_value = float(session.rules.research_minimum_ratio) * 100.0
	ratio.max_value = 100.0
	ratio.step = 0.1
	ratio.value = float(session.research_progress.ratio) * 100.0
	ratio.suffix = "%"
	automatic.add_child(ratio)
	_command_button(automatic, "应用", func(): return session.set_research_automatic_investment(toggle.button_pressed, ratio.value / 100.0))
	_caption(box, "全局强化")
	var enhancement_buttons := _row(box)
	_command_button(enhancement_buttons, "购买 1 级", func(): return session.buy_enhancement(1))
	_command_button(enhancement_buttons, "最多购买 10 级", func(): return session.buy_enhancement(10))
	var branches := _row(box)
	effect_picker = OptionButton.new()
	for label in EFFECT_NAMES: effect_picker.add_item(label)
	branches.add_child(effect_picker)
	branch_node = SpinBox.new()
	branch_node.min_value = 1
	branch_node.max_value = 3
	branch_node.step = 1
	branches.add_child(branch_node)
	branch_choice = OptionButton.new()
	branch_choice.add_item("A")
	branch_choice.add_item("B")
	branches.add_child(branch_choice)
	_command_button(box, "设置分支", func(): return session.set_enhancement_branch(EFFECT_IDS[effect_picker.selected], int(branch_node.value) - 1, "A" if branch_choice.selected == 0 else "B"))
	_command_button(box, "将所选效果前移一位", func():
		var category: String = "weapon" if effect_picker.selected < 3 else "defence"
		var order: Array = session.enhancement_progress[category + "_order"].duplicate()
		var index: int = order.find(EFFECT_IDS[effect_picker.selected])
		var previous: int = (index + order.size() - 1) % order.size()
		var held = order[previous]
		order[previous] = order[index]
		order[index] = held
		return session.set_enhancement_order(category, order))
	_caption(box, "连发第二节点 B 仅保留选择，不产生第二代连发。")
	_setup_world_controls(box)
	_refresh_growth_pickers()

func _selected_slot() -> String:
	return "" if slot_picker.selected < 0 else str(slot_picker.get_item_metadata(slot_picker.selected))

func _refresh_growth_pickers() -> void:
	_refresh_world_pickers()
	if slot_picker == null:
		return
	var selected: String = _selected_slot()
	slot_picker.clear()
	var ship: Dictionary = session.ship_definitions[session.selected_ship]
	for slot in session.slots:
		if int(slot.index) >= int(ship.para_1 if slot.category == "weapon" else ship.para_2):
			continue
		var index: int = slot_picker.item_count
		slot_picker.add_item(("武器 " if slot.category == "weapon" else "防具 ") + str(int(slot.index) + 1) + " · " + session.equipment_label(str(slot.equipment_id)) + " · Lv." + str(slot.paid_level))
		slot_picker.set_item_metadata(index, slot.id)
		if str(slot.id) == selected: slot_picker.select(index)
	ship_picker.clear()
	for key in session.ship_definitions:
		var index: int = ship_picker.item_count
		ship_picker.add_item(str(session.ship_definitions[key].des))
		ship_picker.set_item_metadata(index, key)
		ship_picker.set_item_disabled(index, not session.unlocked("ship", key))
		if key == session.selected_ship: ship_picker.select(index)
	_populate_equipment_picker()

func _populate_equipment_picker() -> void:
	if equipment_picker == null:
		return
	var id: String = _selected_slot()
	var weapon: bool = id.begins_with("weapon:")
	var quote = session.quote_levels(id, 1)
	var prices: PackedStringArray = []
	if quote.ok:
		for resource in quote.costs:
			var value = session.amount_api.apply("to_display", [quote.costs[resource]])
			prices.append(("铁 " if resource == "1" else "铀 " if resource == "2" else "进化材料 ") + str(value.text))
	upgrade_price.text = "下一级：" + "，".join(prices) if quote.ok else "进化材料未开放或无法报价"
	equipment_picker.clear()
	equipment_picker.add_item("卸下")
	equipment_picker.set_item_metadata(0, "")
	for key in (["laser", "missile", "cannon", "longLaser"] if weapon else ["armour", "shield"]):
		var index: int = equipment_picker.item_count
		equipment_picker.add_item(session.equipment_label(key))
		equipment_picker.set_item_metadata(index, key)
		equipment_picker.set_item_disabled(index, not session.unlocked("equipment", key))

const CREW_JOB_NAMES := {"equipment_upgrade": "装备升级", "hightech_scientists": "科研", "jewel_auto": "强化", "reactor_upgrade": "反应炉"}
const PLANET_BUILD_STATES := {"locked": "未解锁", "building": "施工中", "ready": "待领取", "built": "已建成"}

func _picker_value(picker: OptionButton, fallback = ""):
	return fallback if picker == null or picker.selected < 0 else picker.get_item_metadata(picker.selected)

func _setup_world_controls(box: Control) -> void:
	_caption(box, "船员与星球")
	_caption(box, "随进度逐步开放星球与星系。")
	world_status = Label.new()
	world_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	world_planet_picker = OptionButton.new()
	world_planet_picker.item_selected.connect(func(_index): _refresh_world_buildings())
	box.add_child(world_planet_picker)
	var automatic := _row(box)
	_command_button(automatic, "开启自动探索", func(): return session.set_planet_automatic(str(_picker_value(world_planet_picker)), true))
	_command_button(automatic, "本次完成后停止", func(): return session.set_planet_automatic(str(_picker_value(world_planet_picker)), false))
	_command_button(box, "立即取消探索", func(): return session.cancel_planet(str(_picker_value(world_planet_picker))))
	world_building_picker = OptionButton.new()
	box.add_child(world_building_picker)
	var construction := _row(box)
	_command_button(construction, "领取建筑", func(): return session.claim_planet_build(str(_picker_value(world_planet_picker)), str(_picker_value(world_building_picker))))
	_command_button(box, "刷新世界列表", func(): return {"ok": true})

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
	var previous: Dictionary = _picker_value(world_assignment_picker, {})
	world_assignment_picker.clear()
	for job in CREW_JOB_NAMES:
		_world_assignment(CREW_JOB_NAMES[job], "system_job", job, previous)
	var planet: String = str(_picker_value(world_planet_picker))
	world_planet_picker.clear()
	for id in session.planet_definitions:
		if not session.planet_unlocked(id): continue
		var name: String = str(session.planet_definitions[id].name)
		var index: int = world_planet_picker.item_count
		world_planet_picker.add_item(name)
		world_planet_picker.set_item_metadata(index, id)
		if id == planet: world_planet_picker.select(index)
		_world_assignment("探索 · " + name, "planet_explore", id, previous)
		for key in session.planet_progress[id].buildings:
			if session.planet_progress[id].buildings[key].state == "building" and int(session.planet_buildings[key].extra_crew) > 0:
				_world_assignment("施工 · " + name + " · " + str(session.planet_buildings[key].name), "planet_build", str(id) + ":" + str(key), previous)
	for key in session.galaxy_progress:
		if session.galaxy_unlocked(key):
			_world_assignment("星系 · " + str(session.galaxy_definitions[key].name), "galaxy", key, previous)
	_refresh_world_buildings()
	_refresh_world_status()

func _refresh_world_buildings() -> void:
	var selected: String = str(_picker_value(world_building_picker))
	world_building_picker.clear()
	var id: String = str(_picker_value(world_planet_picker))
	if not session.planet_progress.has(id): return
	for key in session.planet_progress[id].buildings:
		var progress: Dictionary = session.planet_progress[id].buildings[key]
		var row: Dictionary = session.planet_buildings[key]
		var index: int = world_building_picker.item_count
		world_building_picker.add_item(str(row.name) + " · " + str(PLANET_BUILD_STATES[progress.state]) + " %d/%d" % [int(progress.work), int(row.build_explore)])
		world_building_picker.set_item_metadata(index, key)
		if key == selected: world_building_picker.select(index)

func _refresh_world_status() -> void:
	var lines: PackedStringArray = []
	var show_levels: bool = session.unlocked("feature", "crew_level")
	for id in session.crew_progress:
		if not session.unlocked("crew", id): continue
		var member: Dictionary = session.crew_progress[id]
		var job: String = "空闲"
		if member.kind == "system_job": job = str(CREW_JOB_NAMES.get(member.target, member.target))
		elif member.kind == "planet_explore": job = "星球探索"
		elif member.kind == "planet_build": job = "建筑施工"
		elif member.kind == "galaxy": job = "星系建设"
		if show_levels:
			var experience = session.amount_api.apply("to_display", [member.exp])
			lines.append("%s Lv.%d · %s · 经验 %s" % [session.crew_definitions[id].name, int(member.level), job, experience.text])
		else:
			lines.append("%s · %s" % [session.crew_definitions[id].name, job])
	for id in session.planet_progress:
		if not session.planet_unlocked(id): continue
		var progress: Dictionary = session.planet_progress[id]
		lines.append("%s · 探索 %d · %s" % [session.planet_definitions[id].name, int(progress.exploration), "%.1f/%.1f 秒" % [float(progress.elapsed), float(progress.duration)] if progress.running else "待派遣"])
	for key in session.galaxy_progress:
		if not session.galaxy_unlocked(key): continue
		var region: Dictionary = session.galaxy_progress[key]
		var explored: int = 0
		var active: int = 0
		var levels: int = 0
		var upgrading: int = 0
		for node in region.nodes.values():
			if node.explored: explored += 1
			if node.state == "active": active += 1
			levels += int(node.level)
			if float(node.upgrade_remaining) > 0.0: upgrading += 1
		var phase: String = str({"exploring": "探索建设", "developing": "发展升级", "complete": "已完成"}[region.phase])
		lines.append("%s · %s · 探索 %d/%d · 建成 %d · 等级合计 %d · 升级中 %d" % [session.galaxy_definitions[key].name, phase, explored, region.nodes.size(), active, levels, upgrading])
		if not str(region.active_node).is_empty():
			var work: Dictionary = region.nodes[str(region.active_node)]
			lines.append("%s · %s" % [session.galaxy_buildings[work.building].name, "剩余探索工作 %.1f" % float(work.explore_remaining) if not work.explored else "剩余施工 %.1f 秒" % float(work.construction_remaining)])
	world_status.text = "\n".join(lines) if not lines.is_empty() else "继续推进关卡以解锁船员。"
