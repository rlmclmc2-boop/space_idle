extends RefCounted
## Presentation names only. Stable business IDs and saved data stay unchanged.
const RESOURCES := {"1": "铁", "2": "铀", "jewel": "强化碎片", "chrono": "时空微粒"}
const STATES := {"menu": "待命", "departing": "离港", "travel": "航行", "combat": "战斗", "waiting": "通关等待", "guard_wait": "驻守等待", "retreat": "撤退", "hyperspace": "超空间战斗"}
const TOPICS := {"unlock": "解锁", "research": "研究完成", "hyperspace": "超空间奖励"}

var _unlocks: Dictionary = {}
var _research: Dictionary = {}

func _init(configuration: Dictionary = {}) -> void:
	for row in configuration.get("unlock", {}).get("unlock", []):
		_unlocks[str(row.type) + ":" + str(row.target)] = row
	for row in configuration.get("ai_tech_tree", {}).get("ai_tech_tree", []):
		_research[str(row.id)] = str(row.name)

func notification_text(topic: String, id: String) -> String:
	if topic == "unlock":
		var row: Dictionary = _unlocks.get(id.trim_prefix("unlock:"), {})
		return str(row.get("title", "新功能")) + "：" + str(row.get("desc", "新内容已开放，可在成长页查看。"))
	if topic == "research":
		var pieces: PackedStringArray = id.split(":")
		return str(_research.get(pieces[0], "科研项目")) + (" · 等级 " + pieces[1] if pieces.size() > 1 else "已完成")
	return "超空间挑战奖励已就绪，请前往超空间领取。"

static func resource(id: String) -> String:
	return str(RESOURCES.get(id, "资源"))

static func state(id: String) -> String:
	return str(STATES.get(id, "待命"))

static func wrap(label: Label) -> void:
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

static func error(reason: String) -> String:
	return str({"SettingsWriteFailed": "个人设置未能写入文件，请检查目录权限。", "InvalidSettings": "个人设置文件无效。",
		"SaveDirectoryRequired": "请选择可写的存档目录。", "InvalidPrimarySave": "主存档无效，请尝试备份或导入有效存档。",
		"InvalidBackup": "没有可读取的有效备份。", "ConfigurationMismatch": "存档与当前游戏配置不一致。",
		"ImportPreviewRequired": "请先预览要导入的存档。", "NewGamePreviewRequired": "请先预览新游戏。",
		"ReforgePreviewRequired": "请先预览重铸结果。", "HyperspaceManualActive": "请先退出手动超空间挑战，再出击主线关卡。", "InsufficientResources": "资源不足。",
		"InvalidResearchRatio": "投入比例须在0.1%至100%之间。", "InvalidDecimal": "请输入有效的非负数，可使用科学计数法。",
		"WriteFailed": "文件写入失败，请检查剩余空间和目录权限。"}.get(reason, "操作未完成，请检查条件后重试。"))


static var _number_pattern: RegEx

# Presentation only: Amount remains the owner of value arithmetic and precision.
# Round decimal digits, never convert an Amount or its exponent to float.
static func number(value: String) -> String:
	if _number_pattern == null:
		_number_pattern = RegEx.new()
		_number_pattern.compile("^([+-]?)([0-9]+(?:\\.[0-9]*)?|\\.[0-9]+)(?:[eE]([+-]?[0-9]+))?$")
	var matched: RegExMatch = _number_pattern.search(value.strip_edges())
	if matched == null: return "—"
	var sign: String = "-" if matched.get_string(1) == "-" else ""
	var parts: PackedStringArray = matched.get_string(2).split(".")
	var whole: String = parts[0]
	var significant: String = (whole + (parts[1] if parts.size() > 1 else "")).lstrip("0")
	if significant.is_empty(): return "0"
	var leading: int = (whole + (parts[1] if parts.size() > 1 else "")).length() - significant.length()
	var raw_exponent: String = matched.get_string(3)
	var exponent_digits: String = raw_exponent.trim_prefix("-").trim_prefix("+").lstrip("0")
	if exponent_digits.is_empty(): exponent_digits = "0"
	if exponent_digits.length() > 15:
		if raw_exponent.begins_with("-"): return "0"
		var large_magnitude: String = _add_decimal_offset(exponent_digits, whole.length() - leading - 1)
		var large_tenths: int = _round_tenths(significant, 0, 0)
		if large_tenths == 100:
			large_tenths = 10
			large_magnitude = _add_decimal_offset(large_magnitude, 1)
		return sign + _tenths_text(large_tenths) + "e" + large_magnitude
	var magnitude: int = raw_exponent.to_int() + whole.length() - leading - 1
	var unit_index: int = -1
	if magnitude >= 15 and magnitude < 18: unit_index = 4
	elif magnitude >= 12 and magnitude < 15: unit_index = 3
	elif magnitude >= 9 and magnitude < 12: unit_index = 2
	elif magnitude >= 6 and magnitude < 9: unit_index = 1
	elif magnitude >= 3 and magnitude < 6: unit_index = 0
	if magnitude >= 18:
		var sci_tenths: int = _round_tenths(significant, magnitude, magnitude)
		if sci_tenths == 100:
			sci_tenths = 10
			magnitude += 1
		return sign + _tenths_text(sci_tenths) + "e" + str(magnitude)
	var scale: int = [3, 6, 9, 12, 15][unit_index] if unit_index >= 0 else 0
	var tenths: int = _round_tenths(significant, magnitude, scale)
	if tenths == 0: return "0"
	if tenths == 10000:
		unit_index += 1
		tenths = 10
		if unit_index == 5: return sign + "1.0e18"
	return sign + _tenths_text(tenths) + (["k", "m", "b", "t", "kt"][unit_index] if unit_index >= 0 else "")

static func _round_tenths(significant: String, magnitude: int, scale: int) -> int:
	var kept: int = magnitude - scale + 2
	if kept < 0: return 0
	var whole_digits: String = significant.substr(0, kept) if kept > 0 else ""
	if whole_digits.length() < kept: whole_digits += "0".repeat(kept - whole_digits.length())
	var result: int = whole_digits.to_int() if not whole_digits.is_empty() else 0
	if kept < significant.length() and significant.substr(kept, 1).to_int() >= 5: result += 1
	return result

static func _tenths_text(tenths: int) -> String:
	return str(tenths / 10) + "." + str(tenths % 10)

static func _add_decimal_offset(digits: String, offset: int) -> String:
	var out: String = ""
	var carry: int = offset
	for index in range(digits.length() - 1, -1, -1):
		var total: int = digits.substr(index, 1).to_int() + carry
		var digit: int = total % 10
		if digit < 0: digit += 10
		carry = (total - digit) / 10
		out = str(digit) + out
	if carry > 0: out = str(carry) + out
	return out.lstrip("0")
