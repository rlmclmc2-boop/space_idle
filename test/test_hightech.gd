extends SceneTree

var checks := 0
var failures := 0
const F := BattleGame.FURNACE
const E := BattleGame.ENERGY_FOCUS
const A := BattleGame.DENSE_ARMOUR

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(label)

func _initialize() -> void:
	call_deferred("run")

func write_save(profile: Dictionary) -> void:
	var file := FileAccess.open(BattleGame.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(profile))
	file.close()

func run() -> void:
	var db := ShipDatabase.new()
	db.data.hightech[F].para2 = 0.5 # Fixed mechanism fixture, independent of balance edits.
	var g := BattleGame.new(db, false)
	check(db.data.hightech.size() == 3, "Three workbook technologies loaded")
	check(not g.research(F) and g.hightech_level(F) == 0, "Locked and initially level zero")
	g.profile.cleared = [5,8]
	check(g.hightech_unlocked(F) and g.hightech_unlocked(E), "Workbook clear gates")
	check(g.hightech_duration(F) == 60, "First level time from source")
	check(g.research(F), "Research starts without resource cost")
	check(not g.research(F) and g.research(E) and not g.profile.hightechResearch[F].active and g.research(F), "Same tech ignored; switching preserves previous job")
	g.paused = true
	g.tick(30)
	check(g.profile.hightechResearch[F].remaining == 60, "Pause freezes research")
	g.paused = false
	g.speed = 5
	g.tick(5)
	check(g.profile.hightechResearch[F].remaining == 55, "Scaled simulation delta advances research")
	g.advance_hightech(54)
	check(g.hightech_level(F) == 0, "No effect before completion")
	g.advance_hightech(1)
	check(g.hightech_level(F) == 1 and g.profile.hightechResearch[F].remaining==72 and g.active_research()==[F], "Completion automatically starts next level")
	check(g.hightech_duration(F) == 72, "Second level linear duration")
	g.profile.hightechLevels[F] = 2
	check(g.hightech_duration(F) == 84, "Third level linear rather than compound duration")
	g.profile.hightechLevels[F] = 1000
	g.profile.hightechResearch.clear()
	check(g.research(F), "No equipment level cap applied to research")
	g.profile.hightechResearch.clear()
	db.config.hightechLimit = 2
	check(g.research(E) and g.research(A) and not g.research(F), "Concurrency reads config instead of hardcoded one")
	g.player.armour = 17
	g.player.shield = 7
	var base_armour := float(db.equip("armour",1).para1)
	var base_laser := float(db.equip("laser",1).dmg)
	var base_cannon := float(db.equip("cannon",1).dmg)
	g.advance_hightech(60)
	check(g.stat("armour") == ceilf(base_armour*1.08) and g.player.armour == 17, "Armour maximum multiplied and rounded, current unchanged")
	check(g.stat("laser") == ceilf(base_laser*1.1), "Energy weapon damage multiplied and rounded")
	check(g.stat("cannon") == ceilf(base_cannon*1.1), "Physical weapon also enhanced")
	db.equipment.cannon[0].dmgtype = 1
	check(g.stat("cannon") == ceilf(base_cannon*1.1), "All weapon types share the enhancement")
	db.equipment.cannon[0].dmgtype = 2
	check(g.stat("shield")==ceilf(float(db.equip("shield",1).para1)*1.08) and g.player.shield==7, "Shield maximum grows without refilling current shield")
	g.profile.hightechLevels[E]=3
	g.profile.hightechLevels[A]=3
	for key in ["laser","cannon","missile"]:
		check(g.stat(key)==ceilf(float(db.equip(key,1).dmg)*pow(1.1,3)), "All player weapons compound at level three: "+key)
	for key in ["armour","shield"]:
		check(g.stat(key)==ceilf(float(db.equip(key,1).para1)*pow(1.08,3)), "Both defensive maxima compound: "+key)
	g.reset_player()
	check(g.player.armour == g.stat("armour"), "Existing recovery uses enhanced maximum")
	g = BattleGame.new(db, false)
	g.profile.hightechLevels[F] = 1
	var now := Time.get_unix_time_from_system()
	g.resource_samples.assign([{"time":now-60,"id":"1","amount":1000.0},{"time":now-59,"id":"1","amount":31.0},{"time":now-1,"id":"2","amount":999.0}])
	g.advance_hightech(30,30,now)
	check(g.drops.size()==1 and g.drops[0].amount==16, "Furnace uses last minute actual iron, excludes boundary and other resource, rounds up")
	var block: Dictionary = g.drops[0]
	g.collect_near(Vector2(block.x,block.y))
	g.settle_drops()
	check(g.drops.has(block) and g.profile.resources["1"]==0, "Furnace cannot be hovered or auto-settled")
	g.collect_near(Vector2(block.x,block.y),true)
	check(not g.drops.has(block) and g.profile.resources["1"]==16, "Click credits full furnace amount")
	check(g.resource_minute_total("1", now+0.1)==47, "Furnace pickup uses the same income sample stream")
	g.advance_hightech(30,30,now+30)
	check(g.drops.size()==1 and g.drops[0].amount==16, "Next block retains peak after normal samples expire")
	g.advance_hightech(10,10,now+40)
	check(g.drops.is_empty() and g.profile.resources["1"]==16, "Block expires at ten seconds without credit")
	g.paused = true
	var elapsed := float(g.profile.furnaceElapsed)
	g.tick(5)
	check(g.profile.furnaceElapsed==elapsed, "Pause freezes furnace")
	g.paused = false
	g.advance_hightech(3600,3600,now+3640)
	check(g.drops.size()<=1, "Long offline gap skips expired generations")
	# Actual save/load in this test runner's isolated user directory.
	var profile := g.fresh_profile()
	profile.cleared = [5,8]
	profile.hightechSavedAt = Time.get_unix_time_from_system()-35
	profile.hightechLevels = {F:1}
	profile.hightechResearch = {E:{"remaining":60.0,"duration":60.0}}
	profile.resourceSamples = [{"time":profile.hightechSavedAt-1,"id":"1","amount":40.0,"origin":"drop"}]
	write_save(profile)
	var resumed := BattleGame.new(db)
	check(absf(float(resumed.profile.hightechResearch[E].remaining)-25)<1, "Offline research resumes at real one-times speed")
	check(resumed.drops.size()==1 and resumed.drops[0].amount==20 and absf(float(resumed.drops[0].age)-5)<1, "Offline preserves only unexpired block and source income")
	resumed.save_progress()
	var again := BattleGame.new(db)
	check(absf(float(again.profile.hightechResearch[E].remaining)-float(resumed.profile.hightechResearch[E].remaining))<1, "Reload does not count prior offline gap twice")
	db.config.offlineMax = 0.01
	profile.hightechSavedAt = Time.get_unix_time_from_system()-1000
	profile.hightechLevels = {}
	profile.hightechResearch = {E:{"remaining":60.0,"duration":60.0}}
	write_save(profile)
	resumed = BattleGame.new(db)
	check(is_equal_approx(float(resumed.profile.hightechResearch[E].remaining),24), "Offline cap comes from config hours")
	db.config.offlineMax = 0
	write_save(profile)
	resumed = BattleGame.new(db)
	check(resumed.profile.hightechResearch[E].remaining==60, "Zero offline cap disables progression")
	db.config.offlineMax = 4
	profile.hightechResearch[E] = {"remaining":20000.0,"duration":20000.0}
	profile.hightechSavedAt = Time.get_unix_time_from_system()-86400
	write_save(profile)
	resumed = BattleGame.new(db)
	check(resumed.profile.hightechResearch[E].remaining==5600, "Four-hour cap applies to longer absence")
	write_save({"version":1,"resources":{"1":123,"2":7},"levels":{"laser":2},"cleared":[5]})
	resumed = BattleGame.new(db)
	check(resumed.hightech_level(F)==0 and resumed.profile.hightechResearch.is_empty() and resumed.profile.resources["1"]==123 and resumed.profile.levels.laser==2, "Old save keeps resources/equipment and starts tech at zero")
	# Real UI, input button and screenshot.
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.game.save_enabled = false
	scene.game.profile.cleared = [5,8]
	scene.game.pending_unlocks.clear()
	scene.build_ui()
	scene.equipment_tabs.current_tab = 2
	check(scene.equipment_tabs.get_tab_title(2)=="高科技" and scene.hightech_buttons.size()==3, "Hightech tab shows all three cards")
	scene.hightech_buttons[E].pressed.emit()
	await process_frame
	check(scene.game.profile.hightechResearch.has(E) and scene.equipment_tabs.current_tab==2, "Real research button and rebuild keep selected page")
	check(not scene.hightech_buttons[A].disabled, "Other technology offers research switching")
	var card: Control = scene.hightech_buttons[A].get_parent()
	var description: Label = card.get_child(1)
	check(description.text=="生命增加100%" and not description.text.contains("armour"), "Description comes from description instead of des")
	scene.game.profile.hightechLevels[F] = 1
	scene.game.resource_samples.assign([{"time":Time.get_unix_time_from_system(),"id":"1","amount":120.0}])
	scene.game.advance_hightech(30)
	scene.game.drops[0].x = 650
	scene.game.drops[0].y = 400
	scene.build_ui()
	scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://hightech.png")
	var furnace_card: Control = scene.hightech_buttons[F].get_parent()
	var furnace_description: Label = furnace_card.get_child(1)
	check(furnace_description.size.x<=423 and furnace_description.get_rect().end.y<=79, "Furnace description wraps within its card above button")
	check(scene.equipment_tabs.get_rect().end.y<=778, "Cards fit above footer")
	print("Hightech: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
