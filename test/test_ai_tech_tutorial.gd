extends SceneTree

const VIEW = preload("res://scripts/ai_tech_view_model.gd")
const AITech = preload("res://scripts/ai_tech_tree.gd")

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", label)
	else:
		print("PASS ", label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	check(UIText.reload_catalog().is_empty(), "tutorial text contract loads")
	var game := BattleGame.new(ShipDatabase.new(), false)
	var idle: Dictionary = VIEW.snapshot(game)
	var first: Dictionary = idle.technologies.filter(func(item): return item.id == "ai_singularity")[0]
	check(first.state_text == UIText.t("ai_tech.research.estimate", {"time":VIEW.duration(AITech.required(game,"singularity"))}), "choice estimates the next level at current speed")
	check(UIText.t("ai_tech.tutorial.research").contains("免费") and UIText.t("ai_tech.tutorial.research").contains("保留"), "first selection explains free research and preserved progress")
	check(UIText.t("ai_tech.tutorial.investment").contains("每秒") and UIText.t("ai_tech.tutorial.investment").contains("余额不足"), "optional investment explains continuous cost and shortage")
	check(UIText.t("ai_tech.investment.iron_per_second").contains("/秒") and UIText.t("ai_tech.investment.uranium_per_second").contains("/秒"), "both inputs carry per-second units")
	game.select_tech("weapon_accuracy")
	game.advance_hightech(5.0)
	var active: Dictionary = VIEW.snapshot(game).technologies.filter(func(item): return item.id == "weapon_accuracy")[0]
	var left := (AITech.required(game,"weapon_accuracy") - float(game.profile.aiTechProgress.weapon_accuracy)) / float(game.tech_tree_snapshot().speed)
	check(active.state_text == UIText.t("ai_tech.research.active_estimate", {"time":VIEW.duration(left)}), "active estimate follows current progress")
	print("AI_TECH_TUTORIAL_CHECKS=", checks, " FAILURES=", failures)
	quit(1 if failures else 0)
