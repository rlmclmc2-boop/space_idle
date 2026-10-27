extends VBoxContainer
const PlayerText = preload("res://src/ui/player_text.gd")
var _session
var _status := Label.new()
var _stage := SpinBox.new()
var _guard := CheckBox.new()
var _policy := OptionButton.new()
var _command: Callable

func _init(session, command: Callable) -> void:
	_session = session
	_command = command
	var title := Label.new()
	title.text = "航行与驻守"
	title.add_theme_font_size_override("font_size", 20)
	add_child(title)
	PlayerText.wrap(_status)
	add_child(_status)
	_stage.min_value = 1
	_stage.step = 1
	_stage.max_value = int(session.campaign_system.progress_facts().cycle_reached)
	_stage.value = int(session.campaign_system.scenery_facts().stage)
	_stage.prefix = "关卡 "
	add_child(_stage)
	_command.call(self, "出击所选关卡", func(): return _session.campaign_system.start_sortie(int(_stage.value), _session.equipment.clear_switch_locks))
	_guard.text = "驻守当前战点"
	_guard.button_pressed = bool(session.campaign_system.save_state().guard.enabled)
	add_child(_guard)
	for caption in ["死亡后取消驻守", "死亡后保留原目标", "死亡后在新位置驻守"]: _policy.add_item(caption)
	_policy.select(int(session.campaign_system.save_state().guard.death_option))
	add_child(_policy)
	_command.call(self, "应用驻守策略", func(): return _session.campaign_system.set_guard(_guard.button_pressed, _policy.selected))
	_session.campaign_system.progress_changed.connect(_refresh)
	_session.campaign_system.status_changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	_status.text = _session.campaign_system.status_text()
	_stage.max_value = int(_session.campaign_system.progress_facts().cycle_reached)
