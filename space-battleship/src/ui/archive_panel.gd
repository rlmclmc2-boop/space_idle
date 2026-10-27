extends VBoxContainer
const PlayerText = preload("res://src/ui/player_text.gd")
const HELP := {
	"equip": ["配装", "在舰船页选择槽位和装备，再确认换装。槽位等级保留；战斗中的换装受冷却约束。"],
	"upgrade": ["升级", "在舰船页查看下一级费用，用+1、+10或MAX升级。资源不足时不会扣费。"],
	"pickup": ["拾取", "点击战场中的资源光点领取，也可等待自动拾取。定时资源在生成时确定金额；普通敌舰掉落按领取时的对应收益与自动领取规则结算。"],
	"retreat": ["撤退与驻守", "盾甲耗尽后自动撤退并恢复防御。舰船页可设置驻守和死亡后的目标策略。"],
	"clear": ["通关", "最终战点清空后先结算奖励，再显示解锁提示。关闭提示只释放引导暂停。"]}
var _session
var _tutorial := VBoxContainer.new()
var _intel := VBoxContainer.new()
var _damage := VBoxContainer.new()
var _elapsed: float = 0.0
var _tutorial_lines: Dictionary = {}
var _intel_rows: Dictionary = {}
var _damage_rows: Dictionary = {}
var _empty_intel: Label
var _empty_damage: Label

func _init(session) -> void:
	_session = session

func _ready() -> void:
	add_child(_heading("飞行手册"))
	add_child(_tutorial)
	add_child(_heading("当前敌情"))
	add_child(_intel)
	add_child(_heading("伤害明细"))
	add_child(_damage)
	for key in HELP:
		var line := Label.new()
		PlayerText.wrap(line)
		_tutorial.add_child(line)
		_tutorial_lines[key] = line
	_empty_intel = _heading("当前没有交战敌舰")
	_intel.add_child(_empty_intel)
	_empty_damage = _heading("尚未造成伤害")
	_damage.add_child(_empty_damage)
	_refresh()

func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	return label

func _set_text(label: Label, text: String) -> void:
	if label.text != text: label.text = text

func _refresh() -> void:
	for key in HELP:
		_set_text(_tutorial_lines[key], "%s · %s\n%s" % [HELP[key][0], "已实践" if _session.tutorial.completed(key) else "操作指引", HELP[key][1]])
	var enemies: Array = _session.battle.enemy_intelligence()
	_empty_intel.visible = enemies.is_empty()
	var active: Dictionary = {}
	for index in enemies.size():
		var enemy: Dictionary = enemies[index]
		var id: int = int(enemy.uid)
		active[id] = true
		if not _intel_rows.has(id):
			var row := HBoxContainer.new()
			_intel.add_child(row)
			var preview := TextureRect.new()
			preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			preview.custom_minimum_size = Vector2(64, 80)
			row.add_child(preview)
			var label := Label.new()
			PlayerText.wrap(label)
			row.add_child(label)
			_intel_rows[id] = {"row": row, "preview": preview, "label": label}
		var view: Dictionary = _intel_rows[id]
		if view.row.get_index() != index + 1: _intel.move_child(view.row, index + 1)
		if view.preview.texture != enemy.texture: view.preview.texture = enemy.texture
		var types := {0: "无", 1: "能量", 2: "物理"}
		_set_text(view.label, "%s · %s\n装甲 %s（%s） · 护盾 %s（%s）\n%s" % [enemy.name,
			{"normal": "普通", "elite": "精英", "boss": "首领", "ultimate": "终极"}.get(enemy.tier, "敌舰"),
			PlayerText.number(str(enemy.armour)), types.get(enemy.armour_type, "特殊"), PlayerText.number(str(enemy.shield)), types.get(enemy.shield_type, "特殊"), enemy.mechanics])
	for id in _intel_rows.keys():
		if active.has(id): continue
		var row: Control = _intel_rows[id].row
		_intel.remove_child(row)
		row.queue_free()
		_intel_rows.erase(id)
	var damage_rows: Array = _session.battle.statistics().display_rows()
	_empty_damage.visible = damage_rows.is_empty()
	for index in damage_rows.size():
		if not _damage_rows.has(index):
			var line := Label.new()
			PlayerText.wrap(line)
			_damage.add_child(line)
			_damage_rows[index] = line
		var source: Dictionary = damage_rows[index]
		_set_text(_damage_rows[index], "%s · 总伤害 %s\n护盾 %s · 装甲 %s" % [source.name, source.total, source.shield, source.armour])
	for index in _damage_rows.keys():
		if index < damage_rows.size(): continue
		var line: Label = _damage_rows[index]
		_damage.remove_child(line)
		line.queue_free()
		_damage_rows.erase(index)

func _process(dt: float) -> void:
	if not is_visible_in_tree(): return
	_elapsed += dt
	if _elapsed >= 1.0:
		_elapsed = 0.0
		_refresh()
