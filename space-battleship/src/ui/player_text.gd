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
		"ReforgePreviewRequired": "请先预览重铸结果。", "InsufficientResources": "资源不足。",
		"InvalidResearchRatio": "投入比例须在0.1%至100%之间。", "InvalidDecimal": "请输入有效的非负数，可使用科学计数法。",
		"WriteFailed": "文件写入失败，请检查剩余空间和目录权限。"}.get(reason, "操作未完成，请检查条件后重试。"))
