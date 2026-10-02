extends SceneTree
const Adapter=preload("res://qa/presented_balance_game.gd")
const Policy=preload("res://scripts/balance_autoplayer.gd")
class Native extends "res://scripts/presented_battle_game.gd":
	var simulated_time:=0.0
	func _init(db):
		super(db,false);profile.hightechSavedAt=0.0
	func economy_time()->float:return simulated_time
	func tick(dt:float)->void:
		simulated_time+=dt;super.tick(dt)
var scenes:Array=[]
func prepare(game):
	var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"]
	root.add_child(scene);scene.set_process(false);scene.game.save_enabled=false
	scene.game=game;scene.db=game.db;scene.current_hull=str(game.profile.selectedShip)
	scene.enemy_poses.clear();scene.turret_visuals.clear();scene.fx_time=0.0;scene.demo_time=0.0
	scene.ship_view.set_hull(scene.current_hull);scene.ship_view.set_loadout(game.weapon_entries(),game.active_slot_count("weapons"));scene._set_reference_dimensions()
	game.launch_provider=scene._prototype_launch_pose;game.target_provider=scene._prototype_target_point
	return scene
func visual_step(scene,dt:float):
	scene.demo_time+=dt
	if scene.current_hull!=str(scene.game.profile.selectedShip):
		scene.current_hull=str(scene.game.profile.selectedShip);scene.ship_view.set_hull(scene.current_hull);scene._set_reference_dimensions()
	scene.ship_view.set_loadout(scene.game.weapon_entries(),scene.game.active_slot_count("weapons"))
	var aim:Vector2=scene.player_render_position()+Vector2(0,-450)
	if not scene.game.enemies.is_empty():aim=scene.enemy_render_position(scene.game.enemies[0])
	scene.ship_view.set_pose(scene.player_render_position()+scene.reference_offset,scene.reference_height,0.0,aim,scene.demo_time,scene.shield_enabled,false,dt)
	scene.fx_time+=dt;scene.advance_turrets(dt)
func signature(g)->Dictionary:
	return {"stage":g.stage,"node":g.group_index,"state":g.state,"distance":g.distance,"player":g.player,"enemies":g.enemies,"resources":g.profile.resources,"loadout":g.profile.loadout,"tech":g.profile.hightechLevels,"points":g.profile.techPoints,"scientists":g.profile.scientists,"assignments":g.profile.scientistAssignments,"reactor":g.profile.reactorLevel,"allocation":g.profile.reactorAllocation,"rng":str(g.rng.state),"cleared":g.profile.cleared,"production":g.production_time(),"furnace_peak":g.profile.furnaceIncomePeak,"projectiles":g.projectiles.size(),"queue":g.missile_queue.size(),"motion_clock":g.motion_clock}
func _initialize():call_deferred("run")
func run():
	var a=Adapter.new(ShipDatabase.new());var b=Native.new(ShipDatabase.new())
	a.stat_cache_enabled=true;b.stat_cache_enabled=true
	a.rng.seed=20261002;b.rng.seed=20261002
	var scene_mode:=OS.get_environment("PROGRESSION_COMPARE_SCENE")=="1"
	if scene_mode:scenes=[prepare(a),prepare(b)]
	var policies=[Policy.new(),Policy.new()]
	for policy in policies:policy.configure("BALANCED",20261002)
	var duration:=int(OS.get_environment("PROGRESSION_COMPARE_DURATION"))
	if duration<=0:duration=900
	var next_visit:=0.0
	for step in duration*60:
		if step/60.0+.000001>=next_visit:
			for index in 2:
				var game=a if index==0 else b
				for drop in game.drops.duplicate():game.collect(drop,true)
				policies[index].act(game,step/60.0)
			next_visit=step/60.0+(10.0 if a.profile.highestLevel<=5 else 120.0)
		if scene_mode:
			for scene in scenes:visual_step(scene,1.0/60.0)
		a.tick(1.0/60.0);b.tick(1.0/60.0)
		if (step+1)%60==0:
			var left=JSON.parse_string(JSON.stringify(signature(a)));var right=JSON.parse_string(JSON.stringify(signature(b)))
			if left!=right:
				var f=FileAccess.open("res://.runtime/formal-adapter-mismatch.json",FileAccess.WRITE);f.store_string(JSON.stringify({"second":(step+1)/60,"adapter":left,"native":right},"\t"));f.close()
				printerr("FORMAL_ADAPTER_MISMATCH second=",(step+1)/60);quit(1);return
		if (step+1)%36000==0:print("FORMAL_COMPARE_HEARTBEAT seconds=",(step+1)/60," stage=",a.stage)
	print("FORMAL_ADAPTER_PASS seconds=",duration," scene_providers=",scene_mode," stage=",a.stage," node=",a.group_index," scope=same formal sparse decisions; every-second state/resources/RNG/research/queue check")
	for scene in scenes:scene.queue_free()
	quit()
