extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	scene.automation_args = ["--capture"]
	root.add_child(scene)
	scene.set_process(false)
	scene.game.save_enabled = false
	scene.game.start(1,false)
	scene.game.spawn_group()
	for enemy in scene.game.enemies:
		enemy.hp = 100000
		enemy.equipment = []
	scene.game.profile.unlocked = ["missile","cannon","laser"]
	scene.game.profile.loadout.weapons = [{"key":"missile","level":1},{"key":"cannon","level":1},{"key":"laser","level":1}]
	scene.refresh_structure()
	var index := 0
	for key in ["missile","cannon","laser"]:
		scene.game.fire(scene.game.player,scene.game.enemies[index],scene.db.equip(key,1),10,false,key,scene.game.player_weapon_offset(index))
		index += 1
	check(scene.projectile_visuals.size()==3,"launch creates one fixed visual buffer per projectile")
	check(scene.particles.any(func(p):return p.has("smoke")),"launch smoke present")
	check(scene.weapon_visual_tier(scene.game.projectiles[0])==1 and scene.weapon_visual_tier(scene.game.projectiles[2])==0,"heavy projectile and ordinary laser use distinct presentation tiers")
	check(scene.turret_visuals.has(0) and is_equal_approx(float(scene.turret_visuals[0].fired_at),scene.fx_time),"missile pod records a short launch pulse")
	var snapshot: Array = scene.game.projectiles.duplicate(true)
	scene.advance_projectile_visuals(0.03)
	check(scene.game.projectiles==snapshot,"visual update cannot change projectile logic")
	scene._process(0)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/weapons-launch.png")
	var background_draws := [0]
	scene.background_layer.draw.connect(func():background_draws[0]+=1)
	var tabs = scene.equipment_tabs
	var missile: Dictionary = scene.game.projectiles[0]
	var visual: Dictionary = scene.projectile_visuals[0]
	var old_angle: float = visual.angle
	missile.direction = Vector2.DOWN
	scene.advance_projectile_visuals(0.016)
	check(visual.angle!=old_angle and absf(angle_difference(visual.angle,PI/2))>0.01,"missile display rotates smoothly")
	check(missile.direction==Vector2.DOWN,"display smoothing preserves actual direction")
	for i in 8:
		scene.game.tick_projectiles(0.025)
		scene.advance_projectile_visuals(0.025)
	check(visual.trail.size()==14 and visual.samples<=14,"trail storage stays fixed")
	scene.battle_layer.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/weapons-flight.png")
	for shot in scene.game.projectiles:
		shot.x = shot.target.x
		shot.y = shot.target.y
	scene.game.tick_projectiles(0.01)
	check(scene.game.projectiles.is_empty(),"visual hooks preserve impact removal")
	check(not scene.particles.any(func(p):return p.has("ring")),"ordinary non-area hits never show area rings")
	scene.advance_projectile_visuals(0.01)
	scene._process(0.06)
	check(scene.projectile_visuals.is_empty(),"finished visual references released")
	scene.battle_layer.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/weapons-impact.png")
	check(background_draws[0]==0 and scene.equipment_tabs==tabs,"effects preserve static layer and UI instances")
	scene.game.paused = true
	var particle_snapshot: Array = scene.particles.duplicate(true)
	scene._process(0.1)
	check(scene.particles==particle_snapshot,"pause freezes effect state")
	for i in 100:scene.weapon_impact({"key":"missile","damage":1e30},Vector2(700,400))
	check(scene.particles.size()<=scene.WEAPON_PARTICLE_LIMIT,"weapon effects have bounded particle count")
	check(scene.weapon_strength({"damage":1e30})<=1.5,"large damage cannot obscure battlefield with unbounded effects")
	scene.particles.clear()
	scene.game.paused = false
	scene.game.enemies.resize(1)
	scene.game.profile.loadout.weapons = [{"key":"missile","level":1},{"key":"","level":1},{"key":"","level":1}]
	scene.db.equipment.missile[0].para1 = 3
	scene.game.cooldowns.weapons_0 = 0
	scene.game.tick(0.0)
	check(scene.game.projectiles.size()==3 and scene.projectile_visuals.size()==3,"single target still receives three actual missiles")
	var first: Dictionary = scene.projectile_visuals[0]
	var middle: Dictionary = scene.projectile_visuals[1]
	var last: Dictionary = scene.projectile_visuals[2]
	var first_pos: Vector2 = scene.missile_visual_position(first.shot,first.spread,first.origin)
	var middle_pos: Vector2 = scene.missile_visual_position(middle.shot,middle.spread,middle.origin)
	var last_pos: Vector2 = scene.missile_visual_position(last.shot,last.spread,last.origin)
	check(first_pos==middle_pos and middle_pos==last_pos,"all visual missiles start at the same muzzle")
	var logical_muzzle: Vector2 = Vector2(scene.game.player.x,scene.game.player.y)+scene.game.player_weapon_offset(0)
	var muzzle: Vector2 = scene.visual_muzzle(first.shot)
	check(first_pos==muzzle and first.origin==muzzle and last.origin==muzzle,"launch flashes and trails use the real muzzle")
	check(first.shot.x==last.shot.x and first.shot.y==last.shot.y,"actual volley spawn points are identical")
	scene.game.tick_projectiles(0.15)
	first_pos = scene.missile_visual_position(first.shot,first.spread,first.origin)
	last_pos = scene.missile_visual_position(last.shot,last.spread,last.origin)
	check(last_pos.x-first_pos.x>20,"visual lanes unfold only after leaving muzzle")
	var real_y: float = first.shot.y
	scene.advance_projectile_visuals(0.1)
	check(first.shot.y==real_y,"lane animation never moves real missile")
	scene.battle_layer.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/missile-volley.png")
	scene.db.config.equipmentSocket = 10
	check(scene.db.jewel_effect("4")=="repeat","repeat fixture uses the current repeat gem")
	scene.db.data.jewel["4"].para_2 = 1.0
	scene.game.slot_entry("weapons",0).sockets = [scene.game.new_jewel("4",1)]
	scene.game.player.x += 17.0
	muzzle.x += 17.0
	scene.game.queue_jewel_repeats(0,1.0)
	check(scene.game.jewel_repeats.size()==1,"repeat gem queues one additional volley")
	scene.game.advance_jewel_repeats(0.5)
	check(scene.projectile_visuals.size()==6 and scene.projectile_visuals[3].spread==-24 and scene.projectile_visuals[5].spread==24,"repeat volley shares visual spread")
	if scene.projectile_visuals.size()<6:
		quit(1)
		return
	check(scene.projectile_visuals[3].origin==muzzle and scene.projectile_visuals[5].origin==muzzle,"repeat volley also spawns at the one true muzzle")
	for count in [1,2,3,5]:
		scene.game.projectiles.clear()
		for i in count:
			scene.game.jewel_fire(0,scene.game.enemies[0],scene.db.equip("missile",1),Vector2(900,900),1.0,scene.game.missile_visual_spread(i,count))
		check(scene.game.projectiles.size()==count and scene.game.projectiles.all(func(p):return Vector2(p.x,p.y)==logical_muzzle+Vector2(17,0)),"shared emitter overrides caller offsets for volley count="+str(count))
		check(scene.game.projectiles.all(func(p):return p.direction==Vector2.UP),"initial direction follows fixed forward mount count="+str(count))
	scene.floats.clear()
	scene.fx_time = 10.0
	var hit := {"player":false,"uid":999,"type":1,"x":800,"y":360,"amount":10}
	scene.on_event("hit",hit)
	scene.fx_time += 0.1
	scene.on_event("hit",hit)
	check(scene.floats.size()==1 and scene.floats[0].amount==20,"same type merges inside 200ms")
	scene.fx_time += 0.11
	scene.on_event("hit",hit)
	check(scene.floats.size()==2,"damage starts new label after window")
	hit.type = 2
	scene.on_event("hit",hit)
	check(scene.floats.size()==2,"simplified merges ordinary damage types")
	for i in 6:
		scene.fx_time += 0.13
		scene.on_event("hit",hit)
	check(scene.floats.size()==2 and scene.floats[0].life<=0.08,"two labels maximum with oldest accelerated fade")
	scene.particles.clear()
	scene.weapon_impact({"key":"cannon","damage":10,"direction":Vector2.RIGHT},Vector2(700,350))
	check(scene.particles.all(func(p):return not p.has("ring")),"cannon impact has no area indicator")
	check(scene.particles.filter(func(p):return p.has("spark")).size()<=3,"ordinary impact uses at most three sparks")
	check(scene.particles.filter(func(p):return p.has("flash")).all(func(p):return p.duration>=0.04 and p.duration<=0.08),"contact flashes last 40 to 80ms")
	check(scene.particles.filter(func(p):return p.has("spark")).all(func(p):return p.vel.x>0),"sparks follow impact direction")
	scene.weapon_impact({"key":"cannon","damage":10,"critical":true},Vector2(700,350))
	check(scene.particles.any(func(p):return p.has("ring") and p.size<=11),"critical has a small short shock ring")
	scene.show_damage_numbers = false
	scene.battle_layer.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/no-damage-numbers.png")
	scene.particles.clear()
	scene.on_event("explode",{"x":800,"y":360,"boss":false})
	check(scene.particles.any(func(p):return p.has("spark") and p.life>=0.4 and p.life<=0.7),"kill has independent lingering debris")
	check(scene.particles.any(func(p):return p.has("destroy") and p.duration>=0.3 and p.duration<=0.6),"kill has staged core effect distinct from hit")
	scene.game.enemies[0].hp = 0
	scene.battle_layer.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/kill-no-numbers.png")
	scene.particles.clear()
	var enemy_snapshot: Dictionary = scene.game.enemies[0].duplicate(true)
	scene.on_event("explode",scene.game.enemies[0])
	check(scene.game.enemies[0]==enemy_snapshot,"hull breakup does not mutate enemy data")
	check(scene.particles.filter(func(p):return p.has("fragment")).size()==6,"kill splits real hull into six pieces")
	check(scene.particles.any(func(p):return p.has("destroy") and p.has("texture") and p.has("extent")),"kill retains a short hull highlight snapshot")
	check(scene.particles.filter(func(p):return p.has("smoke")).all(func(p):return p.duration<=0.24),"kill smoke clears before debris")
	scene.game.paused=true
	scene.battle_layer.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/destroy-hull.png")
	for p in scene.particles:p.life-=0.3
	scene.particles=scene.particles.filter(func(p):return p.life>0)
	scene.battle_layer.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/destroy-core.png")
	scene.game.paused=false
	scene.particles.clear()
	scene.weapon_impact({"key":"missile","damage":10,"direction":Vector2.RIGHT},Vector2(700,350))
	check(scene.particles.any(func(p):return p.has("flash") and p.size>=10),"missile contact has a clearly visible bright core")
	check(scene.particles.filter(func(p):return p.has("smoke")).all(func(p):return p.duration<=0.18),"missile blast smoke stays short")
	var saved_group: int=scene.game.group_index
	scene.game.group_index=scene.db.levels[0].groups.size()
	check(scene.weapon_visual_tier({"key":"laser","hostile":true})==2,"boss attack has highest visual tier")
	scene.game.group_index=saved_group
	scene.game.profile.loadout=scene.game.empty_loadout(scene.game.profile.selectedShip)
	scene.game.projectiles.clear()
	scene.projectile_visuals.clear()
	scene.game.enemies[0].hp=1e9
	scene.game.enemies[0].equipment=[]
	scene.particles.clear()
	var node_count: int=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	for frame in 240:
		if frame%2==0:scene.weapon_impact({"key":["laser","cannon","missile"][frame%3],"damage":10,"direction":Vector2.UP},Vector2(286,350))
		scene._process(1.0/60.0)
	check(scene.particles.size()<=scene.WEAPON_PARTICLE_LIMIT,"dense visual impacts remain capped")
	for frame in 90:scene._process(1.0/60.0)
	check(scene.particles.is_empty() and scene.projectile_visuals.is_empty(),"dense effects recycle after combat quiets")
	check(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))==node_count,"dense effects create no persistent nodes")
	scene.game.projectiles.clear()
	scene.projectile_visuals.clear()
	scene.particles.clear()
	scene.game.speed=3.0
	scene.sync_accelerated_visual_mode()
	var accelerated_shot_count: int = scene.game.projectiles.size()
	scene.game.fire(scene.game.player,scene.game.enemies[0],scene.db.equip("laser",1),10,false,"laser",scene.game.player_weapon_offset(0))
	check(scene.accelerated_visual_mode and scene.game.projectiles.size()==accelerated_shot_count+1,"3x keeps logical projectile simulation enabled")
	check(scene.projectile_visuals.is_empty() and scene.particles.is_empty(),"3x creates no projectile or combat effects")
	scene.on_event("hit",hit)
	scene.on_event("explode",scene.game.enemies[0])
	check(scene.floats.all(func(entry):return not entry.get("damage",false)) and scene.particles.is_empty(),"3x hides hit labels and destruction effects")
	scene.game.speed=2.99
	scene.sync_accelerated_visual_mode()
	check(not scene.accelerated_visual_mode,"combat effects return below 3x")
	scene.queue_free()
	await process_frame
	print("Weapon FX: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
