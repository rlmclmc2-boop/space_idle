extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:failures += 1;printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	scene.automation_args=["--capture"]
	root.add_child(scene)
	scene.automation_args=[]
	scene.set_process(false)
	scene.game.save_enabled=false
	var page = scene.enemy_intel_page
	check(page.route_stage == -1,"Hidden enemy page does not prepare route data")
	check(page.route_builds == 0 and page.detail_builds == 0,"Hidden page has no route or detail work")
	var rng_before = scene.game.rng.state
	var profile_before = scene.game.profile.duplicate(true)
	scene.select_system(11)
	check(page.route_stage == 1 and not page.entries.is_empty(),"Opening tab lists actual stage-one route")
	check(page.route_builds == 1 and page.detail_builds == 1,"First opening builds route and detail once")
	scene.select_system(0)
	scene.select_system(11)
	page.show_entry(0)
	check(page.route_builds == 1 and page.detail_builds == 1,"Reopening and same selection reuse current page")
	check(scene.game.rng.state == rng_before and scene.game.profile == profile_before,"Enemy page leaves game state and RNG unchanged")
	var first: Dictionary = page.entries[0]
	var source: Dictionary = scene.db.enemies[first.id]
	var title := str(source.des)
	check(page.heading.text == title,"Stable enemy ID resolves the source name")
	source.intelTrait="表格字段定点替换"
	page.show_entry(-1)
	page.show_entry(0)
	check(page.detail.get_children().any(func(node):return node is Label and node.text=="表格字段定点替换"),"Changing only table data changes displayed trait")
	scene.select_system(0)
	scene.game.stage=3
	page.refresh_if_needed()
	check(page.route_stage==1,"Hidden tab does not recompute after stage change")
	check(page.route_builds == 1,"Hidden stage switch does no route work")
	scene.select_system(11)
	check(page.route_stage==3 and page.entries.any(func(entry):return str(entry.id)=="271024"),"Reopening lists stage-three reactive enemy")
	check(page.route_builds == 2,"Stage switch rebuilds the route once")
	var reactive_index = page.entries.find_custom(func(entry):return str(entry.id)=="271024")
	page.show_entry(reactive_index)
	check(page.detail.get_children().any(func(node):return node is Label and node.text==UIText.t("enemy.intel.reactive")),"Reactive text follows referenced combat field")
	var entry: Dictionary=page.entries[reactive_index]
	var row: Dictionary=scene.db.enemies[entry.id]
	var expected := ceilf(float(row.health)*scene.db.ratio(3,int(entry.point),"lifeRatio"))
	check(scene.db.enemy_encounter_capacity(row,3,int(entry.point),"health")==expected,"Displayed capacity uses battle-point interpolation and ceiling")
	page.show_entry(page.entries.find_custom(func(item):return str(item.id)=="271028"))
	check(page.detail.get_children().any(func(node):return node is Label and node.text.contains("1.8")),"Shield recovery details bind actual delay")
	print("Enemy intel: %d checks, %d failures" % [checks,failures])
	scene.queue_free()
	quit(1 if failures else 0)
