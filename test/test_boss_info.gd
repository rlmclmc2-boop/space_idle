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
	var db := ShipDatabase.new()
	var g := BattleGame.new(db,false)
	g.start(1,false)
	check(g.boss_info()=="？？？", "Unseen boss stays unknown")
	g.spawn_group()
	check(g.boss_info()=="？？？", "Ordinary wave does not reveal boss")
	g.group_index = db.levels[0].groups.size()-1
	g.spawn_group()
	check(g.boss_info()==str(g.enemies[0].des), "Encounter reveals configured boss description")
	g.begin_retreat()
	check(g.boss_info()!="？？？", "Death retains discovery")
	g.start(1,false)
	check(g.boss_info()!="？？？", "Replay retains discovery")
	g.save_enabled = true
	g.save_progress()
	var restored := BattleGame.new(db,true)
	check(restored.boss_info()==g.boss_info(), "Discovery survives save and load before clear")
	g.profile.highestLevel = 2
	g.start(2,false)
	check(g.boss_info()=="？？？", "Discovery is stage specific")
	var legacy := g.fresh_profile()
	legacy.cleared = [1]
	legacy.erase("bossSeen")
	var file := FileAccess.open(BattleGame.SAVE_PATH,FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	var migrated := BattleGame.new(db,true)
	check(migrated.boss_info()!="？？？", "Legacy cleared stage implies discovered boss")
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.game.save_enabled = false
	scene.game.start(1,false)
	await process_frame
	scene.queue_redraw()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://boss-known.png")
	scene.game.start(2,false)
	scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://boss-unknown.png")
	print("BOSS info: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
