extends SceneTree

const TECH = preload("res://scripts/ai_tech_tree.gd")
const DB = preload("res://scripts/database.gd")
const GAME = preload("res://scripts/game.gd")
const MAIN = preload("res://scripts/main.gd")

class ResearchGame:
	extends RefCounted
	signal event(kind: String, payload: Dictionary)
	var db := {"data": {"ai_tech_tree": {}}}
	var profile := {"aiTechLevels": {}, "aiTechProgress": {}, "aiTechActive": "weapon_accuracy", "aiTechInput": {"1": 10, "2": 0}, "resources": {"1": 10000.0, "2": 0.0}, "aiTechCompletionUnread": false}
	var stat_cache_enabled := false
	var stat_cache := {}
	var ai_tech_last_resource_notice_ms := 0
	var save_dirty := false
	func ai_tech_factory_unlocked() -> bool: return true
	func content_unlocked(_kind:String,_key:String) -> bool: return true
	func enhancement_unlocked() -> bool: return false
	func native_before_configuration_change() -> bool: return true
	func invalidate_stat_cache() -> void: pass
	func resources_changed(_ids: Array) -> void: pass

func _initialize() -> void:
	var research := ResearchGame.new()
	research.db.data.ai_tech_tree = JSON.parse_string(FileAccess.get_file_as_string("res://data/ai_tech_tree.json"))
	var speed := TECH.input_factor(10)
	var first_duration: float = TECH.required(research,"weapon_accuracy")
	TECH.advance(research,first_duration/speed)
	var ok := int(research.profile.aiTechLevels.get("weapon_accuracy",0)) == 1
	ok = ok and research.profile.aiTechActive == "weapon_accuracy" and float(research.profile.aiTechProgress.get("weapon_accuracy",0.0)) == 0.0
	ok = ok and bool(research.profile.aiTechCompletionUnread) and research.save_dirty
	research.profile.aiTechCompletionUnread = false
	var second_duration: float = TECH.required(research,"weapon_accuracy")
	TECH.advance(research,second_duration/speed)
	ok = ok and research.profile.aiTechLevels.weapon_accuracy == 2 and research.profile.aiTechActive == "weapon_accuracy"
	ok = ok and bool(research.profile.aiTechCompletionUnread)
	var expected_cost: float = 10.0 * (first_duration+second_duration)/speed
	ok = ok and absf(float(research.profile.resources["1"]) - (10000.0 - expected_cost)) < 0.01
	TECH.advance(research,1.0)
	ok = ok and float(research.profile.aiTechProgress.weapon_accuracy) > 0.0
	var saved_game = GAME.new(DB.new(),false)
	saved_game.profile.aiTechCompletionUnread = true
	var saved: Dictionary = JSON.parse_string(JSON.stringify(saved_game.portable_save_data()))
	var restored = GAME.new(DB.new(),false)
	restored.load_hightech(saved)
	ok = ok and bool(restored.profile.aiTechCompletionUnread)
	var host = MAIN.new()
	host.game = restored
	host.system_nav_buttons.append(Button.new())
	var tech_nav := Button.new()
	var dot := Control.new()
	dot.name = "ActivationBadge"
	dot.visible = false
	tech_nav.add_child(dot)
	host.system_nav_buttons.append(tech_nav)
	host.refresh_ai_tech_completion_badge()
	ok = ok and dot.visible
	restored.save_dirty = false
	ok = ok and restored.read_ai_tech_completion() and not restored.profile.aiTechCompletionUnread and restored.save_dirty
	host.refresh_ai_tech_completion_badge()
	ok = ok and not dot.visible
	ok = ok and not bool(restored.portable_save_data().aiTechCompletionUnread)
	host.system_nav_buttons[0].free()
	tech_nav.free()
	host.free()
	if not ok:
		printerr("TECH_CONTINUOUS_BADGE_FAIL ", research.profile, " saved=", saved.get("aiTechCompletionUnread"), " restored=", restored.profile.aiTechCompletionUnread)
		quit(1)
		return
	print("TECH_CONTINUOUS_BADGE_OK level=2 active=weapon_accuracy balance=", research.profile.resources["1"], " saved_unread=", saved.aiTechCompletionUnread, " restored_clear=true")
	quit()
