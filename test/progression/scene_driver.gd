extends RefCounted
## Canonical pre-simulation carrier pose and real scene muzzle/target providers.
## Mirrors battlefield._process and main._process ordering at X1 1/60.
var scene
func setup(tree:SceneTree,game):
	scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"]
	tree.root.add_child(scene);scene.set_process(false);scene.game.save_enabled=false
	scene.game=game;scene.db=game.db;scene.current_hull=str(game.profile.selectedShip)
	scene.enemy_poses.clear();scene.turret_visuals.clear();scene.fx_time=0.0;scene.demo_time=0.0
	scene.ship_view.set_hull(scene.current_hull);scene.ship_view.set_loadout(game.weapon_entries(),game.active_slot_count("weapons"));scene._set_reference_dimensions()
	game.launch_provider=scene._prototype_launch_pose;game.target_provider=scene._prototype_target_point
func before_tick(dt:float):
	if scene.current_hull!=str(scene.game.profile.selectedShip):
		scene.current_hull=str(scene.game.profile.selectedShip);scene.ship_view.set_hull(scene.current_hull);scene._set_reference_dimensions()
	scene.ship_view.set_loadout(scene.game.weapon_entries(),scene.game.active_slot_count("weapons"))
	scene.demo_time+=dt
	var aim:Vector2=scene.player_render_position()+Vector2(0,-450)
	if not scene.game.enemies.is_empty():aim=scene.enemy_render_position(scene.game.enemies[0])
	scene.ship_view.set_pose(scene.player_render_position()+scene.reference_offset,scene.reference_height,0.0,aim,scene.demo_time,scene.shield_enabled,false,dt)
	scene.fx_time+=dt;scene.advance_turrets(dt)
func close():
	if is_instance_valid(scene):scene.queue_free()
