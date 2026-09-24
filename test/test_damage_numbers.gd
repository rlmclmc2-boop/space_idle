extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	scene.automation_args = ["--capture"]
	root.add_child(scene)
	scene.set_process(false)
	scene.automation_args = []
	scene.game.save_enabled = false
	scene.game.start(1,false)
	scene.game.spawn_group()
	scene.game.profile.loadout = scene.game.empty_loadout(scene.game.profile.selectedShip)
	scene.refresh_structure()
	for e in scene.game.enemies:
		e.hp = 1e9
		e.max_hp = 1e9
		e.equipment = []
	var enemy: Dictionary = scene.game.enemies[0]
	var hit := {"player":false,"uid":999,"type":1,"x":286,"y":360,"amount":12345.0}
	check(scene.damage_mode==0,"default simplified")
	scene.on_event("hit",hit)
	scene.fx_time += 0.19
	scene.on_event("hit",hit)
	check(scene.floats.size()==1 and scene.floats[0].amount==24690,"fixed 200ms aggregation preserves sum")
	hit.critical = true
	scene.on_event("hit",hit)
	check(scene.floats.size()==2 and scene.floats[1].critical and scene.floats[1].size>scene.floats[0].size,"critical separately gold and larger")
	check(scene.floats[0].text=="24.7K" and scene.floats[0].life==0.6,"unsigned three significant digits and 600ms lifetime")
	check(scene.NUMBER_FORMAT.damage(999999)=="1M" and scene.NUMBER_FORMAT.damage(123456789)=="123M","unit carry and common units")
	check(scene.damage_history.back().contains("12345"),"details preserve full event amount")
	scene.fx_time += 0.02
	hit.critical = false
	scene.on_event("hit",hit)
	check(scene.floats.size()==2 and scene.floats[0].life<=0.08,"overflow fades oldest without third label")
	scene._process(0.09)
	check(scene.floats.size()<=2,"queued label admitted after retiring label disappears")
	var frozen: Array = scene.floats.duplicate(true)
	scene.game.paused = true
	scene._process(0.1)
	check(scene.floats==frozen,"pause freezes labels")
	scene.game.paused = false
	var tabs = scene.equipment_tabs
	var static_draws := [0]
	scene.background_layer.draw.connect(func():static_draws[0]+=1)
	await process_frame
	static_draws[0] = 0
	scene.db.equipment.longLaser = [{"name":"longLaser","level":1,"dmg":3456,"dmgtype":1,"cd":0.04,"para1":1.0,"para2":3.0,"para3":0.0,"unlock":0}]
	scene.game.profile.unlocked.append("longLaser")
	scene.game.equip_slot("weapons",0,"longLaser")
	scene.refresh_structure()
	for mode in [0,1,2]:
		scene.set_damage_mode(mode)
		for frame in 60:
			# Sustained beams and repeated missile volleys use actual public hit paths.
			for target in scene.game.enemies:
				if frame%3==0:
					for missile in 5:
						scene.game.fire(scene.game.player,target,scene.db.equip("missile",1),12345,false,"missile",Vector2.ZERO)
						var shot: Dictionary = scene.game.projectiles.back()
						shot.x = target.x
						shot.y = target.y
						shot.critical = missile==0
			scene._process(0.02)
			for target in scene.game.enemies:
				check(scene.floats.filter(func(f):return f.get("target","")=="enemy:%s" % target.uid).size()<=2,"dense per-target cap")
			for i in scene.floats.size():
				var f: Dictionary = scene.floats[i]
				if not f.get("damage",false):continue
				for target in scene.game.enemies:
					var dimensions: Vector2 = scene.SHIP_VISUALS.CANVAS*scene.SHIP_VISUALS.enemy_scale_for(target)
					check(not scene.damage_text_rect(f.pos,f.text,f.size).intersects(Rect2(Vector2(target.x,target.y)-dimensions/2-Vector2(4,8),dimensions+Vector2(8,12))),"numbers avoid hull and health bar")
				for j in range(i+1,scene.floats.size()):
					var other: Dictionary = scene.floats[j]
					check(not scene.damage_text_rect(f.pos,f.text,f.size).intersects(scene.damage_text_rect(other.pos,other.text,other.size)),"adjacent labels separated")
			if frame==40:
				scene.battle_layer.queue_redraw()
				await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://.runtime/damage-mode-%d.png" % mode)
		check(mode!=2 or scene.floats.is_empty(),"off suppresses damage only")
	check(scene.equipment_tabs==tabs and static_draws[0]==0,"damage updates preserve unrelated controls and static drawing")
	scene.on_event("collect",{"id":"1","amount":123,"x":enemy.x,"y":enemy.y})
	var reward: Dictionary = scene.floats.back()
	var reward_pos: Vector2 = reward.pos
	scene._process(0.1)
	check(reward.pos==reward_pos and reward.pos.y>=500,"rewards stay in independent fixed region")
	var menu: PopupMenu = scene.guard_settings.get_popup()
	menu.id_pressed.emit(10)
	check(scene.damage_mode==0 and menu.is_item_checked(menu.get_item_index(10)),"settings select simplified locally")
	menu.id_pressed.emit(20)
	var details = scene.ui.get_child(scene.ui.get_child_count()-1)
	check(details is AcceptDialog and details.visible,"full value details opens")
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/damage-details.png")
	details.get_ok_button().grab_focus()
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	details.push_input(enter)
	enter = enter.duplicate()
	enter.pressed = false
	details.push_input(enter)
	await process_frame
	check(not is_instance_valid(details),"details confirms and frees with actual keyboard input")
	scene.queue_free()
	await process_frame
	print("Damage numbers: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
