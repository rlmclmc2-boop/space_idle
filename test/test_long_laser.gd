extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)
func fixture() -> BattleGame:
	var db := ShipDatabase.new()
	db.equipment.longLaser = [{"name":"longLaser", "level":1,"dmg":10,"dmgtype":1,"cd":0.2,"para1":1.0,"para2":3.0,"unlock":0}]
	db.equipment.erase("longLaser-mon")
	var g := BattleGame.new(db, false)
	g.start(1, false)
	g.spawn_group()
	g.profile.loadout = g.empty_loadout(g.profile.selectedShip)
	g.profile.loadout.defence[0] = {"key":"armour","level":1}
	g.profile.unlocked = ["longLaser","armour"]
	check(g.equip_slot("weapons",0,"longLaser"), "weapon installs")
	for e in g.enemies:
		e.hp = 100000
		e.armourType = 2
		e.equipment = []
	return g
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var g := fixture()
	var target := g.targets(1)[0]
	g.tick(0.1)
	check(g.projectiles.size() == 1 and target.hp == 100000, "lock connects without immediate damage")
	var beam: Dictionary = g.projectiles[0]
	g.tick(0.1)
	check(target.hp == 99986, "first cd hit uses elapsed 0.2 multiplier 1.4")
	g.tick(0.8)
	check(target.hp == 99890, "multiple scheduled ticks ramp to cap")
	g.tick(0.4)
	check(target.hp == 99830 and is_same(g.projectiles[0],beam), "cap maintained and beam reused")
	g.paused = true
	g.tick(1)
	check(target.hp == 99830 and is_equal_approx(beam.elapsed,1.4), "pause freezes damage and ramp")
	g.paused = false
	target.x += 100
	g.player.x += 10
	g.tick(0.05)
	check(is_same(beam.target,target) and is_equal_approx(beam.x,g.player.x+g.player_weapon_offset(0).x), "lock retained and muzzle follows")
	g.projectiles.clear()
	g.tick(0.1)
	check(target.hp == 99830 and is_equal_approx(g.projectiles[0].elapsed,0.1), "interruption starts fresh cd")
	g.tick(0.1)
	check(g.projectiles[0].ticks == 1, "reconnected beam begins first tick")
	var old: Dictionary = g.projectiles[0]
	old.target.hp = 0
	g.tick(0.1)
	check(not g.projectiles.has(old) and g.projectiles.size()==1 and g.projectiles[0].ticks==0, "death retarget resets ramp and cd")
	old = g.projectiles[0]
	g.enemies.erase(old.target)
	g.tick(0.1)
	check(not g.projectiles.has(old), "lost target removes beam")
	g.profile.loadout.weapons[0] = {"key":"", "level":1}
	g.tick(0.1)
	check(g.projectiles.is_empty(), "removed mount interrupts beam")
	var hostile := fixture()
	hostile.profile.loadout = hostile.empty_loadout(hostile.profile.selectedShip)
	hostile.player.armour = 100000
	hostile.player.shield = 0
	var shooter: Dictionary = hostile.enemies[0]
	shooter.equipment = [{"name":"longLaser-mon"},{"name":"longLaser-mon"}]
	shooter.cooldowns = [0.0,0.0]
	hostile.tick(0.1)
	check(hostile.projectiles.size()==2 and hostile.player.armour==100000, "enemy mounts independently lock without damage")
	hostile.tick(0.1)
	check(hostile.player.armour<100000 and hostile.projectiles[0].ticks==1, "enemy periodic damage")
	shooter.hp = 0
	hostile.tick(0.01)
	check(hostile.projectiles.is_empty(), "shooter death interrupts both beams")
	var switched := fixture()
	switched.tick(0.4)
	var previous: Dictionary = switched.projectiles[0]
	previous.target = switched.targets(1)[1]
	switched.tick(0.1)
	check(not switched.projectiles.has(previous) and switched.projectiles[0].ticks==0, "target switch resets timing")
	switched.change_state(BattleGame.State.TRAVEL)
	check(switched.projectiles.is_empty(), "combat interruption removes beam immediately")
	var stepped := fixture()
	var batched := fixture()
	for i in range(14):
		stepped.tick(0.1)
	batched.tick(1.4)
	check(stepped.targets(1)[0].hp==batched.targets(1)[0].hp, "damage independent of step partition")
	var charged := fixture()
	charged.db.equipment.longLaser[0].para3 = 0.6
	var victim := charged.targets(1)[0]
	charged.tick(0.59)
	check(victim.hp==100000 and charged.projectiles[0].ticks==0, "charge suppresses damage before para3")
	charged.paused = true
	charged.tick(1)
	check(is_equal_approx(charged.projectiles[0].elapsed,0.59), "pause freezes charge")
	charged.paused = false
	charged.tick(0.01)
	check(victim.hp==99990 and charged.projectiles[0].ticks==1, "charge completion hits once at base damage")
	charged.tick(0.2)
	check(victim.hp==99976, "subsequent cd ramps only after charge")
	charged.projectiles.clear()
	charged.tick(0.3)
	check(victim.hp==99976 and charged.projectiles[0].ticks==0, "interruption requires full recharge")
	charged.db.equipment["longLaser-mon"] = [{"name":"longLaser-mon","level":1,"para3":null}]
	check(charged.db.enemy_weapon("longLaser-mon").para3==0.6, "enemy charge inherits missing field")
	charged.db.equipment["longLaser-mon"][0].para3 = 0.9
	check(charged.db.enemy_weapon("longLaser-mon").para3==0.9, "enemy explicit charge preserved")
	charged.profile.loadout = charged.empty_loadout(charged.profile.selectedShip)
	charged.projectiles.clear()
	var charging_enemy: Dictionary = charged.enemies[0]
	charging_enemy.equipment = [{"name":"longLaser-mon"}]
	charging_enemy.cooldowns = [0.0]
	charged.player.armour = 100000
	charged.tick(0.89)
	check(charged.projectiles[0].ticks==0, "enemy waits its own para3")
	charged.tick(0.01)
	check(charged.projectiles[0].ticks==1, "enemy fires at charge boundary")
	var instant := fixture()
	instant.db.equipment.longLaser[0].para3 = 0.0
	instant.tick(0)
	check(instant.projectiles[0].ticks==1, "explicit zero charge fires immediately")
	var twin := fixture()
	twin.db.equipment.longLaser[0].para3 = 0.2
	twin.db.config.equipmentSocket = 10
	twin.db.data.jewel["6"].para_2 = 1.0
	twin.db.data.jewel["6"].para_4 = 0.2
	var twin_entry := twin.slot_entry("weapons",0)
	twin_entry.sockets = [twin.new_jewel("6",1)]
	twin.tick(0.2)
	check(twin.jewel_repeats.size()==1, "primary beam enters shared repeat queue")
	twin.advance_jewel_repeats(0.49)
	check(twin.projectiles.size()==1, "secondary waits repeat delay")
	twin.advance_jewel_repeats(0.01)
	check(twin.projectiles.size()==2, "repeat creates persistent secondary beam")
	var primary: Dictionary = twin.projectiles[0]
	var secondary: Dictionary = twin.projectiles[1]
	check(not is_same(primary.target,secondary.target), "secondary prefers a different living target")
	var secondary_hp: float = secondary.target.hp
	twin.tick_projectiles(0.1)
	check(secondary.target.hp==secondary_hp and secondary.ticks==0, "secondary independently charges")
	twin.tick_projectiles(0.1)
	check(secondary.target.hp==secondary_hp-12, "secondary first hit applies repeat multiplier without inherited ramp")
	twin.db.equipment.longLaser[0].cri = 1.0
	twin.db.config.baseCriDmg = 2.0
	secondary_hp = secondary.target.hp
	twin.tick_projectiles(0.2)
	check(secondary.target.hp==secondary_hp-34, "secondary combines critical repeat and independent ramp")
	twin_entry.sockets.append(twin.new_jewel("3",1))
	twin_entry.sockets.append(twin.new_jewel("4",1))
	twin.db.data.jewel["4"].para_2 = 1.0
	twin.tick_projectiles(0.2)
	check(primary.target.get("jewelIronStacks",0)>0 and secondary.target.get("jewelIronStacks",0)>0, "both beams apply shared hit effects")
	check(secondary.target.get("interference",0)>0, "secondary applies interference status")
	for i in 20:
		twin.tick(0.1)
	check(twin.projectiles.size()==2 and twin.jewel_repeats.is_empty(), "repeat beams neither recurse nor accumulate each cd")
	secondary.target.hp = 0
	twin.tick(0.2)
	twin.advance_jewel_repeats(0.5)
	check(twin.projectiles.size()==1 and twin.jewel_repeats.is_empty() and not twin.projectiles.has(secondary), "lost secondary cannot reroll double fire on continued primary")
	twin.profile.loadout.weapons[0] = {"key":"", "level":1}
	twin.tick(0.1)
	check(twin.projectiles.is_empty(), "unequipped mount removes both beams")
	var solo := fixture()
	solo.enemies.resize(1)
	solo.db.equipment.longLaser[0].para3 = 0.2
	solo.db.config.equipmentSocket = 10
	solo.db.data.jewel["6"].para_2 = 1.0
	solo.slot_entry("weapons",0).sockets = [solo.new_jewel("6",1)]
	solo.tick(0.2)
	solo.advance_jewel_repeats(0.5)
	check(solo.projectiles.size()==2 and is_same(solo.projectiles[0].target,solo.projectiles[1].target), "single target supports two beams")
	check(solo.projectiles[0].x!=solo.projectiles[1].x, "same-target beams have distinct muzzle offsets")
	var cancel := fixture()
	cancel.db.config.equipmentSocket = 10
	cancel.db.data.jewel["6"].para_2 = 1.0
	cancel.slot_entry("weapons",0).sockets = [cancel.new_jewel("6",1)]
	cancel.tick(0.2)
	cancel.projectiles.clear()
	cancel.advance_jewel_repeats(0.5)
	check(cancel.projectiles.is_empty() and cancel.jewel_repeats.is_empty(), "broken parent cancels delayed secondary")
	var sustained := fixture()
	sustained.db.equipment.longLaser[0].para3 = 0.6
	sustained.db.equipment.longLaser[0].para2 = 1.0
	sustained.tick(0.2)
	var sustained_beam: Dictionary = sustained.projectiles[0]
	var sustained_target: Dictionary = sustained_beam.target
	sustained.cooldowns.weapons_0 = 0.37
	sustained.db.config.equipmentSocket = 10
	sustained.db.data.jewel["8"].para_2 = 0.6
	sustained.db.data.jewel["8"].para_4 = 1
	sustained.profile.loadout.defence[0] = {"key":"armour","level":1,"sockets":[sustained.new_jewel("8",1)]}
	sustained.jewel_defence_hit(0)
	check(sustained.cooldowns.weapons_0==0.37 and sustained_beam.elapsed==0.2, "charge changes neither beam cd nor windup")
	sustained.tick(0.39)
	check(sustained_target.hp==100000, "charge buff does not skip windup")
	sustained.tick(0.01)
	sustained.tick(0.2)
	check(sustained_target.hp==99968, "charge damage persists across successive ticks")
	sustained.apply_jewel_charge(0,1.6)
	sustained.apply_jewel_charge(0,1.2)
	check(sustained_beam.charged_multiplier==1.6, "retrigger refreshes highest multiplier without stacking")
	sustained.lock_long_laser(sustained.player,sustained.db.equip("longLaser",1),false,0,sustained.slot_entry("weapons",0),true,1.2)
	var sustained_extra: Dictionary = sustained.projectiles[1]
	check(sustained_extra.charged_multiplier==1.0, "new secondary does not inherit old charge buff")
	sustained.apply_jewel_charge(0,1.8)
	check(sustained_beam.charged_multiplier==1.8 and sustained_extra.charged_multiplier==1.8, "selected mount buffs both existing beams")
	var extra_hp: float = sustained_extra.target.hp
	sustained.tick_projectiles(0.6)
	check(sustained_extra.target.hp==extra_hp-22, "secondary combines repeat and persistent charge once")
	sustained.projectiles.erase(sustained_beam)
	sustained.tick(0.01)
	var replacement: Dictionary = sustained.projectiles.filter(func(p):return not p.repeated)[0]
	check(replacement.charged_multiplier==1.0 and sustained_extra.charged_multiplier==1.8, "broken beam loses buff independently of surviving secondary")
	var queued_charge := fixture()
	queued_charge.apply_jewel_charge(0,1.6)
	queued_charge.tick(0.1)
	check(queued_charge.projectiles[0].charged_multiplier==1.6 and queued_charge.jewel_charged.is_empty(), "idle mount consumes pending charge into next beam instance")
	var once := fixture()
	once.db.config.equipmentSocket = 10
	once.db.equipment.longLaser[0].para3 = 0.6
	once.db.data.jewel["6"].para_2 = 0.0
	once.slot_entry("weapons",0).sockets = [once.new_jewel("6",1)]
	once.tick(0.59)
	check(once.jewel_repeats.is_empty(), "windup does not roll double fire")
	once.tick(0.01)
	check(once.jewel_repeats.is_empty(), "first emission can fail double fire roll")
	once.db.data.jewel["6"].para_2 = 1.0
	for i in 20:once.tick(0.1)
	check(once.projectiles.size()==1 and once.jewel_repeats.is_empty(), "later damage ticks never retry failed first roll")
	once.projectiles.clear()
	once.tick(0.6)
	check(once.jewel_repeats.size()==1, "new lock and emission rolls once again")
	var scene = load("res://main.tscn").instantiate()
	scene.automation_args = ["--capture"]
	root.add_child(scene)
	scene.automation_args = []
	scene.set_process(false)
	scene.game.save_enabled = false
	scene.db.equipment.longLaser[0].para3 = null
	scene.game.start(1,false)
	scene.game.spawn_group()
	scene.game.profile.unlocked.append("longLaser")
	scene.game.profile.loadout = scene.game.empty_loadout(scene.game.profile.selectedShip)
	scene.game.profile.loadout.defence[0] = {"key":"armour","level":1}
	check(scene.game.equip_slot("weapons",0,"longLaser"), "UI fixture equips real configuration")
	for e in scene.game.enemies:
		e.hp = 100000
		e.equipment = []
	scene.game.tick(0.01)
	scene.refresh_structure()
	var card = scene.equipment_panel.cards.weapons_0
	var background_draws := [0]
	scene._process(0)
	await process_frame
	await RenderingServer.frame_post_draw
	scene.background_layer.draw.connect(func():background_draws[0]+=1)
	scene.battle_layer.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/long-laser.png")
	check(scene.equipment_panel.cards.weapons_0==card and background_draws[0]==0, "beam redraw preserves equipment card and static background")
	var live: Dictionary = scene.game.projectiles[0]
	var low: Dictionary = scene.beam_style(live)
	var events := [0]
	scene.game.event.connect(func(kind,_info):
		if kind=="beam_hit":events[0]+=1)
	scene.game.tick(0.19)
	check(events[0]==1 and scene.particles.any(func(p):return p.has("flash") and p.size<=8.0 and p.duration<=0.08), "each CD emits a small burn flash through existing particles")
	var flash: Dictionary = scene.beam_style(live)
	scene.game.tick(0.12)
	check(float(flash.width)>float(scene.beam_style(live).width), "CD pulse decays between hits")
	scene.game.tick(1.68)
	scene.sync_beam_visuals()
	check(events[0]==10 and scene.beam_visuals[0].full, "all scheduled hits notify and full power triggers")
	check(float(scene.beam_style(live).width)>float(low.width) and float(scene.beam_style(live).glow)>float(low.glow), "width and glow grow with damage multiplier")
	var count: int = scene.particles.size()
	scene.sync_beam_visuals()
	check(scene.particles.size()==count, "full power feedback occurs once per lock")
	scene.battle_layer.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/long-laser-full.png")
	scene.game.paused = true
	var life: float = scene.particles.back().life
	scene._process(0.1)
	check(scene.particles.back().life==life and scene.particles.size()==count, "pause freezes feedback without repeated effects")
	scene.game.paused = false
	scene.game.projectiles.clear()
	scene.sync_beam_visuals()
	check(scene.beam_visuals.is_empty() and scene.particles.any(func(p):return p.has("beam_end")), "interruption leaves a short retracting afterglow")
	count = scene.particles.size()
	scene.sync_beam_visuals()
	check(scene.particles.size()==count, "interruption feedback fires once")
	scene.battle_layer.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/long-laser-break.png")
	check(scene.equipment_panel.cards.weapons_0==card and background_draws[0]==0, "all feedback preserves static layers and equipment instances")
	scene.particles.clear()
	scene.floats.clear()
	scene.battle_layer.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var uncharged_image := root.get_texture().get_image()
	scene.db.equipment.longLaser[0].para3 = 1.0
	scene.game.tick(0.5)
	scene.sync_beam_visuals()
	var charging: Dictionary = scene.game.projectiles[0]
	scene.particles.clear() # Check charge itself, without a launch flash masking occlusion.
	check(charging.ticks==0 and scene.beam_style(charging).power==0, "charging does not grow damage visual")
	scene.battle_layer.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/long-laser-charge.png")
	var charge_image := root.get_texture().get_image()
	var visible_muzzle: Vector2 = scene.battle_layer.get_global_transform_with_canvas()*scene.battle_point(scene.visual_muzzle(charging))
	var logical_size := Vector2(ProjectSettings.get_setting("display/window/size/viewport_width"), ProjectSettings.get_setting("display/window/size/viewport_height"))
	visible_muzzle*=Vector2(charge_image.get_size())/logical_size
	var bright_core := false
	for x in range(maxi(0,int(visible_muzzle.x)-45),mini(charge_image.get_width(),int(visible_muzzle.x)+46)):
		for y in range(maxi(0,int(visible_muzzle.y)-45),mini(charge_image.get_height(),int(visible_muzzle.y)+46)):
			var pixel := charge_image.get_pixel(x,y)
			if pixel.g>0.75 and pixel.b>0.75 and pixel.b>pixel.r*1.2:
				bright_core=true
	check(bright_core,"charging bright core stays visible in front of the hull")
	check(scene.equipment_panel.cards.weapons_0==card and background_draws[0]==0, "charge drawing preserves unrelated UI")
	scene.db.config.equipmentSocket = 10
	scene.db.data.jewel["6"].para_2 = 1.0
	scene.game.slot_entry("weapons",0).sockets = [scene.game.new_jewel("6",1)]
	scene.game.tick(0.5)
	scene.game.advance_jewel_repeats(0.5)
	scene.game.tick_projectiles(1.0)
	scene.sync_beam_visuals()
	scene.battle_layer.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/long-laser-twin.png")
	check(scene.game.projectiles.size()==2 and scene.equipment_panel.cards.weapons_0==card and background_draws[0]==0, "two beam rendering preserves unrelated UI")
	scene.queue_free()
	await process_frame
	print("Long laser: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

