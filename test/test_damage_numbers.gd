extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func verify_incoming_lanes(scene) -> void:
	scene.set_damage_mode(0)
	var before=JSON.stringify(scene.game.profile);var rng=scene.game.rng.state
	var energy={"player":true,"uid":0,"type":1,"amount":100.0,"absorbed":20.0,"critical":false}
	var physical={"player":true,"uid":0,"type":2,"amount":300.0,"critical":false}
	scene.queue_damage_number(physical);scene.queue_damage_number(energy)
	var rows=scene.floats.filter(func(f):return f.get("incoming_lane",false))
	check(rows.size()==2 and scene.damage_pending.is_empty(),"incoming types occupy two rows without the shared target backlog")
	var e:Dictionary=rows.filter(func(f):return f.type==1)[0];var p:Dictionary=rows.filter(func(f):return f.type==2)[0]
	var e_pos:Vector2=e.pos;var p_pos:Vector2=p.pos
	check(e_pos.y<p_pos.y and e.text.begins_with("能量") and p.text.begins_with("物理") and e.color==scene.CYAN and p.color==scene.ORANGE,"energy stays above physical with type prefixes and distinct colors regardless of hit order")
	check(not scene.damage_text_rect(scene.battle_point(e.pos),e.text,e.size).intersects(scene.damage_text_rect(scene.battle_point(p.pos),p.text,p.size)),"the fixed incoming rows do not overlap")
	energy.amount=30.0;energy.absorbed=5.0;energy.critical=true;scene.fx_time+=0.1;scene.queue_damage_number(energy)
	check(e.amount==130 and e.absorbed==25 and e.critical and e.size>p.size and p.amount==300 and scene.floats.size()==2,"same-type ordinary and critical hits aggregate within200ms without consuming the other type row")
	var old_p:Dictionary=p.duplicate(true);scene.fx_time+=0.11;energy.amount=7.0;energy.absorbed=0;energy.critical=false;scene.queue_damage_number(energy)
	check(e.amount==7 and not e.critical and is_equal_approx(e.pos.y,e_pos.y) and p==old_p and not p.get("retiring",false),"next energy window replaces only its own fixed row without retiring physical")
	for i in 30:
		scene.fx_time+=0.21;energy.amount=i+1;scene.queue_damage_number(energy)
	check(scene.floats.size()==2 and scene.damage_pending.is_empty() and p==old_p,"sustained one-type pressure cannot evict the other type or grow a backlog")
	var uid:int=scene.game.enemies[0].uid
	for target in scene.game.enemies:scene.enemy_pose(target).born=0.0;target.hp=0 # Resolved killed-enemy fixture: no live hull can block its final damage label.
	var enemy={"player":false,"uid":uid,"type":1,"amount":12345.0,"critical":false}
	scene.queue_damage_number(enemy)
	var outgoing:Dictionary=scene.floats.filter(func(f):return f.get("target","")=="enemy:%s" % uid)[0]
	check(outgoing.text=="12.3K" and not outgoing.get("incoming_lane",false) and not scene.incoming_damage_bounds().intersects(scene.damage_text_rect(scene.battle_point(outgoing.pos),outgoing.text,outgoing.size)),"enemy damage retains compact unsigned text outside reserved incoming rows")
	check(JSON.stringify(scene.game.profile)==before and scene.game.rng.state==rng and scene.damage_history.back().contains("12345"),"display updates keep gameplay/RNG unchanged and full per-event history")
	var frozen=scene.floats.duplicate(true);scene.game.paused=true;scene._process(0.1)
	check(scene.floats==frozen,"pause freezes both incoming rows and outgoing labels")
	scene.game.paused=false;scene._process(0.1)
	check(is_equal_approx(e.pos.y,e_pos.y) and is_equal_approx(p.pos.y,p_pos.y),"incoming labels hold their type rows instead of floating into each other")
	for mode in [1,0]:
		scene.set_damage_mode(mode);scene.queue_damage_number(energy);scene.queue_damage_number(physical)
		check(scene.floats.size()==2 and scene.floats.all(func(f):return f.get("incoming_lane",false)),"both enabled modes preserve the incoming two-type rows")
	scene.set_damage_mode(2);scene.queue_damage_number(energy)
	check(scene.floats.is_empty() and scene.damage_pending.is_empty(),"off clears rows and suppresses new labels")
	scene.set_damage_mode(0);scene.game.paused=false
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
	if "--incoming-only" in OS.get_cmdline_user_args():
		verify_incoming_lanes(scene)
		scene.queue_free();await process_frame
		print("Incoming damage rows: %d checks, %d failures" % [checks,failures])
		quit(1 if failures else 0);return
	var hit := {"player":false,"uid":999,"type":1,"x":286,"y":360,"amount":12345.0}
	check(scene.damage_mode==0,"default simplified")
	scene.on_event("hit",hit)
	scene.fx_time += 0.19
	scene.on_event("hit",hit)
	check(scene.floats.size()==1 and scene.floats[0].amount==24690,"fixed 200ms aggregation preserves sum")
	hit.critical = true
	scene.on_event("hit",hit)
	check(scene.floats.size()==2 and scene.floats[1].critical and scene.floats[1].size>scene.floats[0].size,"critical separately gold and larger")
	check(scene.floats[0].text=="24.7K" and is_equal_approx(scene.floats[0].life,scene.battle_visual.damage_number_normal_duration),"unsigned three significant digits and short ordinary lifetime")
	check(is_equal_approx(scene.floats[1].life,scene.battle_visual.damage_number_critical_duration),"critical label stays distinct slightly longer")
	check(scene.NUMBER_FORMAT.damage(999999)=="1M" and scene.NUMBER_FORMAT.damage(123456789)=="123M","unit carry and common units")
	check(scene.NUMBER_FORMAT.damage(1e36)=="1.00e+36" and scene.NUMBER_FORMAT.damage(-1.234e100)=="1.23e+100","large damage uses supported scientific formatting")
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
					var half_width: float=scene.enemy_render_width(target)
					var center: Vector2=scene.enemy_render_position(target)
					var envelope := Vector2(half_width*0.6,half_width*1.15)
					var overlap: bool = scene.damage_text_rect(scene.battle_point(f.pos),f.text,f.size).intersects(Rect2(center-envelope,envelope*2.0))
					check(not overlap,"numbers avoid hull and health bar")
				for j in range(i+1,scene.floats.size()):
					var other: Dictionary = scene.floats[j]
					check(not scene.damage_text_rect(scene.battle_point(f.pos),f.text,f.size).intersects(scene.damage_text_rect(scene.battle_point(other.pos),other.text,other.size)),"adjacent labels separated")
			if frame==40:
				scene.battle_layer.queue_redraw()
				await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://.runtime/damage-mode-%d.png" % mode)
		check(mode!=2 or scene.floats.is_empty(),"off suppresses damage only")
	check(scene.equipment_tabs==tabs and static_draws[0]==0,"damage updates preserve unrelated controls and static drawing")
	scene.toast("Status notice")
	scene.on_event("collect",{"id":"1","amount":123,"x":enemy.x,"y":enemy.y})
	var reward: Dictionary = scene.floats.back()
	var notice: Rect2 = scene.battle_notice_rect(1)
	check(scene.battle_notices().size()==2 and scene.pickup_effects.size()==1,"Status and resource pickup use separate status-panel rows")
	check(Rect2(30,100,552,98).encloses(notice) and scene.pickup_effects[0].end==notice.get_center(),"Pickup flight ends inside the battle status panel")
	scene.on_event("collect",{"id":"2","amount":7,"x":enemy.x,"y":enemy.y})
	check(scene.battle_notices().size()==2 and scene.battle_notices()[1].resources.size()==2,"Simultaneous resource notices share one row")
	scene._process(0.1)
	check(reward.life<0.8 and scene.pickup_effects[0].life<0.42,"Pickup notice and flight advance together")
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
