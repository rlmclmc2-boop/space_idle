extends Node2D
const BattleView = preload("res://src/ui/battle_view.gd")
const BattleStatisticsView = preload("res://src/ui/battle_statistics_view.gd")
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
var session
var startup_error: String = ""
var _overlay: Node2D
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
	get_window().content_scale_size = session.battle.view_size()
	result = session.campaign_system.start_sortie(1, session.equipment.clear_switch_locks)
	if not result.ok:
		startup_error = str(result.reason)
	else:
		add_child(BattleView.new(session.battle))
		add_child(BattleStatisticsView.new(session.battle.statistics()))
		_setup_shell_overlay()
		add_child(CampaignView.new(session.campaign_system))
		add_child(EconomyView.new(session.economy, session.economy_display_context, session.refresh_growth))
		_setup_growth_panel()

func _process(dt: float) -> void:
	if session != null and startup_error.is_empty():
		session.frame(dt, DisplayServer.window_is_focused())
	if _overlay != null: _overlay.queue_redraw()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if session == null or not startup_error.is_empty() or not session.run_state.is_running():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		session.set_pause("user", not session.pause_reasons.has("user"))

func _draw() -> void:
	draw_rect(get_viewport_rect(), Color("071423"))
	var font: Font = ThemeDB.fallback_font
	if not startup_error.is_empty():
		draw_string(font, Vector2(18, 45), startup_error, HORIZONTAL_ALIGNMENT_LEFT, 536, 14, Color("ffb4a6"))
		return

func _setup_shell_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 9
	add_child(layer)
	_overlay = Node2D.new()
	layer.add_child(_overlay)
	_overlay.draw.connect(_draw_shell)

func _draw_shell() -> void:
	var font: Font = ThemeDB.fallback_font
	_overlay.draw_string(font, Vector2(18, 920), "空格暂停 · G 驻守 · 点击掉落领取", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("91a9c0"))
	if not session.run_state.is_running():
		_overlay.draw_string(font, Vector2(18, 850), session.run_state.reason(), HORIZONTAL_ALIGNMENT_LEFT, 536, 14, Color("ffb4a6"))

func _command_button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	parent.add_child(button)
	button.pressed.connect(func():
		if not session.run_state.is_running():
			growth_status.text = session.run_state.reason()
			return
		var result: Dictionary = action.call()
		var reason: String = str(result.get("reason", result.get("error", "操作失败")))
		var labels := {"NoChange": "没有变更", "NativeConfigurationRejected": "配装或属性不满足条件"}
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
