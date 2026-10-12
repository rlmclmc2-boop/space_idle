extends SceneTree
var checks := 0
var failures := 0
const TEXT = preload("res://scripts/ui_text.gd")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var scene=load("res://main.tscn").instantiate()
	scene.automation_args=["--capture"]
	root.add_child(scene);scene.set_process(false);scene.automation_args=[]
	scene.game.save_enabled=false;scene.game.pending_unlocks.clear();scene.game.paused=true
	scene.game.start(1,false);scene.game.spawn_group();scene.game.paused=true
	scene.refresh_structure();scene.floats.clear();scene.damage_pending.clear()
	scene.fx_time+=5.0
	var enemy: Dictionary=scene.game.enemies[0]
	scene.enemy_render_position(enemy)
	scene.fx_time+=5.0
	var hit={"player":false,"uid":enemy.uid,"type":1,"amount":12345.0,"absorbed":7.0}
	scene.queue_damage_number(hit);scene.queue_damage_number(hit)
	check(scene.floats.is_empty() and scene.damage_pending.size()==1,"same-frame events defer projection and merge numerically")
	check(scene.damage_pending[0].amount==24690 and scene.damage_pending[0].text=="","final label string remains lazy")
	check(scene.damage_history.size()==2 and scene.damage_history[0]==scene.damage_history[1],"history preserves both actual hits")
	var expected=scene.battle_logical_point(scene.enemy_render_position(enemy)-Vector2(0,scene.enemy_render_width(enemy)+16))
	enemy.hp=0;scene.game.enemies.erase(enemy)
	scene._process(0.1)
	check(scene.floats.size()==1,"paused final display admits queued last hit")
	if not scene.floats.is_empty():
		var entry: Dictionary=scene.floats[0]
		check(entry.origin.is_equal_approx(expected),"same-frame killed enemy retains final enemy anchor")
		check(entry.text==scene.damage_feedback_text(24690.0,14.0),"final display has exact merged feedback formatting")
		check(is_equal_approx(entry.life,scene.battle_visual.damage_number_normal_duration),"pause does not age a new label")
		var frozen=scene.floats.duplicate(true)
		scene._process(0.1)
		check(scene.floats==frozen,"pause leaves clean displayed labels unchanged")
	scene.set_damage_mode(1)
	for i in 3:
		var target=enemy.duplicate(true)
		target.uid=800+i;target.slot=i;target.x=110+150*i;target.y=340;target.hp=1e100;target.max_hp=1e100
		scene.game.enemies.append(target)
		scene.enemy_render_position(target)
	scene.fx_time+=5.0
	for target in scene.game.enemies:
		for kind in [1,2]:
			scene.queue_damage_number({"player":false,"uid":target.uid,"type":kind,"amount":12345,"critical":kind==2})
	scene._process(0.0)
	check(scene.floats.size()>=3,"low-load picture displays labels at live hulls")
	for entry in scene.floats:
		check(scene.floats.filter(func(other):return other.target==entry.target).size()<=2,"existing two-label per-target cap")
		var bounds=scene.damage_text_rect(scene.battle_point(entry.pos),entry.text,entry.size)
		for obstacle in scene.damage_text_enemy_bounds():check(not bounds.intersects(obstacle),"final display avoids enemy envelope")
		for other in scene.floats:
			if not is_same(entry,other):check(not bounds.intersects(scene.damage_text_rect(scene.battle_point(other.pos),other.text,other.size)),"final labels remain readable independently")
	scene.battle_layer.queue_redraw()
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/damage-timing-low.png")
	scene.set_damage_mode(2)
	var amount={"m":1.25,"e":80.0}
	scene.queue_damage_number({"player":true,"type":2,"amount":amount,"absorbed":0,"critical":true})
	var stored=scene.damage_history.back();amount.m=9.0
	check(scene.damage_history.back()==stored,"history owns scalar growth values independently")
	for i in 45:scene.queue_damage_number({"player":false,"uid":700+i,"type":1,"amount":100+i})
	var records: Array[String]=scene.damage_history
	check(records.size()==40,"history ring keeps original forty-hit bound")
	for i in 40:
		var exact=scene.damage_feedback_text(105+i,0,true)
		var target=TEXT.t("battle.queue_damage_number.text_02",{"uid":"%s" % (705+i)})
		check(records[i]==TEXT.t("battle.damage_record",{"target":target,"critical":"","damage":exact}),"history read preserves chronological full values")
	check(scene.floats.is_empty() and scene.damage_pending.is_empty(),"hidden labels still keep per-hit history")
	scene.queue_free();await process_frame
	print("Damage display timing: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
