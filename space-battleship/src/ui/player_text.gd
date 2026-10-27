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
# Parse the exponent as text first, so an extreme Amount never becomes float INF.
static func number(value: String) -> String:
	if _number_pattern == null:
		_number_pattern = RegEx.new()
		_number_pattern.compile("^([+-]?)([0-9]+(?:\\.[0-9]*)?|\\.[0-9]+)(?:[eE]([+-]?[0-9]+))?$")
	var matched: RegExMatch = _number_pattern.search(value.strip_edges())
	if matched == null: return "—"
	var sign: String = "-" if matched.get_string(1) == "-" else ""
	var mantissa: String = matched.get_string(2)
	var parts: PackedStringArray = mantissa.split(".")
	var whole: String = parts[0]
	var digits: String = whole + (parts[1] if parts.size() > 1 else "")
	var significant: String = digits.lstrip("0")
	if significant.is_empty(): return "0"
	var exponent: String = matched.get_string(3)
	var negative_exponent: bool = exponent.begins_with("-")
	exponent = exponent.trim_prefix("-").trim_prefix("+").lstrip("0")
	if exponent.is_empty(): exponent = "0"
	if negative_exponent and exponent != "0": exponent = "-" + exponent
	if exponent.trim_prefix("-").length() > 9:
		# Keep an unbounded exponent verbatim rather than overflow a native integer.
		if "." in mantissa:
			mantissa = mantissa.rstrip("0").trim_suffix(".")
		if mantissa.length() > 24: mantissa = mantissa.substr(0, 20) + "…"
		return sign + mantissa + "×10^" + exponent
	var leading: int = digits.length() - significant.length()
	var magnitude: int = exponent.to_int() + whole.length() - leading - 1
	var prefix: String = significant.substr(0, 15)
	var coefficient: float = prefix.to_float() / pow(10.0, prefix.length() - 1)
	if magnitude >= -4 and magnitude < 4:
		var decimals: int = maxi(2, 2 - magnitude) if magnitude < 0 else 2
		return sign + _group_decimal(_decimal_text(coefficient * pow(10.0, magnitude), decimals))
	if magnitude >= 4 and magnitude < 20:
		var units := ["万", "亿", "兆", "京"]
		var unit_index: int = mini(3, magnitude / 4 - 1)
		var scaled: float = coefficient * pow(10.0, magnitude - (unit_index + 1) * 4)
		if scaled >= 9999.995 and unit_index < 3:
			unit_index += 1
			scaled /= 10000.0
		return sign + _decimal_text(scaled, 2) + units[unit_index]
	if coefficient >= 9.9995:
		coefficient = 1.0
		magnitude += 1
	return sign + _decimal_text(coefficient, 3) + "×10^" + str(magnitude)

static func _decimal_text(value: float, decimals: int) -> String:
	var result: String = ("%." + str(decimals) + "f") % value
	if "." in result: result = result.rstrip("0").trim_suffix(".")
	return result

static func _group_decimal(value: String) -> String:
	var parts: PackedStringArray = value.split(".")
	var whole: String = parts[0]
	var grouped: String = ""
	for index in whole.length():
		if index > 0 and (whole.length() - index) % 3 == 0: grouped += ","
		grouped += whole[index]
	return grouped + ("." + parts[1] if parts.size() > 1 else "")
