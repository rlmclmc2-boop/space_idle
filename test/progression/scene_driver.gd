extends RefCounted
## Canonical pre-simulation carrier pose and real scene muzzle/target providers.
## Mirrors battlefield._process and main._process ordering at X1 1/60.
var scene
func setup(tree:SceneTree,game):
	scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"]
	tree.root.add_child(scene);scene.set_process(false);scene.game.save_enabled=false
	if scene.game.event.is_connected(scene.on_event):scene.game.event.disconnect(scene.on_event)
	scene.game=game;scene.db=game.db;scene.current_hull=str(game.profile.selectedShip)
	game.event.connect(scene.on_event)
	scene.enemy_poses.clear();scene.turret_visuals.clear();scene.fx_time=0.0;scene.demo_time=0.0
	scene.ship_view.set_hull(scene.current_hull);scene.ship_view.set_loadout(game.weapon_entries(),game.active_slot_count("weapons"));scene._set_reference_dimensions()
	game.launch_provider=scene._prototype_launch_pose;game.target_provider=scene._prototype_target_point
func before_tick(dt:float):
	scene.ship_view.set_accelerated_quality(scene.game.speed>=10.0)
	if scene.current_hull!=str(scene.game.profile.selectedShip):
		scene.current_hull=str(scene.game.profile.selectedShip);scene.ship_view.set_hull(scene.current_hull);scene._set_reference_dimensions()
	scene.ship_view.set_loadout(scene.game.weapon_entries(),scene.game.active_slot_count("weapons"))
	scene.demo_time+=dt
	var aim:Vector2=scene.player_render_position()+Vector2(0,-450)
	if not scene.game.enemies.is_empty():aim=scene.enemy_render_position(scene.game.enemies[0])
	scene.ship_view.set_pose(scene.player_render_position()+scene.reference_offset,scene.reference_height,0.0,aim,scene.demo_time,scene.shield_enabled,false,dt)
	scene.shield_before_hit=scene.game.player.shield
	scene.clock+=dt;scene.fx_time+=dt;scene.wave_hint=maxf(0,scene.wave_hint-dt);scene.advance_turrets(dt)
func after_tick(dt:float):
	# Retain the full production event handler. Mirror its bounded VFX cleanup;
	# none of these containers own game projectiles or enemy health.
	scene.sync_beam_visuals();scene.advance_projectile_visuals(dt)
	for p in scene.particles:
		p.life-=dt;p.pos+=p.vel*dt;p.vel*=.97
	scene.particles=scene.particles.filter(func(p):return p.life>0)
	for f in scene.floats:
		f.life-=dt
		if f.get("damage",false):f.pos.y-=dt*12
	scene.floats=scene.floats.filter(func(f):return f.life>0)
	for effect in scene.pickup_effects:effect.life-=dt
	scene.pickup_effects=scene.pickup_effects.filter(func(effect):return effect.life>0)
	scene.flush_damage_numbers();scene.shake=maxf(0,scene.shake-dt*18);scene.message_time=maxf(0,scene.message_time-dt)
	scene.destruction_events=scene.destruction_events.filter(func(e):return scene.fx_time-float(e.born)<.65)
	scene.missile_events=scene.missile_events.filter(func(e):return scene.fx_time-float(e.born)<float(e.get("duration",.25)))
	scene.rail_events=scene.rail_events.filter(func(e):return scene.fx_time-float(e.born)<maxf(scene.rail_vfx.flash_seconds,scene.rail_vfx.impact_seconds))
	scene.enemy_impacts=scene.enemy_impacts.filter(func(e):return scene.fx_time-float(e.born)<.12)
	scene.pulse_events=scene.pulse_events.filter(func(e):return scene.fx_time-float(e.born)<.14)
func close():
	if is_instance_valid(scene):scene.queue_free()
