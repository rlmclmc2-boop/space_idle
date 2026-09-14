extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var g: BattleGame = scene.game
	g.save_enabled = false
	g.start(1,false)
	g.group_index = g.db.levels[0].groups.size()-1
	g.spawn_group()
	var boss: Dictionary = g.enemies[0]
	g.enemies.assign([boss])
	boss.boss = true
	boss.size = 3
	boss.hp = 1
	boss.x = 1130.0
	boss.y = 410.0
	boss.equipment = []
	g.profile.unlocked = []
	g.player.shield = 0
	g.player.armour = 1
	g.projectiles.clear()
	var weapon := g.db.equip("laser",1)
	g.fire(g.player,boss,weapon,1000000,false,"laser")
	var killing_shot: Dictionary = g.projectiles.back()
	for key in ["laser","cannon","missile"]:
		g.fire(boss,g.player,g.db.equip(key,1),1000000,true,key+"_mon")
		g.fire(g.player,boss,g.db.equip(key,1),1,false,key)
	scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://boss-before.png")
	killing_shot.x = boss.x
	killing_shot.y = boss.y
	for shot in g.projectiles:
		if shot.hostile:
			shot.x = g.player.x
			shot.y = g.player.y
	g.tick(0.001)
	check(boss.hp == 0,"Boss killed by projectile")
	check(g.projectiles.is_empty(),"All friendly and hostile projectiles cleared")
	check(g.player.armour == 1,"Same-frame lethal hostile shots never resolve after boss death")
	check(g.state == BattleGame.State.LEVEL_CLEAR and g.profile.cleared.has(1),"Clear recorded without retreat")
	var drop_count := g.drops.size()
	g.hit_enemy(boss,1000000,1)
	check(g.drops.size() == drop_count,"Dead boss cannot drop twice")
	scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://boss-after.png")
	g.acknowledge_unlocks()
	g.tick(float(g.db.defaults.loopDelay)+0.1)
	check(g.stage == 2 and g.state == BattleGame.State.TRAVEL,"Next stage starts normally")
	g.spawn_group()
	var normal: Dictionary = g.enemies[0]
	normal.boss = false
	g.fire(normal,g.player,weapon,1,true,"laser_mon")
	g.hit_enemy(normal,1000000000,1)
	check(not g.projectiles.is_empty(),"Ordinary enemy death preserves projectiles")
	g.group_index = g.db.levels[g.stage-1].groups.size()-1
	g.spawn_group()
	for enemy in g.enemies:
		g.hit_enemy(enemy,1000000000,1)
	check(g.projectiles.is_empty(),"Direct final-group damage also clears immediately")
	print("Boss projectile clear: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
