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
	var reusable_detail_nodes: int = page.detail.get_child_count()
	var equipment = scene.equipment_panel
	var builds: int = scene.game.compiled_combat_rules.builds if scene.game.compiled_combat_rules else 0
	var projections: int = equipment.projection_builds
	var refreshes: int = equipment.refresh_passes
	var rng_before = scene.game.rng.state
	var profile_before = scene.game.profile.duplicate(true)
	var paused_before = scene.game.paused
	check(page.route_stage==-1 and page.route_builds==0 and page.detail_builds==0,"Hidden tab performs no route or detail work")
	scene.select_system(11)
	check(scene.equipment_tabs.current_tab==11 and page.route_builds==1 and page.detail_builds==1,"Actual tab event opens route and first detail once")
	check(equipment.projection_builds==projections and equipment.refresh_passes==refreshes,"Enemy tab leaves equipment projections and refresh untouched")
	check((scene.game.compiled_combat_rules.builds if scene.game.compiled_combat_rules else 0)==builds,"Enemy tab does not recompile battle rules")
	check(scene.game.rng.state==rng_before and scene.game.profile==profile_before and scene.game.paused==paused_before,"Opening leaves RNG, profile and pause unchanged")
	var first: Dictionary=page.entries[0]
	var row: Dictionary=scene.db.enemies[first.id]
	check(page.heading.text==str(row.intelName) and not page.heading.text.contains("开场资源变体"),"Displayed name comes from authored player field")
	check(str(row.intelVisualRef)==str(row.archetype_id) and page.detail.get_children().any(func(node):return node is TextureRect and node.texture==scene.ship_hull_texture(scene.enemy_visual_identity.resolve(row,scene.visual_config))),"Image follows authored combat archetype through the battle resolver")
	page.list.item_selected.emit(1)
	check(page.selected==1 and page.detail_builds==2,"Different enemy selection builds one detail")
	page.list.item_selected.emit(1)
	check(page.detail_builds==2,"Same enemy selection does no work")
	check(equipment.projection_builds==projections and (scene.game.compiled_combat_rules.builds if scene.game.compiled_combat_rules else 0)==builds,"Selections leave equipment and combat compilation untouched")
	scene.select_system(0)
	var hidden_builds: int = page.route_builds
	scene.select_system(11)
	check(page.route_builds==hidden_builds,"Real close and reopen reuse route")
	scene.select_system(0)
	scene.game.profile.highestLevel=3
	scene.game.start(3,false)
	scene.game.paused=false
	var before_tick: float = scene.game.distance
	scene.game.tick(1.0/60.0)
	check(scene.game.distance>before_tick and page.route_builds==hidden_builds,"Combat continues while enemy page is closed")
	scene.game.spawn_group()
	var actual_enemy: Dictionary=scene.game.enemies[0]
	var mounted_id := str(int(scene.db.groups[str(int(scene.db.levels[2].groups[0].id))].slots[int(actual_enemy.slot)]))
	var actual_row: Dictionary=scene.db.enemies[mounted_id]
	check(actual_enemy.max_hp==scene.db.enemy_encounter_capacity(actual_row,3,0,"health") and actual_enemy.max_shield==scene.db.enemy_encounter_capacity(actual_row,3,0,"shield"),"Page capacity equals actual spawned combat actor")
	for slot in scene.game.profile.loadout.defence:
		if str(slot.get("key",""))=="":slot.key="armour"
	scene.game.invalidate_stat_cache()
	var descriptor: Dictionary=preload("res://scripts/native_execution_compiler.gd").new().compile(scene.game,"native_rich15_layer2")
	check(not descriptor.has("error"),"Native descriptor accepts actual spawned encounter: "+str(descriptor.get("error","")))
	if not descriptor.has("error"):
		var hostile: Array=descriptor.weapons.filter(func(weapon):return weapon.hostile and int(weapon.source)==0)
		var enemy_weapon: Dictionary=scene.db.enemy_weapon(str(actual_enemy.equipment[0].name))
		check(not hostile.is_empty() and hostile[0].damage==scene.db.enemy_attack_damage(actual_row,enemy_weapon,3,0),"Page attack equals admitted native hostile output")
	page.refresh_if_needed()
	check(page.route_builds==hidden_builds,"Closed stage change does no enemy-page work")
	builds=scene.game.compiled_combat_rules.builds if scene.game.compiled_combat_rules else 0
	projections=equipment.projection_builds
	scene.select_system(11)
	check(page.route_stage==3 and page.route_builds==hidden_builds+1,"Opening after stage change rebuilds once")
	check(page.list is ItemList and page.detail.get_child_count()==reusable_detail_nodes,"Stage change reuses the route control and detail nodes")
	for pair in [["271022","271023"],["271026","271027"]]:
		var first_entry = page.entries.find_custom(func(entry):return str(entry.id)==pair[0])
		var second_entry = page.entries.find_custom(func(entry):return str(entry.id)==pair[1])
		check(first_entry>=0 and second_entry>=0 and page.list.get_item_text(first_entry)!=page.list.get_item_text(second_entry),"Different same-point enemy IDs retain distinct authored names")
	check(equipment.projection_builds==projections and (scene.game.compiled_combat_rules.builds if scene.game.compiled_combat_rules else 0)==builds,"Cross-stage tab opening avoids unrelated recompilation")
	var reactive_index = page.entries.find_custom(func(entry):return str(entry.id)=="271024")
	page.list.item_selected.emit(reactive_index)
	var reactive := UIText.t("enemy.intel.reactive",{"stacks":str(scene.game.REACTIVE_STACK_LIMIT),"reduction":scene.number(scene.game.REACTIVE_STACK_REDUCTION*100.0),"window":page.duration_text(scene.game.REACTIVE_RESET_SECONDS)})
	check(page.detail.get_children().any(func(node):return node is Label and node.text==reactive),"Reactive detail binds combat parameters")
	check(reactive.contains("2200 毫秒") and not reactive.contains("2.2 秒"),"Reactive reset is shown as exact integer milliseconds")
	check(not reactive.contains("毫秒 秒"),"Reactive sentence has no leftover seconds suffix")
	check(not page.detail.get_children().any(func(node):return node is Label and node.text.contains("271024")),"Player view omits internal ID")
	var reactive_row: Dictionary=scene.db.enemies[page.entries[reactive_index].id]
	reactive_row.intelName="表内测试名称"
	reactive_row.shield=100
	reactive_row.shieldRecovery=0.08
	reactive_row.shieldDelay=1.8
	reactive_row.intelMechanics=["shieldRecovery","reactiveReduction"]
	page.show_entry(-1)
	page.show_entry(reactive_index)
	await process_frame
	var detail_lines: Array=page.detail.get_children().filter(func(node):return node is Label).map(func(node):return node.text)
	check(page.heading.text=="表内测试名称","Authoring field controls player name without slicing internal des")
	var recovery_line := detail_lines.find_custom(func(value):return str(value).begins_with("护盾恢复"))
	check(recovery_line>=0 and detail_lines.find(reactive)>recovery_line,"Both active mechanisms appear in authored order")
	var recovery_index = page.entries.find_custom(func(entry):return str(entry.id)=="271028")
	page.list.item_selected.emit(recovery_index)
	check(page.detail.get_children().any(func(node):return node is Label and node.text.contains("1800 毫秒")),"Recovery detail binds exact authored delay")
	check(page.detail.get_children().any(func(node):return node is Label and node.text.contains("500 毫秒")),"Weapon cooldown uses exact millisecond text")
	check(not page.detail.get_children().any(func(node):return node is Label and node.text.contains("毫秒 秒")),"Recovery and cooldown sentences have no leftover seconds suffix")
	check(page.duration_text(float(scene.db.enemy_weapon("longLaser-mon").cd))=="200 毫秒","Short weapon cooldown keeps exact authored duration")
	var recovery_row: Dictionary=scene.db.enemies[page.entries[recovery_index].id]
	check(page.heading.text==str(recovery_row.intelName),"Different selection updates authored name")
	print("Enemy intel tab chain: %d checks, %d failures; route=%d detail=%d compile=%d projection=%d" % [checks,failures,page.route_builds,page.detail_builds,builds,projections])
	scene.queue_free()
	quit(1 if failures else 0)
