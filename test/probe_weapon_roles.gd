extends SceneTree

# Focused, non-playthrough probe. Run only in the agreed serial Godot window.
class ScaledGame extends "res://scripts/presented_battle_game.gd":
	var balance_scale := 1.0
	var measured := {"hp_loss":0.0,"shield_loss":0.0,"shield_regen":0.0,"overkill":0.0,"reported":0.0}
	func equipment_stat(key: String, level: int, galaxy_charge := -1.0) -> Variant:
		var derived = super.equipment_stat(key,level,galaxy_charge)
		return GrowthNumber.multiply(derived,balance_scale) if key in ["laser","missile","cannon","longLaser","armour","shield"] else derived
	func settle_enemy_shield(enemy: Dictionary, at: float) -> bool:
		var before := float(enemy.get("shield",0))
		var accepted := super.settle_enemy_shield(enemy,at)
		if accepted and float(enemy.get("shield",0)) > before:
			measured.shield_regen += (float(enemy.shield)-before)/balance_scale
		return accepted
	func hit_enemy(enemy: Dictionary, raw, type: int, effects: Array = [], critical: bool = false, context: Dictionary = {}) -> void:
		if not settle_enemy_shield(enemy,enemy_shield_time if enemy_shield_hit_time < 0 else enemy_shield_hit_time):return
		var before_hp := float(enemy.hp)
		var before_shield := float(enemy.get("shield",0))
		var before_reported := float(measured.reported)
		super.hit_enemy(enemy,raw,type,effects,critical,context)
		var hp_loss := maxf(0.0,before_hp-float(enemy.hp))/balance_scale
		var shield_loss := maxf(0.0,before_shield-float(enemy.get("shield",0)))/balance_scale
		measured.hp_loss += hp_loss
		measured.shield_loss += shield_loss
		measured.overkill += maxf(0.0,float(measured.reported)-before_reported-hp_loss-shield_loss)

const WEAPONS := ["laser", "missile", "cannon", "longLaser"]
const CASES := {
	"medium": {"count":5,"hp":300.0,"shield":0.0,"delay":0.0,"rate":0.0,"reactive":false},
	"swarm": {"count":10,"hp":180.0,"shield":0.0,"delay":0.0,"rate":0.0,"reactive":false},
	"heavy": {"count":2,"hp":5000.0,"shield":0.0,"delay":0.0,"rate":0.0,"reactive":false},
	"reactive": {"count":2,"hp":5000.0,"shield":0.0,"delay":0.0,"rate":0.0,"reactive":true},
	"recovering_plain": {"count":1,"hp":1700.0,"shield":0.0,"delay":0.0,"rate":0.0,"reactive":false},
	"recovering": {"count":1,"hp":1100.0,"shield":600.0,"delay":1.8,"rate":0.08,"reactive":false},
	"candidate_a": {"count":1,"hp":1100.0,"shield":600.0,"delay":0.8,"rate":0.35,"reactive":false},
	"candidate_b": {"count":1,"hp":1100.0,"shield":1200.0,"delay":0.8,"rate":0.20,"reactive":false},
	"candidate_c": {"count":1,"hp":1100.0,"shield":600.0,"delay":0.8,"rate":0.20,"reactive":false},
	"candidate_d": {"count":1,"hp":1100.0,"shield":600.0,"delay":1.0,"rate":0.25,"reactive":false},
}

func frozen_db() -> ShipDatabase:
	var db := ShipDatabase.new()
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://qa/opening_frozen_contract.json"))
	for index in 3:db.levels[index] = original.levels[index]
	for id in original.groups:db.groups[id] = original.groups[id]
	return db

func run_case(weapon: String, case_name: String, scale: float, weapon_level := 1, mounts := 1, missile_base := 200.0, target_count := -1, target_hp := -1.0, missile_salvo := 4, laser_cd := 1.5, missile_cd := 2.4, native := false, armour_type := 0, shield_type := 2, cannon_base := 1500.0, beam_cd := 0.28, laser_base := 300.0) -> Dictionary:
	var settings: Dictionary = CASES[case_name].duplicate()
	if target_count > 0:settings.count = target_count
	if target_hp > 0:settings.hp = target_hp
	var db := frozen_db()
	db.data.enhance_config.base_critical_rate.value = 0.0
	if weapon == "missile":
		db.equipment.missile[0].dmg = missile_base
		db.equipment.missile[0].para1 = missile_salvo
		db.equipment.missile[0].cd = missile_cd
	if weapon == "laser":
		db.equipment.laser[0].cd = laser_cd
		db.equipment.laser[0].dmg = laser_base
	if weapon == "cannon":db.equipment.cannon[0].dmg = cannon_base
	if weapon == "longLaser":db.equipment.longLaser[0].cd = beam_cd
	var g: ScaledGame = ScaledGame.new(db, false)
	g.balance_scale = scale
	g.save_enabled = false
	g.stat_cache_enabled = true
	g.rng.seed = 1729
	g.start(1, false)
	g.spawn_group()
	g.profile.unlocked = BattleGame.EQUIPMENT.duplicate()
	g.profile.enhancementLevel = 0
	g.profile.loadout = g.empty_loadout(g.profile.selectedShip)
	for mount in mounts:g.profile.loadout.weapons[mount] = {"key":weapon,"level":weapon_level}
	# The native compiler requires every defence mount to have a supported row.
	# No target attacks in this probe, so these mounts cannot change weapon outcomes.
	for index in g.profile.loadout.defence.size():g.profile.loadout.defence[index] = {"key":"armour","level":1}
	g.reset_player()
	var derived_normalized := float(g.equipment_stat(weapon,weapon_level)) / scale
	var actors: Array[Dictionary] = []
	for index in int(settings.count):
		var enemy: Dictionary = db.enemies["270001"].duplicate(true)
		enemy.uid = index + 1
		enemy.slot = index
		enemy.x = 70.0 + float(index % 5) * 105.0
		enemy.y = 100.0 + float(index / 5) * 125.0
		enemy.hp = float(settings.hp) * scale
		enemy.max_hp = enemy.hp
		enemy.shield = float(settings.shield) * scale
		enemy.max_shield = enemy.shield
		enemy.shieldDelay = float(settings.delay)
		enemy.shieldRecovery = float(settings.rate)
		enemy.shieldType = shield_type
		enemy.armourType = armour_type
		enemy.shield_hit_at = 0.0
		enemy.shield_updated_at = 0.0
		enemy.equipment = []
		enemy.cooldowns = []
		enemy.drops = []
		if bool(settings.reactive):enemy.reactiveReduction = 1
		actors.append(enemy)
	g.enemies.assign(actors)
	g.call("refresh_missile_target_registry")
	g.change_state(BattleGame.State.TRAVEL)
	g.change_state(BattleGame.State.COMBAT)
	var observed := {"first_fire":-1.0,"first_hit":-1.0,"hit_total":0.0,"hit_count":0,"fire_times":[],"hit_times":[],"wave_clear_time":-1.0}
	var trace_events := OS.get_environment("SPACE_BALANCE_NATIVE_ROLES") == "1" or OS.get_environment("SPACE_BALANCE_ROLE_GAPS") == "1"
	g.event.connect(func(kind: String, payload: Dictionary) -> void:
		if kind == "fire" and not bool(payload.get("shot",{}).get("hostile",false)):
			if observed.first_fire < 0:observed.first_fire = g.enemy_shield_time
			if trace_events:observed.fire_times.append(g.enemy_shield_time)
		if kind == "hit" and not bool(payload.get("player",false)):
			if observed.first_hit < 0:observed.first_hit = g.enemy_shield_time
			if trace_events:observed.hit_times.append(g.enemy_shield_time)
			observed.hit_total += float(payload.amount) / scale
			observed.hit_count += 1
			g.measured.reported += float(payload.amount) / scale
		if kind == "wave_clear":observed.wave_clear_time = g.enemy_shield_time
	)
	var scope := "native_rich15_layer2" if int(settings.count) > 2 else "native_low_contract"
	var admission := {"requested":native,"scope":scope,"compiled_error":"","admitted":false,"owner_ticks":0,"feedback_rows":0,"handoffs":0,"kernel_metrics":{}}
	var owner:RefCounted = null
	if native:
		var descriptor:Dictionary = preload("res://scripts/native_execution_compiler.gd").new().compile(g,scope)
		admission.compiled_error = str(descriptor.get("error",""))
		if admission.compiled_error.is_empty():
			admission.admitted = g.admit_native_compiled_execution(scope)
		if admission.admitted:owner = g.native_execution
	var target_refs:Array[Dictionary] = g.enemies.duplicate() if admission.admitted else actors
	var elapsed := 0.0
	var max_reactive_stacks := 0
	for step in (3600 if not native or admission.admitted else 0):
		g.tick(1.0 / 60.0)
		elapsed += 1.0 / 60.0
		for actor in target_refs:max_reactive_stacks = maxi(max_reactive_stacks,int(actor.get("reactive_stacks",0)))
		if target_refs.all(func(actor):return float(actor.hp) <= 0.0):break
	if owner != null:
		admission.owner_ticks = owner.ticks
		admission.feedback_rows = owner.feedback_rows
		admission.handoffs = g.native_handoff_count
		admission.kernel_metrics = owner.kernel.metrics()
	var cleared:bool = target_refs.all(func(actor):return float(actor.hp) <= 0.0) and (not native or bool(admission.admitted))
	return {"executor":"native_compiled" if native else "legacy_presented","admission":admission if native else null,"production_stat_cache":g.stat_cache_enabled,"rng_seed":1729,"weapon":weapon,"weapon_level":weapon_level,"mounts":mounts,"case":case_name,"target_count":int(settings.count),"target_hp":float(settings.hp),"armour_type":armour_type,"shield_type":shield_type,"laser_cd":laser_cd if weapon=="laser" else null,"laser_base":laser_base if weapon=="laser" else null,"beam_cd":beam_cd if weapon=="longLaser" else null,"cannon_base":cannon_base if weapon=="cannon" else null,"scale":scale,"authored_missile_base":missile_base if weapon=="missile" else null,"missile_salvo":missile_salvo if weapon=="missile" else null,"missile_cd":missile_cd if weapon=="missile" else null,"derived_base_normalized":derived_normalized,"first_fire":observed.first_fire,"first_hit":observed.first_hit,"fire_times":observed.fire_times,"hit_times":observed.hit_times,"wave_clear_time":observed.wave_clear_time,"kill_time":elapsed if cleared else -1.0,"hit_total_normalized":observed.hit_total,"effective_hp_loss":g.measured.hp_loss if not native else null,"effective_shield_loss":g.measured.shield_loss if not native else null,"shield_regen":g.measured.shield_regen if not native else null,"overkill":g.measured.overkill if not native else null,"max_reactive_stacks":max_reactive_stacks,"hit_count":observed.hit_count,"initial_pool_normalized":int(settings.count) * (float(settings.hp)+float(settings.shield)),"cleared":cleared}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if OS.get_environment("SPACE_BALANCE_PRIORITY_BUDGET") == "1":
		for hp in [5000.0,6500.0,8000.0]:
			for weapon in ["missile","cannon"]:
				for native in [false,true]:print(JSON.stringify(run_case(weapon,"heavy",1.0,1,1,170.0,2,hp,4,1.5,2.4,native,1,2,1200.0,0.25,350.0)))
		for armour_type in [2,1]:
			for hp in [260.0,400.0]:
				for native in [false,true]:print(JSON.stringify(run_case("laser","medium",1.0,1,1,170.0,6,hp,4,1.5,2.4,native,armour_type,2,1200.0,0.25,350.0)))
		for weapon in ["laser","cannon"]:
			for native in [false,true]:print(JSON.stringify(run_case(weapon,"candidate_d",1.0,1,1,170.0,-1,-1.0,4,1.5,2.4,native,1,2,1200.0,0.25,350.0)))
		for weapon in ["missile","cannon"]:
			for native in [false,true]:print(JSON.stringify(run_case(weapon,"heavy",1.0e40,1,1,170.0,2,6500.0,4,1.5,2.4,native,1,2,1200.0,0.25,350.0)))
		for native in [false,true]:print(JSON.stringify(run_case("laser","medium",1.0e40,1,1,170.0,6,260.0,4,1.5,2.4,native,2,2,1200.0,0.25,350.0)))
		quit()
		return
	if OS.get_environment("SPACE_BALANCE_FOUR_BUDGET") == "1":
		for armour_type in [2,1]:
			for hp in [260.0,400.0]:
				for weapon in WEAPONS:
					for native in [false,true]:print(JSON.stringify(run_case(weapon,"medium",1.0,1,1,170.0,6,hp,4,1.5,2.4,native,armour_type,2,1000.0,0.25)))
		for case_name in ["heavy","reactive"]:
			for weapon in WEAPONS:
				for native in [false,true]:print(JSON.stringify(run_case(weapon,case_name,1.0,1,1,170.0,-1,-1.0,4,1.5,2.4,native,0,2,1000.0,0.25)))
		for weapon in WEAPONS:
			for native in [false,true]:print(JSON.stringify(run_case(weapon,"medium",1.0,1,1,170.0,10,100.0,4,1.5,2.4,native,0,2,1000.0,0.25)))
		for weapon in WEAPONS:
			for native in [false,true]:print(JSON.stringify(run_case(weapon,"medium",1.0,1,1,170.0,1,5000.0,4,1.5,2.4,native,1,2,1000.0,0.25)))
		for native in [false,true]:print(JSON.stringify(run_case("missile","medium",1.0,1,1,200.0,1,5000.0,4,1.5,2.4,native,1,2,1000.0,0.25)))
		for weapon in WEAPONS:
			for native in [false,true]:print(JSON.stringify(run_case(weapon,"candidate_d",1.0,1,1,170.0,-1,-1.0,4,1.5,2.4,native,1,2,1000.0,0.25)))
		quit()
		return
	if OS.get_environment("SPACE_BALANCE_TYPED_LEVEL_SLOTS") == "1":
		for armour_type in [2,1]:
			for weapon in ["laser","missile"]:
				for base in ([200.0,120.0] if weapon=="missile" else [200.0]):
					for native in [false,true]:print(JSON.stringify(run_case(weapon,"medium",1.0,4,2,base,6,900.0,4,1.5,2.4,native,armour_type)))
		quit()
		return
	if OS.get_environment("SPACE_BALANCE_TYPED_CANDIDATE") == "1":
		for scale in [1.0,1.0e40]:
			for pair in [["laser","medium",2,6,260.0],["missile","medium",2,6,260.0],["laser","medium",2,6,400.0],["missile","medium",2,6,400.0],["laser","medium",1,6,260.0],["missile","medium",1,6,260.0],["longLaser","candidate_d",1,-1,-1.0],["missile","candidate_d",1,-1,-1.0]]:
				for native in [false,true]:print(JSON.stringify(run_case(str(pair[0]),str(pair[1]),scale,1,1,120.0,int(pair[3]),float(pair[4]),4,1.5,2.4,native,int(pair[2]),2)))
		quit()
		return
	if OS.get_environment("SPACE_BALANCE_TYPED_SCALES") == "1":
		for scale in [1.0,1.0e40]:
			for armour_type in [2,1]:
				for weapon in ["laser","missile"]:
					for native in [false,true]:print(JSON.stringify(run_case(weapon,"medium",scale,1,1,200.0,6,260.0,4,1.5,2.4,native,armour_type)))
			for weapon in ["laser","missile"]:print(JSON.stringify(run_case(weapon,"medium",scale,1,1,200.0,6,400.0,4,1.5,2.4,false,2)))
			for weapon in ["longLaser","missile"]:
				for native in [false,true]:print(JSON.stringify(run_case(weapon,"candidate_d",scale,1,1,200.0,-1,-1.0,4,1.5,2.4,native,1,2)))
		quit()
		return
	if OS.get_environment("SPACE_BALANCE_TYPES") == "1":
		for armour_type in [2,1]:
			var healths := [120.0,180.0,220.0,260.0,300.0,400.0] if armour_type==2 else [100.0,180.0,220.0,300.0]
			for hp in healths:
				var count := 10 if hp==100.0 else 6
				for weapon in ["laser","missile"]:
					for base in ([200.0,120.0] if weapon=="missile" else [120.0]):
						print(JSON.stringify(run_case(weapon,"medium",1.0,1,1,base,count,hp,4,1.5,2.4,false,armour_type)))
		for weapon in WEAPONS:
			print(JSON.stringify(run_case(weapon,"candidate_d",1.0,1,1,120.0,-1,-1.0,4,1.5,2.4,false,1,2)))
		print(JSON.stringify(run_case("missile","candidate_d",1.0,1,1,200.0,-1,-1.0,4,1.5,2.4,false,1,2)))
		quit()
		return
	if OS.get_environment("SPACE_BALANCE_SCALE_INTERIOR") == "1":
		for scale in [100.0,1000.0,100000.0,1.0e40]:
			for weapon in ["laser","missile"]:print(JSON.stringify(run_case(weapon,"medium",scale,1,1,120.0,6,280.0)))
		quit()
		return
	if OS.get_environment("SPACE_BALANCE_NATIVE_SCALE_CANDIDATE") == "1":
		var failures := 0
		for scale in [1.0,100.0,1000.0,100000.0,1.0e40]:
			for pair in [["missile","medium",10,100.0],["laser","medium",10,100.0],["laser","medium",6,280.0],["missile","medium",6,280.0],["cannon","heavy",-1,-1.0],["longLaser","heavy",-1,-1.0],["cannon","reactive",-1,-1.0],["laser","reactive",-1,-1.0],["longLaser","candidate_d",-1,-1.0],["cannon","candidate_d",-1,-1.0]]:
				var row:Dictionary = run_case(str(pair[0]),str(pair[1]),scale,1,1,120.0,int(pair[2]),float(pair[3]),4,1.5,2.4,true)
				print(JSON.stringify(row))
				if not bool(row.admission.admitted) or int(row.admission.owner_ticks)<=0 or int(row.admission.kernel_metrics.get("root_attacks",0))<=0:
					failures += 1
					printerr("NATIVE_SCALE_ADMISSION: ",pair," scale=",scale)
			if scale in [1.0,1.0e40]:
				for hp in [240.0,241.0,300.0,301.0]:
					for weapon in ["laser","missile"]:
						var row:Dictionary = run_case(weapon,"medium",scale,1,1,120.0,6,hp,4,1.5,2.4,true)
						print(JSON.stringify(row))
						if not bool(row.admission.admitted) or int(row.admission.owner_ticks)<=0 or int(row.admission.kernel_metrics.get("root_attacks",0))<=0:
							failures += 1
							printerr("NATIVE_SCALE_EDGE_ADMISSION: ",weapon," hp=",hp," scale=",scale)
		print("NATIVE_SCALE_ADMISSION: 66 cases, ",failures," failures")
		quit(1 if failures else 0)
		return
	if OS.get_environment("SPACE_BALANCE_SCALE_CANDIDATE") == "1":
		for scale in [1.0,100.0,1000.0,100000.0,1.0e40]:
			# Established low, heavy, reactive and recovering roles: winner plus nearest rival.
			if scale != 1.0:
				for pair in [["missile","medium",10,100.0],["laser","medium",10,100.0],["cannon","heavy",-1,-1.0],["longLaser","heavy",-1,-1.0],["cannon","reactive",-1,-1.0],["laser","reactive",-1,-1.0],["longLaser","candidate_d",-1,-1.0],["cannon","candidate_d",-1,-1.0]]:
					print(JSON.stringify(run_case(str(pair[0]),str(pair[1]),scale,1,1,120.0,int(pair[2]),float(pair[3]))))
			# 241 and 300 are inside the one-pulse/three-missile interval;
			# 240 and 301 are immediate outside points at the ordinary and largest scale.
			var hp_values := [240.0,241.0,300.0,301.0] if scale in [1.0,1.0e40] else [241.0,300.0]
			for hp in hp_values:
				for weapon in ["laser","missile"]:print(JSON.stringify(run_case(weapon,"medium",scale,1,1,120.0,6,hp)))
		quit()
		return
	if OS.get_environment("SPACE_BALANCE_ROLE_GAPS") == "1":
		for pair in [["cannon","medium",6,280.0],["longLaser","medium",6,280.0],["laser","heavy",-1,-1.0],["laser","reactive",-1,-1.0]]:
			print(JSON.stringify(run_case(str(pair[0]),str(pair[1]),1.0,1,1,120.0,int(pair[2]),float(pair[3]))))
		quit()
		return
	if OS.get_environment("SPACE_BALANCE_NATIVE_ROLES") == "1":
		var failures := 0
		for pair in [["missile","medium",10,100.0],["laser","medium",6,280.0],["cannon","reactive",-1,-1.0],["longLaser","candidate_d",-1,-1.0]]:
			var old:Dictionary = run_case(str(pair[0]),str(pair[1]),1.0,1,1,120.0,int(pair[2]),float(pair[3]),4,1.5,2.4,false)
			var current:Dictionary = run_case(str(pair[0]),str(pair[1]),1.0,1,1,120.0,int(pair[2]),float(pair[3]),4,1.5,2.4,true)
			print(JSON.stringify(old))
			print(JSON.stringify(current))
			var admission:Dictionary = current.admission
			var metrics:Dictionary = admission.kernel_metrics
			# Time offsets are evidence for design review; no acceptance tolerance was authorized.
			if not bool(old.cleared) or not bool(current.cleared) or not bool(admission.admitted) or int(admission.owner_ticks)<=0 or int(admission.handoffs)!=1 or int(metrics.get("root_attacks",0))<=0 or int(metrics.get("deaths",0))!=int(current.target_count) or int(metrics.get("old_game_callbacks",-1))!=0 or int(old.hit_count)!=int(current.hit_count) or absf(float(old.hit_total_normalized)-float(current.hit_total_normalized))>0.001:
				failures += 1
				printerr("NATIVE_ROLE_MISMATCH: ",pair)
		print("NATIVE_ROLE_CONTRACT: 4 cases, ",failures," failures")
		quit(1 if failures else 0)
		return
	if OS.get_environment("SPACE_BALANCE_SHIELD120") == "1":
		for case_name in ["recovering","candidate_d"]:
			for weapon in WEAPONS:print(JSON.stringify(run_case(weapon,case_name,1.0,1,1,120.0)))
		quit()
		return
	if OS.get_environment("SPACE_BALANCE_CADENCE_OPTION") == "1":
		for n in [5,6,7,8]:
			for weapon in ["laser","missile"]:print(JSON.stringify(run_case(weapon,"medium",1.0,1,1,160.0,n,300.0,4,1.5,4.0)))
		for weapon in ["laser","missile"]:print(JSON.stringify(run_case(weapon,"medium",1.0,1,1,160.0,10,100.0,4,1.5,4.0)))
		quit()
		return
	if OS.get_environment("SPACE_BALANCE_SOFT_BREAKTHROUGH") == "1":
		print(JSON.stringify(run_case("laser","reactive",1.0,6,1,120.0,-1,-1.0,4,1.5)))
		print(JSON.stringify(run_case("missile","reactive",1.0,6,1,120.0,-1,-1.0,4,1.5)))
		print(JSON.stringify(run_case("laser","recovering",1.0,4,1,120.0,-1,-1.0,4,1.5)))
		quit()
		return
	if OS.get_environment("SPACE_BALANCE_DAMAGE_RATIO") == "1":
		for n in [5,6,7,8]:
			for hp in [250.0,280.0,300.0]:
				for weapon in ["laser","missile"]:print(JSON.stringify(run_case(weapon,"medium",1.0,1,1,120.0,n,hp,4,1.5)))
		for weapon in WEAPONS:
			print(JSON.stringify(run_case(weapon,"medium",1.0,1,1,120.0,10,100.0,4,1.5)))
		for case_name in ["heavy","reactive","recovering"]:
			for weapon in ["missile","cannon","longLaser"]:print(JSON.stringify(run_case(weapon,case_name,1.0,1,1,120.0,-1,-1.0,4,1.5)))
		quit()
		return
	if OS.get_environment("SPACE_BALANCE_INTERVAL_FINAL") == "1":
		for n in [5,6,7,8]:
			for hp in [220.0,260.0,300.0]:
				for weapon in ["laser","missile"]:print(JSON.stringify(run_case(weapon,"medium",1.0,1,1,200.0,n,hp,3,1.4)))
		quit()
		return
	if OS.get_environment("SPACE_BALANCE_FINAL") == "1":
		var scale := float(OS.get_environment("SPACE_BALANCE_SCALE"))
		if scale == 1.0:
			for case_name in ["medium","swarm","heavy","reactive","recovering"]:
				for weapon in WEAPONS:print(JSON.stringify(run_case(weapon,case_name,scale)))
		else:
			for pair in [["medium","laser"],["medium","missile"],["swarm","missile"],["heavy","cannon"],["heavy","missile"],["recovering","laser"],["recovering","longLaser"]]:
				print(JSON.stringify(run_case(str(pair[1]),str(pair[0]),scale)))
		quit()
		return
	if OS.get_environment("SPACE_BALANCE_REFINEMENT") == "1":
		for hp in [210.0,220.0,260.0,300.0]:
			for weapon in ["laser","missile"]:print(JSON.stringify(run_case(weapon,"medium",1.0,1,1,200.0,6,hp,3,1.4)))
		for case_name in ["swarm","heavy","reactive","candidate_d"]:
			for weapon in WEAPONS:print(JSON.stringify(run_case(weapon,case_name,1.0,1,1,200.0,-1,-1.0,3,1.4)))
		quit()
		return
	if OS.get_environment("SPACE_BALANCE_SALVO3") == "1":
		var n := int(OS.get_environment("SPACE_BALANCE_TARGET_COUNT"))
		var healths := [220.0,260.0,300.0] if n in [6,7] else [120.0,180.0,200.0,220.0,240.0,260.0,280.0,300.0,320.0]
		for hp in healths:
			for weapon in ["laser","missile"]:print(JSON.stringify(run_case(weapon,"medium",1.0,1,1,200.0,n,hp,3)))
		if n == 5:
			for case_name in ["heavy","reactive","candidate_a","candidate_c"]:
				for weapon in ["laser","missile","cannon","longLaser"]:print(JSON.stringify(run_case(weapon,case_name,1.0,1,1,200.0,-1,-1.0,3)))
		quit()
		return
	if OS.get_environment("SPACE_BALANCE_PULSE_SWEEP") == "1":
		var target_count := int(OS.get_environment("SPACE_BALANCE_TARGET_COUNT"))
		var missile_base := float(OS.get_environment("SPACE_BALANCE_MISSILE_BASE"))
		var healths := [180.0,220.0,260.0,300.0,340.0,500.0] if missile_base < 160.0 else [180.0,220.0,260.0,300.0,340.0,380.0,420.0,460.0,500.0,540.0,580.0,620.0]
		for hp in healths:
			for weapon in ["laser","missile"]:print(JSON.stringify(run_case(weapon,"medium",1.0,1,1,missile_base,target_count,hp)))
		quit()
		return
	if OS.get_environment("SPACE_BALANCE_SHIELD_SWEEP") == "1":
		for case_name in ["candidate_a","candidate_c","candidate_d"]:
			for weapon in WEAPONS:
				print(JSON.stringify(run_case(weapon,case_name,1.0,1,1,120.0)))
		quit()
		return
	if OS.get_environment("SPACE_BALANCE_CANDIDATES") == "1":
		for case_name in ["candidate_a","candidate_b"]:
			for weapon in WEAPONS:print(JSON.stringify(run_case(weapon,case_name,1.0)))
		print(JSON.stringify(run_case("laser","candidate_b",1.0,4)))
		print(JSON.stringify(run_case("laser","candidate_a",1.0,4)))
		for scale in [100.0,1000.0,100000.0,1.0e40]:
			for weapon in ["longLaser","laser"]:print(JSON.stringify(run_case(weapon,"candidate_a",scale)))
		for case_name in ["medium","swarm","heavy","reactive","candidate_a"]:
			print(JSON.stringify(run_case("missile",case_name,1.0,1,1,120.0)))
			print(JSON.stringify(run_case("missile",case_name,1.0,1,1,160.0)))
		quit()
		return
	for case_name in CASES:
		if str(case_name).begins_with("candidate_"):continue
		for weapon in WEAPONS:
			print(JSON.stringify(run_case(weapon,case_name,1.0)))
	# Check both expected specialist and nearest rival at each scale, with mechanics fixed.
	for scale in [100.0,1000.0,100000.0,1.0e40]:
		for pair in [["medium","laser"],["medium","missile"],["swarm","missile"],["swarm","laser"],["heavy","cannon"],["heavy","missile"],["reactive","cannon"],["reactive","missile"],["recovering","longLaser"],["recovering","laser"]]:
			print(JSON.stringify(run_case(str(pair[1]),str(pair[0]),scale)))
	print(JSON.stringify(run_case("cannon","reactive",1.0,1,2)))
	print(JSON.stringify(run_case("laser","reactive",1.0,6)))
	print(JSON.stringify(run_case("laser","recovering",1.0,4)))
	quit()
