extends SceneTree

const UI = preload("res://scripts/ui_text.gd")
const ENEMY_INTEL = preload("res://scripts/enemy_intel_page.gd")

func _initialize() -> void:
	var errors := UI.reload_catalog()
	if not errors.is_empty():
		printerr("UI catalog failed: ", errors)
		quit(1)
		return
	var waiting := UI.t("onboarding.waiting", {"cost": "25铁"})
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_data.json"))
	var reactor: String = data.unlock["reactor"].desc
	var shield: String = data.unlock["shield"].desc
	var unlocks_concise := true
	for row in data.unlock.values():
		var description: String = row.desc
		if not (description.ends_with("已解锁。") or description == "新行星已发现。"):
			unlocks_concise = false
	var ok := waiting == "槽位升级需要25铁。资源数量显示在顶部资源栏。"
	ok = ok and reactor == "反应炉已解锁。" and shield == "偏转护盾已解锁。"
	ok = ok and unlocks_concise and data.unlock.size() == 46
	ok = ok and UI.t("onboarding.unlock_auto").contains("自动跳过")
	ok = ok and UI.t("ai_tech.tutorial.research").contains("每完成一级即停止")
	var intel = ENEMY_INTEL.new()
	ok = ok and intel.duration_text(1.8) == "1.8 秒" and intel.duration_text(0.25) == "0.25 秒"
	intel.free()
	if not ok:
		printerr("Copy rendering mismatch: ", JSON.stringify({"waiting": waiting, "reactor": reactor, "shield": shield}))
		quit(1)
		return
	print("COPY_CHECK_OK ", JSON.stringify({"waiting": waiting, "reactor": reactor, "shield": shield, "auto_skip": UI.t("onboarding.unlock_auto")}))
	quit()
