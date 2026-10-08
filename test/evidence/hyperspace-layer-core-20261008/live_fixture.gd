extends SceneTree
class IsolatedUI extends "res://scripts/battlefield.gd":
	func create_battle_game(_persist:bool)->BattleGame:
		var prototype=preload("res://scripts/presented_battle_game.gd").new(db,false);db=prototype.db
		prototype.launch_provider=_prototype_launch_pose;prototype.drone_launch_provider=_prototype_drone_launch_pose;prototype.target_provider=_prototype_target_point;prototype.rail_geometry_provider=_rail_geometry;prototype.rail_target_point_provider=entity_render_position
		prototype.stat_cache_enabled=true;return prototype
var failures:=0
var scene
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	print("LIVE_CHECK ",label,"=",ok)
	if not ok:failures+=1
func click(button:Button)->void:
	var position:Vector2=root.get_final_transform()*(button.get_screen_transform()*(button.size/2))
	DisplayServer.warp_mouse(position)
	print("CLICK_POSITION ",position," root_final=",root.get_final_transform())
	var motion:=InputEventMouseMotion.new();motion.position=position;motion.global_position=position;Input.parse_input_event(motion)
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=position;event.global_position=position;Input.parse_input_event(event)
		await process_frame
func screenshot(name:String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/workspace/bug-qa/performance-20261008/"+name+".png")
func run()->void:
	root.size=Vector2i(1180,812);Engine.max_fps=60
	scene=load("res://main.tscn").instantiate();scene.set_script(IsolatedUI);scene.automation_args=["--capture"];root.add_child(scene);scene.automation_args=[];scene.set_process(false)
	var g=scene.game;g.save_enabled=false;g.stat_cache_enabled=true;g.profile.onboarding.completed=true;g.profile.cleared=range(1,34);g.profile.highestLevel=34;g.rebuild_unlocks();g.pending_unlocks.clear();g.load_hyperspace_routes()
	g.profile.loadout.weapons=[{"key":"longLaser","level":14},{"key":"missile","level":14},{"key":"laser","level":14}]
	g.profile.loadout.defence=[{"key":"armour","level":14},{"key":"shield","level":14}];g.invalidate_stat_cache()
	g.start(14,false);g.spawn_group();g.speed=1.0;g.paused=true;g.cooldowns[g.slot_id("weapons",1)]=0.0
	scene.refresh_structure();scene.refresh_navigation();scene.set_process(true)
	for i in 12:await process_frame
	g.paused=false
	for i in 2:await process_frame
	g.paused=true;scene._process(0.0)
	var before:=preload("res://scripts/hyperspace_battle_return.gd").capture(g);var hp:Variant=g.player.armour;var enemies:int=g.enemies.size();var point:int=g.group_index
	await screenshot("layer-live-main-before")
	var button:=Button.new();button.text="QA: challenge next layer";button.position=Vector2(780,12);button.size=Vector2(260,38);button.z_index=100;scene.add_child(button)
	button.pressed.connect(func():print("START_CALLBACK ",g.start_hyperspace_challenge("alpha")," error=",g.manual_hyperspace.last_error));await process_frame
	await click(button)
	check(g.manual_hyperspace.active and g.stage==1,"real input starts immediate layer1 challenge")
	g.paused=true;scene._process(0.0);await screenshot("layer-live-challenge")
	button.text="QA: exit challenge";var connections:Array=button.pressed.get_connections()
	for connection in connections:button.pressed.disconnect(connection.callable)
	button.pressed.connect(func():g.exit_hyperspace_challenge());await click(button)
	check(not g.manual_hyperspace.active and g.stage==14 and g.player.armour==hp and g.enemies.size()==enemies and g.group_index==point,"real input returns main health and encounter")
	check(preload("res://scripts/hyperspace_battle_return.gd").capture(g)==before,"actual rendered battle graph exact after return")
	button.queue_free();await process_frame;scene._process(0.0);await screenshot("layer-live-main-after")
	print("LIVE_SCOPE normalX1 short segment, actual rendered scene and routed mouse clicks; isolated QA fixture, no clear acceptance. source4cf702a+working claim API; engine=",Engine.get_version_info().string," checks3 failures=",failures)
	quit(1 if failures else 0)
