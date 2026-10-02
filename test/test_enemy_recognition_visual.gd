extends SceneTree
## Short, isolated real-scene acceptance. Fixtures only change in-memory encounter/profile.
const GEO := preload("res://scripts/enemy_protection_geometry.gd")
var checks := 0
var failures := 0
var scene
var report := {"scenarios":[],"controlled_events":[],"renderer_mutations":false}
var frame_id := 0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func render(path := "") -> void:
	scene.refresh_draw_layers(0.0)
	scene.battle_layer.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	if not path.is_empty():root.get_texture().get_image().save_png("res://.runtime/"+path+".png")
func step() -> void:
	for j in 5:scene._process(0.02)
	await render()
	root.get_texture().get_image().save_png("res://.runtime/frames/%04d.png"%frame_id)
	frame_id+=1
func encounter(group: int) -> void:
	scene.game.profile.selectedShip="Heavy_Battleship"
	scene.game.profile.onboarding.completed=true
	scene.game.profile.loadout=scene.game.empty_loadout("Heavy_Battleship")
	for i in 4:scene.game.profile.loadout.defence[i]={"key":"armour","level":10}
	scene.game.profile.loadout.weapons[0]={"key":"laser","level":1}
	scene.db.levels[0].groups=[{"id":group,"position":0.0},{"id":group,"position":1.0}]
	scene.game.start(1,false)
	scene.game.spawn_group()
	scene.game.speed=1.0
	scene.game.pending_unlocks.clear()
	scene.enemy_poses.clear()
	scene.projectile_visuals.clear()
	scene.particles.clear()
	scene.floats.clear()
	scene.refresh_structure()
	scene.capture_frame=-10000
func audit(label: String) -> void:
	var snapshot: Array=scene.game.enemies.duplicate(true)
	var projectile_snapshot: Array=scene.game.projectiles.duplicate(true)
	var profile_snapshot: Dictionary=scene.game.profile.duplicate(true)
	var rng_state: int=scene.game.rng.state
	var clock_value: float=scene.game.enemy_shield_time
	var minimum := INF
	var mounts := 0
	for enemy in scene.game.enemies:
		if enemy.hp<=0:continue
		var packet: Dictionary=scene.enemy_recognition_geometry(enemy)
		var width: float=scene.enemy_render_width(enemy)
		var angle: float=scene.enemy_render_angle(enemy)
		for component in scene.enemy_weapon_components(enemy):
			mounts+=1
			var pose: Dictionary=scene.enemy_component_pose(enemy,component)
			var descriptor: Dictionary=scene.enemy_recognition.descriptors([component])[0]
			var actual := PackedVector2Array()
			# Independently transform actual hardpoint body corners into the hull frame.
			for p in scene.enemy_recognition.mount_corners(descriptor,width,15.0/packet.scale):
				actual.append((Vector2(pose.origin)+Vector2(p).rotated(pose.angle)).rotated(-PI-angle))
			minimum=minf(minimum,GEO.min_clearance(actual,packet.inner)*float(packet.scale)-float(packet.shield_stroke)*float(packet.scale)*0.5-0.5)
			var sweep := PackedVector2Array()
			for sample in range(25):
				var aim := lerpf(-float(descriptor.limit),float(descriptor.limit),float(sample)/24.0)
				for p in scene.enemy_recognition.mount_corners(descriptor,width,15.0/packet.scale):sweep.append(Vector2(descriptor.pos)*width+Vector2(p).rotated(float(descriptor.base)+aim))
			check(GEO.min_clearance(sweep,packet.inner)*float(packet.scale)-float(packet.shield_stroke)*float(packet.scale)*0.5-0.5>=1.99,label+" dense legal aim sweep")
		check(GEO.min_clearance(packet.audit_points,packet.inner)*float(packet.scale)-float(packet.shield_stroke)*float(packet.scale)*0.5-0.5>=1.99,label+" full legal turn envelope")
	check(minimum>=1.99,label+" actual mounted weapon pixel gap")
	check(scene.game.enemies==snapshot and scene.game.projectiles==projectile_snapshot and scene.game.profile==profile_snapshot and scene.game.rng.state==rng_state and scene.game.enemy_shield_time==clock_value,label+" renderer leaves combat, profile and RNG unchanged")
	var builds: int=scene.enemy_recognition.envelope_builds
	var scans: int=scene.enemy_recognition.hull_scans
	for i in 4:
		for enemy in scene.game.enemies:
			if enemy.hp>0:scene.enemy_recognition_geometry(enemy)
	check(builds==scene.enemy_recognition.envelope_builds and scans==scene.enemy_recognition.hull_scans,label+" stationary geometry cached")
	report.scenarios.append({"name":label,"alive":scene.game.enemies.filter(func(e):return e.hp>0).size(),"mounts":mounts,"screen_scale":scene.enemy_recognition_screen_scale(),"min_visible_gap_pixels":minimum,"actual_fields":scene.game.enemies.map(func(e):return {"id":e.id,"armourType":e.armourType,"size":e.size,"shieldType":e.shieldType,"max_shield":e.max_shield,"shieldRecovery":e.shieldRecovery,"shieldDelay":e.shieldDelay,"weapons":e.equipment.map(func(w):var row=scene.db.enemy_weapon(w.name);return {"key":w.name,"type":row.dmgtype,"damage":row.dmg,"cd":row.cd})})})
func run() -> void:
	scene=load("res://main.tscn").instantiate()
	scene.automation_args=["--capture"]
	root.add_child(scene)
	scene.set_process(false)
	scene.game.save_enabled=false
	scene.capture_frame=-10000
	DirAccess.make_dir_recursive_absolute("res://.runtime/frames")
	await process_frame
	encounter(1002)
	check(scene.game.enemies.size()==15,"authored small fleet has 15 enemies")
	for i in 18:await step()
	await render("battle-small")
	audit("15-small-energy")
	check(scene.game.projectiles.any(func(p):return p.hostile and int(p.type)==1),"actual energy enemy bullets")
	encounter(2)
	for i in 12:await step()
	await render("battle-physical")
	audit("physical-fire")
	check(scene.game.projectiles.any(func(p):return p.hostile and int(p.type)==2),"actual physical enemy shells")
	encounter(8)
	for i in 12:await step()
	await render("battle-multi-mounts")
	audit("mixed-real-multi-mounts")
	encounter(1009)
	for i in 8:await step()
	await render("battle-physical-armour")
	audit("physical-armour-fleet")
	encounter(1018)
	for i in 12:await step()
	await render("battle-large-shield")
	audit("large-energy-shield")
	var large: Dictionary=scene.game.enemies[0]
	scene.game.hit_enemy(large,float(large.shield)+1.0,2)
	await render("battle-shield-broken")
	check(not scene.enemy_recognition.state(large,scene.game.enemy_shield_time,false,scene.enemy_pose(large)).active,"actual shield break hides shield ring")
	report.controlled_events.append("large-shield: existing hit_enemy path with shield+1 physical hit; no table edit")
	for i in 5:await step()
	encounter(1004)
	for i in 8:await step()
	# Pause player weapons only in this fixture so the real recovery can become visible.
	for i in scene.game.profile.loadout.weapons.size():scene.game.profile.loadout.weapons[i]={"key":"","level":1}
	scene.game.projectiles.clear()
	var regen: Dictionary=scene.game.enemies[0]
	scene.game.hit_enemy(regen,float(regen.max_shield)*0.65,1)
	await render("battle-recovery-hit")
	var delay_state: Dictionary=scene.enemy_recognition.state(regen,scene.game.enemy_shield_time,false,scene.enemy_pose(regen))
	check(not delay_state.recovering,"hit delay shows no invented recovery")
	for i in 9:await step()
	await render("battle-recovery")
	audit("actual-shield-recovery")
	check(scene.enemy_recognition.state(regen,scene.game.enemy_shield_time,false,scene.enemy_pose(regen)).recovering,"flow follows actual shield increase")
	var draw_snapshot: Array=scene.game.enemies.duplicate(true)
	var draw_clock: float=scene.game.enemy_shield_time
	var draw_rng: int=scene.game.rng.state
	await render()
	check(scene.game.enemies==draw_snapshot and scene.game.enemy_shield_time==draw_clock and scene.game.rng.state==draw_rng,"actual draw never settles or mutates shields")
	report.controlled_events.append("regen: existing hit_enemy path with 65% max shield energy hit; player weapons emptied in memory to observe actual delay/recovery")
	scene.game.paused=true
	await render("battle-paused")
	var snapshot: Array=scene.game.enemies.duplicate(true)
	var frozen_clock: float=scene.game.enemy_shield_time
	var builds: int=scene.enemy_recognition.envelope_builds
	for i in 4:await step()
	check(scene.game.enemies==snapshot and scene.game.enemy_shield_time==frozen_clock and scene.enemy_recognition.envelope_builds==builds,"pause freezes actual shield and geometry")
	check(not scene.enemy_recognition.state(regen,frozen_clock,true,scene.enemy_pose(regen)).recovering,"paused recovery flow hidden")
	scene.game.paused=false
	scene.game.hit_enemy(regen,float(regen.max_shield)*0.1,1)
	await render("battle-recovery-interrupted")
	check(not scene.enemy_recognition.state(regen,scene.game.enemy_shield_time,false,scene.enemy_pose(regen)).recovering,"new real hit interrupts recovery flow")
	for enemy in scene.game.enemies.duplicate():scene.game.hit_enemy(enemy,1e12,1)
	scene.refresh_draw_layers(0.0)
	check(scene.enemy_poses.is_empty(),"dead ship protection cache removed")
	for i in 15:await step()
	await render("battle-cleanup")
	check(scene.enemy_poses.is_empty(),"death effects never recreate removed protection cache")
	report.controlled_events.append("regen death: existing hit_enemy path with lethal fixture hit, followed by 1.5s cleanup")
	# Check high slots 10..14, which were missed by the former fixed ten-slot cleanup.
	encounter(1002)
	await render()
	for enemy in scene.game.enemies.duplicate():scene.game.hit_enemy(enemy,1e12,2)
	scene.refresh_draw_layers(0.0)
	check(scene.enemy_poses.is_empty(),"all 15 slots clean after death")
	# Unknown/neutral rows have no invented defense marker.
	var neutral: Dictionary=scene.db.enemies["1019"].duplicate(true)
	neutral.hp=1.0
	neutral.max_shield=0.0
	neutral.shield=0.0
	var neutral_state: Dictionary=scene.enemy_recognition.state(neutral,scene.game.enemy_shield_time,false,{})
	check(not neutral_state.active and int(neutral.armourType)==0,"neutral row retains no shield/type assumption")
	report.checks=checks
	report.failures=failures
	report.frames=frame_id
	report.hull_scans=scene.enemy_recognition.hull_scans
	report.envelope_builds=scene.enemy_recognition.envelope_builds
	var file := FileAccess.open("res://.runtime/recognition-check.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("Enemy recognition: %d checks, %d failures; %d real scene frames"%[checks,failures,frame_id])
	scene.queue_free()
	scene=null
	await process_frame
	quit(1 if failures else 0)
