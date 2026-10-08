extends SceneTree
class UI extends "res://scripts/battlefield.gd":
	func create_battle_game(_persist: bool) -> BattleGame:return super.create_battle_game(false)
	func show_qa_tools() -> void:pass
	func show_chrono_login_report() -> void:pass
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:failures+=1;printerr(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var scene=load("res://main.tscn").instantiate();scene.set_script(UI);scene.automation_args=["--capture"]
	root.add_child(scene);scene.set_process(false);scene.game.save_enabled=false
	var g=scene.game;g.start(1,false);g.spawn_group();g.paused=true
	var view=scene.enemy_defence_inspector;view.set_process(false)
	await process_frame
	var enemy=g.enemies[0]
	# Distinct valid in-memory states verify actual fields, not a colour legend.
	enemy.armourType=2;enemy.max_shield=10;enemy.shield=10;enemy.shieldType=1
	var original=g.enemies.duplicate(true);var profile=g.profile.duplicate(true);var rng=g.rng.state;var clock=g.enemy_shield_time
	var point: Vector2=scene.enemy_render_position(enemy)
	view.refresh_at(point)
	check(view.panel.visible and view.description.text.contains("装甲：抵抗物理伤害") and view.description.text.contains("护盾：抵抗能量伤害"),"Hover distinguishes armour from the active shield using true fields")
	check(g.enemies==original and g.profile==profile and g.rng.state==rng and g.enemy_shield_time==clock,"Inspection does not settle shields or mutate battle, saves or RNG")
	enemy.shield=0;view.refresh_at(point)
	check(view.description.text.contains("护盾已破") and view.description.text.contains("装甲：抵抗物理伤害"),"Broken shield exposes armour without changing its resistance label")
	enemy.max_shield=0;enemy.armourType=0;view.refresh_at(point)
	check(view.description.text.contains("无护盾") and view.description.text.contains("无类型抗性"),"Neutral and unshielded enemies are explicit")
	view.refresh_at(Vector2(-10,-10));check(not view.panel.visible,"Leaving the battlefield closes the local readout")
	scene.help_open=true;view.refresh_at(point);check(not view.hint.visible and not view.panel.visible,"Existing help hides the inspection overlay")
	scene.help_open=false;g.pending_unlocks.append("missile");view.refresh_at(point);check(not view.panel.visible,"Unlock notice is not masked by inspection")
	g.pending_unlocks.clear();enemy.hp=0;view.refresh_at(point);check(not view.panel.visible,"Dead ships cannot retain a stale readout")
	check(view.mouse_filter==Control.MOUSE_FILTER_IGNORE and view.panel.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Inspection never consumes pickup, combat or GUI input")
	scene.queue_free();await process_frame
	print("Enemy defence inspector: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
