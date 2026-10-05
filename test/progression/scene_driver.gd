extends RefCounted
## Canonical pre-simulation carrier pose and real scene muzzle/target providers.
## Mirrors battlefield._process and main._process ordering at X1 1/60.
var scene
var scene_path:="res://main.tscn"
var drop_post_vfx:=false
var ui_refresh_seconds:=0.0
var ui_elapsed:=0.0
var production_ui_ticks:=false
var enhancement_ui_elapsed:=0.0
func setup(tree:SceneTree,game):
	scene=load(OS.get_environment("QA_STAGE_SCENE") if not OS.get_environment("QA_STAGE_SCENE").is_empty() else scene_path).instantiate();scene.automation_args=["--capture"]
	tree.root.add_child(scene);scene.set_process(false);scene.game.save_enabled=false
	if scene.game.event.is_connected(scene.on_event):scene.game.event.disconnect(scene.on_event)
	scene.game=game;scene.db=game.db;scene.current_hull=str(game.profile.selectedShip)
	game.event.connect(scene.on_event)
	scene.enemy_poses.clear();scene.turret_visuals.clear();scene.fx_time=0.0;scene.demo_time=0.0
	scene.ship_view.set_hull(scene.current_hull);scene.ship_view.set_loadout(game.weapon_entries(),game.active_slot_count("weapons"));scene._set_reference_dimensions()
	game.launch_provider=scene._prototype_launch_pose;game.target_provider=scene._prototype_target_point
	game.drone_launch_provider=scene._prototype_drone_launch_pose
	game.rail_geometry_provider=scene._rail_geometry
	game.rail_target_point_provider=scene.entity_render_position
	# Fixture replacement is a global model reset: rebuild its dependent UI once.
	scene.build_ui()
	if production_ui_ticks:scene.hightech_page.set_process(false)
func before_tick(dt:float):
	if scene.ui_rebuild_pending and not scene.get_viewport().gui_is_dragging():
		scene.ui_rebuild_pending=false;scene.build_ui()
		if production_ui_ticks:scene.hightech_page.set_process(false)
	scene.ship_view.set_accelerated_quality(scene.game.speed>=10.0)
	scene.before_logical_game_tick(dt)
	scene.clock+=dt;scene.wave_hint=maxf(0,scene.wave_hint-dt)
func after_tick(dt:float):
 if drop_post_vfx:
  for key in ["particles","floats","pickup_effects","beam_visuals","projectile_visuals","destruction_events","missile_events","rail_events","enemy_impacts","pulse_events"]:scene.get(key).clear()
  scene.damage_pending.clear()
  if production_ui_ticks:
   scene.hightech_page.set_process(false);scene.hightech_page._process(dt)
   if is_instance_valid(scene.enhancement_panel):scene.enhancement_panel.metrics_timer.stop()
  return
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
	ui_elapsed+=dt
	if ui_refresh_seconds<=0.0 or ui_elapsed+0.000001>=ui_refresh_seconds:
		scene.refresh_visible_cards(ui_elapsed);scene.refresh_navigation();ui_elapsed=0.0
	if production_ui_ticks:
		# The workshop owns its0.2s sampling; use its actual production process
		# with logical UI dt instead of sampling the accelerated test's wall time.
		scene.hightech_page.set_process(false);scene.hightech_page._process(dt)
		# The enhancement metric timer is a UI-only1s sampler bound to refresh.
		# Event invalidation remains production-owned. No gameplay timer is driven.
		if is_instance_valid(scene.enhancement_panel):
			scene.enhancement_panel.metrics_timer.stop()
			if scene.enhancement_panel.visible:
				enhancement_ui_elapsed+=dt
				if enhancement_ui_elapsed>=scene.enhancement_panel.metrics_timer.wait_time:
					enhancement_ui_elapsed=fmod(enhancement_ui_elapsed,scene.enhancement_panel.metrics_timer.wait_time)
					scene.enhancement_panel.refresh()
			else:enhancement_ui_elapsed=0.0
func close():
	if is_instance_valid(scene):scene.queue_free()
