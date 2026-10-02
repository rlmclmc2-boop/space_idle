extends SceneTree
class IsolatedUI extends "res://scripts/battlefield.gd":
	func create_battle_game(_persist: bool) -> BattleGame:return super.create_battle_game(false)
	func show_qa_tools() -> void:pass
var failures := 0
var checks := 0
var elapsed := 0.0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var scene=load("res://main.tscn").instantiate()
	scene.set_script(IsolatedUI);scene.music_on=false;scene.automation_args=["--capture"]
	root.add_child(scene);current_scene=scene;scene.set_process(false);scene.automation_args=[]
	var g=scene.game
	g.save_enabled=false;g.rng.seed=92841;g.speed=1
	g.profile.onboarding.completed=true
	if is_instance_valid(scene.beginner_guide):scene.beginner_guide.hide()
	g.profile.cleared=range(1,76);g.rebuild_unlocks();g.profile.selectedShip="Frigate"
	g.profile.loadout={"weapons":[{"key":"cannon","level":1},{"key":"laser","level":1},{"key":"laser","level":1}],"defence":[{"key":"armour","level":10},{"key":"","level":1}]}
	g.db.data.enhance_config.base_critical_rate.value=0;g.db.data.enhance_config.repeat_probability.value=0
	g.start(1,false);g.spawn_group();g.enemies.resize(1)
	var target: Dictionary=g.enemies[0]
	target.hp=1e100;target.max_hp=1e100;target.equipment=[];target.cooldowns=[];target.x=300;target.y=120
	g.refresh_missile_target_registry()
	var period: float=g.db.equip("cannon",1).cd
	g.cooldowns={"weapons_0":period,"weapons_1":float(g.db.equip("laser",1).cd),"weapons_2":float(g.db.equip("laser",1).cd)}
	scene.refresh_structure();scene.refresh_tab_visibility()
	var fires: Array[float]=[];var pulse_fires: Array[float]=[];var impacts: Array=[]
	g.event.connect(func(kind,info):
		if kind=="fire" and not info.shot.hostile:
			if info.shot.key=="cannon":fires.append(elapsed)
			elif info.shot.key=="laser":pulse_fires.append(elapsed)
		if kind=="projectile_impact" and info.shot.key=="cannon":impacts.append(info.shot))
	var folder := ProjectSettings.globalize_path("res://../railgun-frames")
	DirAccess.make_dir_recursive_absolute(folder)
	var baseline := OS.get_environment("RAILGUN_BASELINE")=="1"
	var capture_frames := OS.get_environment("RAILGUN_RECORD")=="1"
	var firing_frame := -1
	for frame in 82:
		for step in 6:
			elapsed+=1.0/60.0
			scene._process(1.0/60.0)
		await process_frame;await RenderingServer.frame_post_draw
		if capture_frames:root.get_texture().get_image().save_png(folder+"/frame-%03d.png"%frame)
		if absf(elapsed-(period-0.1))<0.04:root.get_texture().get_image().save_png("res://../railgun-charge.png")
		if not fires.is_empty() and firing_frame<0:firing_frame=frame
		if frame==firing_frame+1 and firing_frame>=0:root.get_texture().get_image().save_png("res://../railgun-and-laser-flight.png")
	check(fires.size()>=2,"At least two actual primary cannon launches recorded")
	for i in range(1,fires.size()):check(absf(fires[i]-fires[i-1]-period)<0.034,"Charge adds no time to the configured firing period")
	check(pulse_fires.size()>fires.size()*3,"High-frequency lasers retain independent launches")
	# Drain the last in-flight shot without scheduling another primary attack.
	for _i in 120:g.tick_projectiles(1.0/60.0)
	check(impacts.size()==fires.size(),"Each launched cannon has exactly one primary impact")
	check(scene.rail_origin_max_error<0.01 and scene.pulse_origin_max_error<0.01,"Both weapon families retain their actual muzzle origins")
	print("BASE TIMING period=",period," cannon_fires=",fires," laser_fires=",pulse_fires.size()," cannon_impacts=",impacts.size())
	if not baseline:
		check(is_equal_approx(period,3.5),"Requested base cannon period is 3.5 seconds")
		var fx=scene.railgun_fx
		check(fx.player_charge(3.5,1.0,3.5)==0.0 and fx.player_charge(1.0,1.0,3.5)==0.0,"No charging before the final configured charge window")
		check(is_equal_approx(fx.player_charge(0.45,1.0,3.5),0.5),"Charge occupies the final 0.9 seconds of the base period")
		check(is_equal_approx(fx.player_charge(0.225,0.5,3.5),0.5),"Charge scales with the legal cooldown modifier")
		var before_rng: int=g.rng.state
		for i in 100:fx.player_charge(float(i)*0.01,1.0,period)
		check(g.rng.state==before_rng,"Charge presentation never consumes combat RNG")
		# Exercise the actual legal branch, scheduler and UI adapter together.
		g.profile.enhancementLevel=50
		g.profile.loadout.weapons[0].level=150
		g.reset_player();g.set_enhancement_branch("weapons","proficiency",2,"B")
		var entry: Dictionary=g.slot_entry("weapons",0)
		var multiplier: float=g.enhancement_branches.cooldown_multiplier(g,entry)
		var modified_period: float=g.player_weapon_row(entry).cd
		check(multiplier<1.0 and is_equal_approx(modified_period,period*multiplier),"Legal proficiency branch controls cannon cadence")
		g.cooldowns["weapons_0"]=fx.player_charge_time*multiplier*0.5
		check(is_equal_approx(scene.player_railgun_charge(0),0.5),"Live charge adapter uses the same legal cooldown modifier")
		fires.clear();g.projectiles.clear();g.cooldowns["weapons_0"]=modified_period
		for _step in int(ceil(modified_period*3.1*60.0)):
			elapsed+=1.0/60.0;g.tick(1.0/60.0)
		check(fires.size()>=3,"Modified cannon fires repeatedly through the canonical scheduler")
		for i in range(1,fires.size()):check(absf(fires[i]-fires[i-1]-modified_period)<0.034,"Charge does not delay modified firing cadence")
		var variant=ShipDatabase.new()
		for key in ["charge_radius","trail_length","trail_width","flash_seconds","impact_seconds","impact_radius","penetration_length"]:
			var expected: float=variant.weapon_motion_value("rail_"+key,0.0)*0.75
			variant.data.weapon_motion["rail_"+key].value=expected
			scene.rail_vfx.configure(variant)
			check(is_equal_approx(float(scene.rail_vfx.get(key)),expected),"Presentation consumes table parameter "+key)
		variant.data.weapon_motion.rail_charge_seconds.value=0.6
		fx.configure(variant)
		check(is_equal_approx(fx.player_charge(0.3,1.0,period),0.5),"Charge timing consumes changed table value")
	var ticks: float=scene.fx_time
	g.paused=true;scene._process(0.2)
	check(is_equal_approx(scene.fx_time,ticks),"Pause freezes the weapon animation clock")
	print("RAIL PRESENTATION checks=",checks," failures=",failures," period=",period," cannon_fires=",fires," laser_fires=",pulse_fires.size()," cannon_impacts=",impacts.size())
	scene.game.launch_provider=Callable();scene.game.target_provider=Callable();scene.queue_free();await process_frame;current_scene=null
	quit(1 if failures else 0)
