extends SceneTree
class UI extends "res://scripts/battlefield.gd":
	func show_qa_tools()->void:pass
	func show_chrono_login_report()->void:pass
	func create_battle_game(_persist:bool)->BattleGame:
		var g=preload("res://scripts/presented_battle_game.gd").new(db,false)
		db=g.db;g.native_execution_auto=false
		g.launch_provider=_prototype_launch_pose;g.drone_launch_provider=_prototype_drone_launch_pose
		g.target_provider=_prototype_target_point;g.rail_geometry_provider=_rail_geometry;g.rail_target_point_provider=entity_render_position
		g.enable_compiled_combat_rules()
		return g
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize()->void:call_deferred("run")
func picture(scene)->void:
	scene.battle_layer.queue_redraw();scene.pulse_layer.queue_redraw()
	await process_frame;await RenderingServer.frame_post_draw
func run()->void:
	var scene=load("res://main.tscn").instantiate();scene.set_script(UI)
	scene.automation_args=["--capture"];scene.music_on=false
	root.add_child(scene);current_scene=scene;scene.set_process(false);scene.automation_args=[]
	var g=scene.game;g.save_enabled=false;g.speed=1;g.rng.seed=1975
	g.profile.onboarding.completed=true;scene.beginner_guide.hide()
	g.profile.unlocked=BattleGame.EQUIPMENT.duplicate();g.pending_unlocks.clear()
	g.profile.loadout={"weapons":[{"key":"laser","level":1},{"key":"missile","level":1},{"key":"longLaser","level":1}],"defence":[{"key":"armour","level":1},{"key":"shield","level":1}]}
	g.invalidate_stat_cache();g.reset_player();g.state=BattleGame.State.COMBAT;g.spawn_group()
	var template:Dictionary=g.enemies[0].duplicate(true);g.enemies.clear()
	for i in 2:
		var enemy=template.duplicate(true);enemy.uid=500+i;enemy.slot=i;enemy.x=110+150*i;enemy.y=340
		enemy.hp=1e100;enemy.max_hp=1e100;enemy.size=i+1;enemy.equipment=[{"name":"laser_mon"},{"name":"cannon_mon"}];enemy.cooldowns=[0.0,0.0]
		enemy.armourType=i%2+1;enemy.shieldType=i%2+1;enemy.max_shield=1000.0;enemy.shield=1000.0;enemy.shieldRecovery=0.05
		g.enemies.append(enemy)
	scene.refresh_structure();scene.refresh_tab_visibility();scene.select_system(0)
	check(g.admit_native_compiled_execution("native_low_contract"),"low-load sole native owner admitted")
	g.native_execution_auto=true
	check(scene.attach_native_display(),"existing numeric view attached")
	for frame in 165:scene._process(1.0/60.0)
	g.paused=true;scene._process(0.0)
	# Ensure both ordinary and critical label colors are observable at live hulls.
	for enemy in g.enemies:
		scene.queue_damage_number({"player":false,"uid":enemy.uid,"type":1,"amount":12345,"critical":int(enemy.uid)%2==0})
	scene._process(0.0)
	await picture(scene)
	var retained=scene.retained_contacts
	check(retained.records.size()==2,"one retained record for each native actor")
	check(retained.get_child(retained.get_child_count()-1)==retained.foreground,"foreground is after all enemy records")
	check(not retained.frame.is_empty() and retained.frame.flights is Object,"foreground retains native prepared flight frame")
	check(not g.projectiles.is_empty(),"actual native flights remain visible")
	check(scene.floats.size()>0,"damage numbers use same foreground transaction")
	var hull_builds:Dictionary={};var body_builds:Dictionary={}
	for enemy in g.enemies:
		var record=retained.records[int(enemy.uid)]
		check(record.root.position.is_equal_approx(scene.simulation_geometry_view.row(enemy).position),"record transform consumes canonical numeric position")
		check(record.supported and record.root.visible,"ordinary native hull uses retained parts")
		hull_builds[enemy.uid]=record.hull.builds;body_builds[enemy.uid]=record.deck.pieces.deck_physical_body.builds
	await picture(scene)
	for enemy in g.enemies:
		var record=retained.records[int(enemy.uid)]
		check(record.hull.builds==hull_builds[enemy.uid] and record.deck.pieces.deck_physical_body.builds==body_builds[enemy.uid],"unchanged hull/body commands survive parent redraw")
	root.get_texture().get_image().save_png("res://.runtime/retained-native-on.png")
	scene.retained_contacts_enabled=false;await picture(scene)
	check(not retained.visible,"direct painter switch hides retained child commands")
	root.get_texture().get_image().save_png("res://.runtime/retained-native-direct.png")
	scene.retained_contacts_enabled=true;await picture(scene)
	check(retained.visible,"retained owner resumes without second renderer")
	var view=scene.simulation_geometry_view
	var enemy:Dictionary=g.enemies[0]
	var record=retained.records[int(enemy.uid)]
	var old_hull=record.hull.builds
	var old_protection=record.protection.builds;var old_meter=record.shield.builds
	# Display-only fixtures mutate published scalar state while paused, never tick it.
	enemy.shield=500.0
	await picture(scene)
	check(record.shield.builds>old_meter and record.protection.builds>old_protection,"shield fraction invalidates protection and meter")
	check(record.hull.builds==old_hull,"shield change does not rebuild hull")
	var original_scale=scene.battle_layer.scale
	scene.battle_layer.scale=original_scale*0.8
	await picture(scene)
	check(is_equal_approx(record.screen_scale,scene.enemy_recognition_screen_scale()),"live display scale refreshes pixel-width contract")
	check(record.root.position.is_equal_approx(view.row(enemy).position),"scale reads existing numeric position without solving another geometry")
	scene.battle_layer.scale=original_scale;await picture(scene)
	# Cold transfer keeps this test out of native identity/settlement mutation.
	check(g.native_before_configuration_change(),"whole cold transfer for legacy display boundaries")
	check(scene.battle_slice_runtime==null and scene.simulation_geometry_view==null,"native geometry closes at transfer")
	await picture(scene)
	check(retained.records[int(enemy.uid)].source_id==0,"same retained actor switches to main canonical getters")
	var old_root=retained.records[int(enemy.uid)].root
	var replacement=enemy.duplicate(true);replacement.hp=1e100
	g.enemies[0]=replacement
	await picture(scene)
	check(is_same(retained.records[int(replacement.uid)].entity,replacement) and not is_instance_valid(old_root),"same uid new identity retires old command owner")
	record=retained.records[int(replacement.uid)]
	replacement.hp=0.0;await picture(scene)
	check(not record.root.visible,"death hides all retained parts at display boundary")
	g.enemies.erase(replacement);await picture(scene)
	check(not retained.records.has(int(replacement.uid)),"departed death drops retained record")
	var count_before=g.enemies.size()
	g.enemies.clear();await picture(scene)
	check(count_before>0 and retained.records.is_empty(),"wave membership clear removes old hull owners")
	scene.reset_battle_transients_for_scene()
	check(retained.frame.is_empty(),"explicit reset drops held prior flight frame")
	await picture(scene)
	check(retained.records.is_empty(),"explicit scene reset keeps no retained enemies")
	# Reset is allowed to restage an empty foreground, with no prior flight lease.
	check(retained.frame.get("shots",[])==g.projectiles,"reset restages only legitimate in-flight Game shots")
	g.begin_retreat();scene.queue_free();await process_frame;await process_frame
	print("Retained native display: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
