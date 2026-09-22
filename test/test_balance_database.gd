extends SceneTree
const RunDatabase = preload("res://scripts/balance_database.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var original := ShipDatabase.new()
	var cached := RunDatabase.new()
	for key in original.equipment:
		for level in [-1,1,2,40,200,1000]:
			check(original.equip(key,level) == cached.equip(key,level),"real equipment projection %s/%d" % [key,level])
		check(original.enemy_weapon(key) == cached.enemy_weapon(key),"enemy fallback projection "+key)
	for id in original.data.jewel:
		check(original.jewel_effect(id) == cached.jewel_effect(id),"effect definition "+id)
	for unlock in original.data.unlock.values():
		check(cached.unlock_id(unlock.type,unlock.target) == original.unlock_id(unlock.type,unlock.target),"fixed config unlock lookup")
	for index in 600:cached.unlock_id("missing",str(index))
	check(cached.unlock_ids.size() <= cached.ROW_LIMIT,"unlock lookup is bounded even for missing IDs")
	var first_id: String = str(cached.data.unlock.keys()[0])
	var first: Dictionary = cached.data.unlock[first_id]
	cached.unlock_id(first.type,first.target)
	cached.data.unlock.erase(first_id)
	cached.clear_derived_cache()
	check(cached.unlock_id(first.type,first.target).is_empty(),"unlock source edits invalidate lookup")
	var row := cached.equip("laser",40)
	row.dmg = -123
	check(cached.equip("laser",40) == original.equip("laser",40),"returned equipment row has independent ownership")
	row = cached.enemy_weapon("laser-mon")
	row.cd = -123
	check(cached.enemy_weapon("laser-mon") == original.enemy_weapon("laser-mon"),"returned enemy row has independent ownership")
	for level in 600:cached.equip("laser",level+1)
	check(cached.equipment_rows.size() <= cached.ROW_LIMIT,"equipment cache stays bounded")
	for database in [original,cached]:
		for source in database.equipment.laser:
			if int(source.level) == 1:source.dmg *= 2
	cached.clear_derived_cache()
	check(cached.equip("laser",40) == original.equip("laser",40),"explicit source edit invalidation")
	check(cached.enemy_weapon("laser-mon") == original.enemy_weapon("laser-mon"),"fallback invalidation after source edit")
	var timings := []
	for database in [original,cached]:
		var started := Time.get_ticks_usec()
		for index in 10000:database.equip("shield",40+index%3)
		timings.append(Time.get_ticks_usec()-started)
	print("ROW_PROJECTION_USEC=",timings)
	print("Balance Database: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
