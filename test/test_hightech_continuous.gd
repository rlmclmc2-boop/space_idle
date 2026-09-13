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

func run() -> void:
	var db := ShipDatabase.new()
	db.data.hightech[F].para2 = 0.5 # Fixed mechanism fixture, independent of balance edits.
	var g := BattleGame.new(db,false)
	g.profile.cleared = [5,8]
	g.research(E)
	g.advance_hightech(20)
	g.research(A)
	g.advance_hightech(10)
	check(g.profile.hightechResearch[E].remaining==40 and g.profile.hightechResearch[A].remaining==50, "Switch freezes previous remaining time")
	g.research(E)
	g.advance_hightech(45)
	check(g.hightech_level(E)==1 and g.profile.hightechResearch[E].remaining==67 and g.profile.hightechResearch[A].remaining==50, "Resumed progress completes and excess time reaches next level only on selected tech")
	g.advance_hightech(151)
	check(g.hightech_level(E)==3 and g.profile.hightechResearch[E].remaining==96, "Single update completes multiple linear-duration levels and continues")
	g.paused = true
	g.tick(5)
	check(g.profile.hightechResearch[E].remaining==96, "Pause freezes continuous research")
	g.paused = false
	var now := Time.get_unix_time_from_system()
	g.profile.hightechLevels[F]=2
	g.resource_samples.assign([{"time":now-1,"id":"1","amount":123.0}])
	check(g.hightech_description(F,now)=="每30秒在屏幕中生成一个含有123的铁块", "Parameter and live minute-income rounded expression substituted")
	check(g.hightech_description(E)=="能量武器伤害提高0.3", "Current level expression has no floating point tail")
	g.profile.hightechLevels[A]=3
	check(g.hightech_description(A)=="生命增加0.24", "Fractional parameter precision retained")
	check(g.hightech_description(F,now+61)=="每30秒在屏幕中生成一个含有0的铁块", "Description reflects expired minute samples")
	db.data.hightech[F].description="para1 / para2 / {para1*(等级+1),向上取整}"
	check(g.hightech_description(F)=="30 / 0.5 / 90", "Repeated tokens and parenthesized arithmetic")
	db.data.hightech[F].description="{1/2}"
	check(g.hightech_description(F)=="0.5", "Arithmetic division retains fractions")
	db.data.hightech[F].description="{load(1)} {1/0}"
	check(g.hightech_description(F)=="？ ？", "Invalid expression never executes arbitrary calls or displays misleading zero")
	# Save an active and a suspended job, then simulate an offline interval.
	g.profile.hightechLevels[E]=0
	g.profile.hightechResearch={E:{"remaining":60.0,"duration":60.0,"active":true},A:{"remaining":35.0,"duration":60.0,"active":false}}
	g.save_enabled=true
	g.save_progress()
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BattleGame.SAVE_PATH))
	raw.hightechSavedAt=Time.get_unix_time_from_system()-200
	var file := FileAccess.open(BattleGame.SAVE_PATH,FileAccess.WRITE)
	file.store_string(JSON.stringify(raw))
	file.close()
	var loaded := BattleGame.new(ShipDatabase.new())
	check(loaded.hightech_level(E)==2 and absf(float(loaded.profile.hightechResearch[E].remaining)-16)<1, "Offline auto research crosses multiple levels")
	check(loaded.profile.hightechResearch[A].remaining==35 and not loaded.profile.hightechResearch[A].active, "Offline leaves suspended progress untouched")
	loaded.save_enabled=false
	loaded.research(A)
	check(loaded.active_research()==[A] and loaded.profile.hightechResearch[A].remaining==35, "Reloaded suspended job can resume")
	loaded.db.config.hightechLimit=2
	loaded.research(E)
	check(not loaded.research(F), "Multiple active slots require explicit replacement choice")
	check(loaded.research(F,E) and loaded.active_research().has(A) and loaded.active_research().has(F) and not loaded.profile.hightechResearch[E].active, "Explicit replacement preserves other active slot")
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.game.save_enabled=false
	scene.game.profile.cleared=[5,8]
	scene.game.profile.hightechResearch.clear()
	scene.game.profile.hightechLevels={F:2,E:3,A:3}
	scene.game.resource_samples.assign([{"time":Time.get_unix_time_from_system(),"id":"1","amount":123.0}])
	scene.build_ui()
	scene.equipment_tabs.current_tab=2
	scene.hightech_buttons[E].pressed.emit()
	await process_frame
	scene.game.advance_hightech(12)
	scene.hightech_buttons[A].pressed.emit()
	await process_frame
	check(scene.game.active_research()==[A] and scene.hightech_buttons[E].text.contains("继续研发"), "UI switches and labels retained progress")
	scene.game.resource_samples.clear()
	scene._process(0)
	check(scene.hightech_descriptions[F].text.contains("含有0的铁块"), "UI description refreshes without rebuilding cards")
	scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://hightech-continuous.png")
	print("Continuous hightech: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
