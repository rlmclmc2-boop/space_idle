extends VBoxContainer
## A read-only native snapshot; no battle formula or result is calculated in this view.
const PlayerText = preload("res://src/ui/player_text.gd")
var _session
var _summary := Label.new()
var _modules := Label.new()
var _temporary := Label.new()
var _elapsed: float = 1.0

func _init(session) -> void:
	_session = session

func _ready() -> void:
	for title in ["舰船属性", "装备明细", "战斗临时效果"]:
		var heading := Label.new()
		heading.text = title
		heading.add_theme_font_size_override("font_size", 20)
		add_child(heading)
		var content: Label = _summary if title == "舰船属性" else _modules if title == "装备明细" else _temporary
		PlayerText.wrap(content)
		add_child(content)
	_refresh()

func _number(value) -> String:
	var parsed: Dictionary = _session.amount_api.apply("from_decimal", [str(value)])
	if not parsed.ok: return "—"
	var display: Dictionary = _session.amount_api.apply("to_display", [parsed.value])
	return PlayerText.number(str(display.text)) if display.ok else "—"

func _refresh() -> void:
	var details: Dictionary = _session.battle.attribute_details()
	var player: Dictionary = details.player
	_summary.text = "装甲 %s / %s\n护盾 %s / %s" % [_number(player.armour), _number(player.max_armour), _number(player.shield), _number(player.max_shield)]
	var rows := PackedStringArray()
	var buffs := PackedStringArray()
	var types := {0: "无属性", 1: "能量", 2: "物理"}
	for row in details.weapons:
		var entry: Dictionary = row.entry
		var name: String = _session.equipment.label(str(entry.get("key", "")))
		var owner: String = "无人机" if entry.has("drone_id") else "武器 %d" % (int(entry.get("slot", 0)) + 1)
		rows.append("%s · %s · %s\n成长基础 %s → 当前攻击 %s（×%s）\n间隔 %.3f 秒 · 连发 %d · 连锁 %d\n基础暴击 %.1f%% · 暴伤 ×%.2f · 复射 %.1f%%" % [owner, name, types.get(int(row.type), "特殊"), _number(row.base), _number(row.value), _number(row.multiplier), row.interval, row.salvo, row.chain_count, float(row.critical_rate) * 100.0, row.critical_multiplier, float(row.repeat_probability) * 100.0])
		if int(row.critical_stacks) > 0 or int(row.critical_attacks) > 0:
			buffs.append("%s · 暴击标记 %d 层（剩余 %.1f 秒），强化攻击剩余 %d 次" % [owner, row.critical_stacks, row.critical_seconds, row.critical_attacks])
		if float(row.focus_seconds) > 0.0:
			buffs.append("%s · 当前目标持续追踪 %.1f 秒" % [owner, row.focus_seconds])
	for row in details.defences:
		var name: String = "护盾" if int(row.layer) == 0 else "装甲"
		rows.append("%s · %s\n成长基础 %s → 容量 %s（×%s） · 当前 %s" % [name, types.get(int(row.type), "特殊"), _number(row.base), _number(row.maximum), _number(row.multiplier), _number(row.current)])
		if int(row.layer) == 0: rows.append("护盾恢复率 %.2f · 受击后延迟 %.2f 秒" % [row.rate, row.delay])
		if _number(row.buffer) != "0" or _number(row.cover) != "0" or float(row.protection_seconds) > 0.0:
			buffs.append("%s · 记忆缓冲 %s · 抵挡 %s · 属性防护剩余 %.1f 秒" % [name, _number(row.buffer), _number(row.cover), row.protection_seconds])
	rows.append("面板显示当前已提交的攻击参数；在途攻击保留出生快照，目标承伤与持续光束按各自结算时序处理。")
	_modules.text = "\n\n".join(rows)
	if float(details.laser_charge) != 1.0: buffs.append("激光充能倍率 ×%.3f" % details.laser_charge)
	if _number(details.shield_debt) != "0" or _number(details.armour_debt) != "0": buffs.append("待结算伤害 · 护盾 %s · 装甲 %s" % [_number(details.shield_debt), _number(details.armour_debt)])
	_temporary.text = "\n".join(buffs) if not buffs.is_empty() else "当前没有已生效的临时标记或待结算伤害。"

func _process(dt: float) -> void:
	if not is_visible_in_tree(): return
	_elapsed += dt
	if _elapsed >= 0.5:
		_elapsed = 0.0
		_refresh()
