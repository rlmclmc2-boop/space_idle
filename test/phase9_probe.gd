extends SceneTree
# Temporary Phase 9 probe, loaded only in test/work copies by test_performance.py.
class Meter:
	extends RefCounted
	var enabled := false
	var calls := {}
	var times := {}
	var build_frames := {}
	var extra := {}
	func record(key: String, elapsed: int) -> void:
		if not enabled: return
		calls[key] = int(calls.get(key,0))+1
		if not times.has(key): times[key] = []
		times[key].append(elapsed)
		if key == "main.build_ui":
			var frame := Engine.get_process_frames()
			build_frames[frame] = int(build_frames.get(frame,0))+1
	func count(key: String, amount := 1) -> void:
		if enabled: extra[key] = int(extra.get(key,0))+amount
	func reset() -> void:
		calls.clear(); times.clear(); build_frames.clear(); extra.clear()

var meter := Meter.new()
var results := []
var scene
const WARM := 30
const SAMPLES := 120

func summary(values: Array) -> Dictionary:
	if values.is_empty(): return {"n":0,"median_us":0,"p95_us":0,"total_us":0}
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	for value in values: total += value
	return {"n":values.size(),"median_us":sorted[sorted.size()/2],"p95_us":sorted[mini(sorted.size()-1,int(ceil(sorted.size()*0.95))-1)],"total_us":total}

func _initialize() -> void:
	Engine.set_meta("phase9",meter)
	call_deferred("run")

func configure(kind: String, speed: int) -> void:
	seed(1701)
	var db := ShipDatabase.new()
	var g := BattleGame.new(db,false)
	g.rng.seed = 1701
	g.profile.resources = {"1":10000.0,"2":1000.0}
	if kind not in ["IDLE","NORMAL"]:
		g.profile.cleared = range(1,db.levels.size()+1)
		g.profile.unlocked = BattleGame.EQUIPMENT.duplicate()
		g.profile.hightechOrder = g.hightech_slots()
	if kind in ["FULL_LOADOUT","HEAVY_COMBAT"]:
		var largest := g.first_ship()
		for key in db.ships:
			if int(db.ship(key).weaponSlots)>int(db.ship(largest).weaponSlots): largest=key
		g.profile.selectedShip=largest
		g.profile.loadout=g.empty_loadout(largest)
		for category in ["weapons","defence"]:
			var keys := BattleGame.WEAPON_KEYS if category=="weapons" else BattleGame.DEFENSE_KEYS
			for i in range(g.profile.loadout[category].size()):
				g.profile.loadout[category][i]={"key":keys[i%keys.size()],"level":1}
	if kind=="LARGE_VALUE": g.profile.resources={"1":1e100,"2":1e100}
	if kind=="LARGE_SCIENTISTS":
		g.profile.resources={"1":1e100,"2":1e100}
		g.profile.scientists=1000000
		g.profile.scientistAssignments[BattleGame.ENERGY_FOCUS]=1000
	if kind=="INCOME_60S":
		var now := Time.get_unix_time_from_system()
		for i in range(240):
			g.resource_samples.append({"time":now-float(i)/4.0,"id":"1","amount":10.0,"origin":"drop"})
	g.start(1,false)
	if kind in ["NORMAL","FULL_LOADOUT","HEAVY_COMBAT"]:
		if kind=="HEAVY_COMBAT":
			var best_score := -1
			for stage in range(db.levels.size()):
				for idx in range(db.levels[stage].groups.size()):
					var row: Dictionary=db.groups[str(int(db.levels[stage].groups[idx].id))]
					var score := 0
					for id in row.slots:
						if id!=null: score+=1+db.enemies[str(int(id))].equipment.size()
					if score>best_score:
						best_score=score; g.stage=stage+1; g.group_index=idx
		g.spawn_group()
	else: g.state=BattleGame.State.MAIN_MENU
	g.speed=speed
	g.save_enabled=true
	scene.game=g; scene.db=db
	g.event.connect(scene.on_event)
	scene.equipment_page=2 if kind in ["UI_SCIENTISTS","LARGE_VALUE","LARGE_SCIENTISTS"] else 3 if kind=="UI_CHARGE" else 0
	scene.particles.clear(); scene.floats.clear()
	scene.build_ui()

func run() -> void:
	scene=load("res://scripts/main.gd").new()
	scene.automation_args=["--capture"]
	root.add_child(scene)
	scene.automation_args=[]
	scene.set_process(false)
	for kind in ["IDLE","NORMAL","FULL_LOADOUT","HEAVY_COMBAT","UI_EQUIPMENT","UI_SCIENTISTS","UI_CHARGE","LARGE_VALUE","LARGE_SCIENTISTS","INCOME_60S"]:
		for speed in [1,2,5]:
			meter.enabled=false
			configure(kind,speed)
			await process_frame
			var frames := []
			var cpu := []
			var peak_projectiles := 0
			var peak_enemies := 0
			for i in range(WARM+SAMPLES):
				if i==WARM: meter.reset(); meter.enabled=true
				var started := Time.get_ticks_usec()
				scene._process(1.0/60.0)
				var elapsed := Time.get_ticks_usec()-started
				peak_projectiles=maxi(peak_projectiles,scene.game.projectiles.size())
				peak_enemies=maxi(peak_enemies,scene.game.enemies.size())
				await process_frame
				if i>=WARM:
					frames.append(Time.get_ticks_usec()-started); cpu.append(elapsed)
			var timings := {}
			for key in meter.times: timings[key]=summary(meter.times[key])
			var redundant := 0
			for count in meter.build_frames.values(): redundant+=maxi(0,int(count)-1)
			results.append({"scenario":kind,"speed":speed,"frame":summary(frames),"main_cpu":summary(cpu),"timings":timings,"calls":meter.calls.duplicate(),"extra":meter.extra.duplicate(),"build_redundant":redundant,"peak_projectiles":peak_projectiles,"peak_enemies":peak_enemies})
			print("Measured ",kind," ",speed,"X")
			meter.enabled=false
	# Isolated one-shot work: actual filesystem saves and maximum configured offline duration.
	configure("UI_SCIENTISTS",1)
	var save_times := []
	var offline_times := []
	var g: BattleGame=scene.game
	# Production initialization settles offline work before main connects its UI listener.
	g.event.disconnect(scene.on_event)
	g.profile.scientists=100
	g.profile.scientistAssignments[BattleGame.ENERGY_FOCUS]=100
	var original := g.profile.duplicate(true)
	for i in range(35):
		var start := Time.get_ticks_usec()
		g.save_progress()
		if i>=5: save_times.append(Time.get_ticks_usec()-start)
		g.profile=original.duplicate(true)
		start=Time.get_ticks_usec()
		g.settle_offline_resources({"offlineSavedAt":0,"offlineRates":{"1":10,"2":1}},86400)
		g.advance_charge(float(g.db.config.offlineMax)*3600.0)
		g.advance_hightech(float(g.db.config.offlineMax)*3600.0)
		if i>=5: offline_times.append(Time.get_ticks_usec()-start)
	results.append({"scenario":"OFFLINE_SAVE","save":summary(save_times),"offline":summary(offline_times)})
	var output := FileAccess.open("res://.runtime/performance.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"samples":SAMPLES,"warmup":WARM,"renderer":DisplayServer.get_name(),"results":results}))
	output.close()
	print("Phase9 probe complete: ",results.size()," scenarios")
	scene.queue_free()
	print("Cleanup queued")
	await process_frame
	print("Cleanup frame 1")
	await process_frame
	print("Cleanup frame 2")
	Engine.remove_meta("phase9")
	quit()
