extends SceneTree
## Isolated audit only. Timings include the real save writer and original UI event path.
class TimedGame extends BattleGame:
	var save_us:=0
	var saves:=0
	var max_us:=0
	var max_calls:=0
	var upgrades:=0
	func save_progress() -> void:
		var started:=Time.get_ticks_usec()
		super.save_progress()
		save_us+=Time.get_ticks_usec()-started
		saves+=1
	func max_upgrade_amount_slot(category: String,index: int) -> int:
		var started:=Time.get_ticks_usec()
		var value:=super.max_upgrade_amount_slot(category,index)
		max_us+=Time.get_ticks_usec()-started
		max_calls+=1
		return value
	func upgrade_slot(category: String,index: int,levels:=1) -> bool:
		var result:=super.upgrade_slot(category,index,levels)
		if result:upgrades+=1
		return result
	func clear_times() -> void:
		save_us=0
		saves=0
		max_us=0
		max_calls=0
		upgrades=0
class TimedUI extends "res://scripts/main.gd":
	var upgrade_ui_us:=0
	func on_event(kind: String,info: Dictionary) -> void:
		var started:=Time.get_ticks_usec()
		super.on_event(kind,info)
		if kind in ["upgrade","upgrades_completed"]:upgrade_ui_us+=Time.get_ticks_usec()-started
var scene
var reports: Array=[]
func _initialize() -> void:call_deferred("run")
func stats(values: Array) -> Dictionary:
	var ordered:=values.duplicate()
	ordered.sort()
	return {"median_us":ordered[ordered.size()/2],"p95_us":ordered[mini(ordered.size()-1,int(ceil(ordered.size()*0.95))-1)],"max_us":ordered[-1]}
func run() -> void:
	scene=TimedUI.new()
	scene.automation_args=["--capture"]
	root.add_child(scene)
	scene.set_process(false)
	scene.automation_args=[]
	scene.game.event.disconnect(scene.on_event)
	var g:=TimedGame.new(scene.db,false)
	scene.game=g
	g.event.connect(scene.on_event)
	g.profile.cleared=range(1,61)
	g.rebuild_unlocks()
	g.pending_unlocks.clear()
	g.paused=true
	var ships: Array=scene.db.ships.keys()
	ships.sort_custom(func(a,b):return int(scene.db.ships[a].weaponSlots)+int(scene.db.ships[a].defenseSlots)<int(scene.db.ships[b].weaponSlots)+int(scene.db.ships[b].defenseSlots))
	var tested_ships: Array=[ships[0],ships[-1]]
	for ship in tested_ships:
		g.save_enabled=false
		g.switch_ship(str(ship))
		for category in ["weapons","defence"]:
			var keys: Array=BattleGame.WEAPON_KEYS if category=="weapons" else BattleGame.DEFENSE_KEYS
			for index in g.module_entries(category).size():g.profile.loadout[category][index]={"key":keys[index%keys.size()],"level":1}
		g.reset_player()
		scene.build_ui()
		var baseline: Dictionary=g.profile.loadout.duplicate(true)
		for page in [0,5]:
			scene.equipment_tabs.current_tab=page
			await process_frame
			for mode in ["1","10","max"]:
				g.crew.set_upgrade_mode(g,"navigator",mode)
				g.assign_crew("navigator","equipment_upgrade","equipment")
				for budget in [0.0,1e6,1e100]:
					var totals: Array=[]
					var writes: Array=[]
					var calculations: Array=[]
					var ui: Array=[]
					var save_counts: Array=[]
					var upgrade_counts: Array=[]
					for sample in 12:
						g.save_enabled=false
						g.profile.loadout=baseline.duplicate(true)
						g.profile.resources={"1":budget,"2":budget}
						g.reset_player()
						scene.refresh_structure()
						scene.refresh_visible_cards()
						g.crew.timers.clear()
						g.clear_times()
						scene.upgrade_ui_us=0
						g.save_enabled=true
						var started:=Time.get_ticks_usec()
						g.crew.advance(g,1.0)
						var total:=Time.get_ticks_usec()-started
						if sample>=2:
							totals.append(total)
							writes.append(g.save_us)
							calculations.append(g.max_us)
							ui.append(scene.upgrade_ui_us)
							save_counts.append(g.saves)
							upgrade_counts.append(g.upgrades)
						await process_frame
					var report: Dictionary={"ship":ship,"modules":g.loadout_entries("weapons").size()+g.loadout_entries("defence").size(),"page":page,"mode":mode,"budget":str(budget),"total":stats(totals),"save":stats(writes),"max_search":stats(calculations),"ui":stats(ui),"saves_per_check":save_counts[0],"upgrades_per_check":upgrade_counts[0]}
					reports.append(report)
					print("CREW_PERF ",JSON.stringify(report))
	# Steady poor-budget frame ticks isolate scheduler overhead between due checks.
	g.save_enabled=false
	g.profile.resources={"1":0.0,"2":0.0}
	for active in [false,true]:
		g.assign_crew("navigator","equipment_upgrade" if active else "","equipment" if active else "")
		for speed in [1,5]:
			var samples: Array=[]
			for sample in 10:
				var started:=Time.get_ticks_usec()
				for tick in 600*speed:g.crew.advance(g,1.0/60.0)
				samples.append((Time.get_ticks_usec()-started)/600.0)
			reports.append({"scheduler_per_real_frame":stats(samples),"active":active,"speed":speed,"mode":"max","budget":0})
	var file:=FileAccess.open("res://.runtime/crew-performance.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(reports,"\t"))
	file.close()
	scene.queue_free()
	await process_frame
	print("CREW_PERF_COMPLETE ",reports.size()," scenarios")
	quit()
