extends SceneTree
class GeometryAudit extends "res://scripts/simulation_geometry_authority.gd":
	var aim_calls:=0
	func enemy_weapon_angle(enemy:Dictionary,index:int,render_position:=Vector2.INF)->float:
		aim_calls+=1
		return super.enemy_weapon_angle(enemy,index,render_position)
class UI extends "res://scripts/battlefield.gd":
	var enemy_aim_calls:=0
	func enemy_weapon_angle(enemy:Dictionary,index:int,render_position:=Vector2.INF)->float:
		enemy_aim_calls+=1
		return super.enemy_weapon_angle(enemy,index,render_position)
	func show_qa_tools()->void:pass
	func show_chrono_login_report()->void:pass
	func create_battle_game(_persist:bool)->BattleGame:
		var g=preload("res://scripts/presented_battle_game.gd").new(db,false)
		db=g.db;g.native_execution_auto=false
		g.enemy_launch_provider=_prototype_enemy_launch_pose
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
func audit_ports(scene,enemy:Dictionary)->void:
	var retained=scene.retained_contacts
	var record=retained.records[int(enemy.uid)]
	var width:float=scene.enemy_render_width(enemy)
	var angle:float=scene.enemy_render_angle(enemy)
	var pixel_scale:float=scene.enemy_recognition_screen_scale()
	check(record.supported and record.root.get_children().all(func(node):return node.kind!="weapon_group"),"ordinary port owner has no rotating weapon nodes")
	for component in scene.enemy_weapon_components(enemy):
		var canonical:Dictionary=scene.enemy_component_pose(enemy,component)
		var matches:Array=record.ports.filter(func(port):return port.slot==int(component.owner_slot))
		check(matches.size()==1,"one immutable port descriptor for actual weapon slot")
		if matches.is_empty():continue
		var port:Dictionary=matches[0]
		var radius:float=retained.port_radius(port,width,pixel_scale)
		var local:Vector2=Vector2(canonical.muzzle).rotated(-PI-angle)-Vector2(port.position)*width
		var texture=retained.OMNI_PHYSICAL if port.physical else retained.OMNI_ENERGY
		var pixels:Image=texture.get_image()
		var sample:Vector2=(Vector2.ONE*0.5+local/(radius*2))*Vector2(pixels.get_size())
		check(Rect2(Vector2.ZERO,Vector2(pixels.get_size())).has_point(sample) and pixels.get_pixelv(Vector2i(sample)).a>0.95,"actual authoritative muzzle is on an opaque emitter pixel")
		check(Vector2(canonical.port)==Vector2.ZERO and local.length()<0.0001,"logical muzzle equals the static visible emitter center")

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
		enemy.hp=1e100;enemy.max_hp=1e100;enemy.size=6;enemy.equipment=[{"name":"laser_mon"},{"name":"cannon-mon"},{"name":"missile-mon"},{"name":"longLaser-mon"}];enemy.cooldowns=[0.0,0.0,0.0,0.0]
		enemy.armourType=i%2+1;enemy.shieldType=i%2+1;enemy.max_shield=1000.0;enemy.shield=1000.0;enemy.shieldRecovery=0.05
		g.enemies.append(enemy)
	g.player.armour=1e12
	scene.refresh_structure();scene.refresh_tab_visibility();scene.select_system(0)
	check(g.admit_native_compiled_execution("native_low_contract"),"low-load sole native owner admitted")
	g.native_execution_auto=true
	check(scene.attach_native_display(),"existing numeric view attached")
	var hostile_keys:Dictionary={}
	var watch_fire=func(kind:String,info:Dictionary):
		if kind!="fire" or not info.shot.hostile:return
		var shot:Dictionary=info.shot
		hostile_keys[str(shot.key)]=true
		var geometry=scene.battle_slice_runtime.geometry
		var position:Vector2=geometry.enemy_render_position(shot.source)
		var expected:Vector2=geometry.battle_logical_point(position+geometry.enemy_port_offset(shot.source,int(shot.mount),position))
		check(Vector2(shot.launch_point).is_equal_approx(expected),"native birth uses fixed port for "+str(shot.key))
	g.event.connect(watch_fire)
	for frame in 165:scene._process(1.0/60.0)
	for key in ["laser_mon","cannon-mon","missile-mon","longLaser-mon"]:check(hostile_keys.has(key),"native fixture launches "+key)
	var audit=GeometryAudit.new();audit.prepare(scene,g)
	for e in g.enemies:audit.enemy_pose(e)
	audit.fx_time+=10.0
	for e in g.enemies:
		var row:Dictionary=audit.display_enemy(e)
		for component in audit.enemy_weapon_components(e):
			var old:Vector2=audit.execution_enemy_port_offset(e,int(component.owner_slot),Vector2(row.position))
			audit.player_anchor.x+=70.0
			check(is_same(row,audit.display_enemy(e)),"ordinary row does not invalidate on player aim change")
			check(audit.execution_enemy_port_offset(e,int(component.owner_slot),Vector2(row.position)).is_equal_approx(old),"moving player aim never moves ordinary logical port")
			audit.player_anchor.x-=70.0
		check(is_same(row,audit.display_enemy(e)),"settled ordinary component publication is reused")
	check(audit.aim_calls==0,"ordinary numeric geometry never calls enemy_weapon_angle")
	audit.game=null;audit.battle_read_model.host=null;audit.fleet_pose=null

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
	for enemy in g.enemies:audit_ports(scene,enemy)
	var port_builds:Dictionary={};var port_transforms:Dictionary={}
	for enemy in g.enemies:
		var record=retained.records[int(enemy.uid)]
		port_builds[enemy.uid]=record.ports_over.builds
		port_transforms[enemy.uid]=record.ports_over.transform
	var rng_before:int=g.rng.state
	var kernel_before:Dictionary=g.native_execution.kernel.metrics().duplicate(true)
	scene.fx_time+=0.1
	await picture(scene)
	for enemy in g.enemies:
		var record=retained.records[int(enemy.uid)]
		check(record.ports_over.builds==port_builds[enemy.uid] and record.ports_over.transform==port_transforms[enemy.uid],"time and parent redraw do not rebuild or rotate ordinary ports")
	check(g.rng.state==rng_before and g.native_execution.kernel.metrics()==kernel_before,"port rendering does not advance kernel or consume gameplay RNG")
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
	var old_ports=record.ports_over.builds
	var old_protection=record.protection.builds;var old_meter=record.shield.builds
	# Display-only fixtures mutate published scalar state while paused, never tick it.
	enemy.shield=500.0
	await picture(scene)
	check(record.shield.builds>old_meter and record.protection.builds>old_protection,"shield fraction invalidates protection and meter")
	check(record.hull.builds==old_hull,"shield change does not rebuild hull")
	check(record.ports_over.builds==old_ports,"shield changes do not rebuild static ports")
	var original_scale=scene.battle_layer.scale
	scene.battle_layer.scale=original_scale*0.8
	await picture(scene)
	check(is_equal_approx(record.screen_scale,scene.enemy_recognition_screen_scale()),"live display scale refreshes pixel-width contract")
	check(record.root.position.is_equal_approx(view.row(enemy).position),"scale reads existing numeric position without solving another geometry")
	scene.battle_layer.scale=original_scale;await picture(scene)
	g.event.disconnect(watch_fire)
	# Cold transfer keeps this test out of native identity/settlement mutation.
	check(g.native_before_configuration_change(),"whole cold transfer for legacy display boundaries")
	check(scene.battle_slice_runtime==null and scene.simulation_geometry_view==null,"native geometry closes at transfer")
	for e in g.enemies:
		for slot in e.equipment.size():
			var weapon:Dictionary=g.db.enemy_weapon(str(e.equipment[slot].name))
			g.fire(e,g.player,weapon,1.0,true,str(e.equipment[slot].name),g.enemy_weapon_offset(e,slot),0.0,slot)
			var shot:Dictionary=g.projectiles.back()
			var expected:Vector2=scene.battle_logical_point(scene.enemy_render_position(e)+scene.enemy_port_offset(e,slot))
			check(shot.get("fixed_enemy_port",false) and Vector2(shot.launch_point).is_equal_approx(expected),"legacy handoff launch uses same fixed origin")
			check(g.projectile_target_point(shot).is_equal_approx(g.target_point(g.player)),"legacy hostile aims at rendered player authority")
	check(scene.enemy_aim_calls==0,"direct painter and legacy launch never rotate ordinary turrets")
	var beams:Array=g.projectiles.filter(func(shot):return shot.hostile and shot.get("beam",false) and not shot.dead)
	check(not beams.is_empty(),"hostile continuous beams survive the actual handoff")
	for beam in beams:
		check(beam.get("fixed_enemy_port",false),"native beam retains fixed-port semantics after handoff")
		check(g.advance_long_laser(beam,1.0/60.0),"transferred live beam remains valid")
		var expected:Vector2=scene.battle_logical_point(scene.enemy_render_position(beam.source)+scene.enemy_port_offset(beam.source,int(beam.mount)))
		check(g.projectile_position(beam).is_equal_approx(expected),"legacy continuous beam follows same fixed outlet")
		var encounter_row:Dictionary=g.db.levels[g.stage-1].groups[g.group_index-1]
		var group_row:Dictionary=g.db.groups[str(int(encounter_row.id))]
		var tier_before:Variant=group_row.get("combatTier")
		var aim_calls_before:int=scene.enemy_aim_calls
		group_row.combatTier="boss"
		check(g.advance_long_laser(beam,1.0/60.0),"live source beam remains valid while encounter tier changes")
		check(g.projectile_position(beam).is_equal_approx(expected) and scene.visual_muzzle(beam).is_equal_approx(expected),"committed fixed beam keeps logical and visual outlet after tier change")
		check(scene.enemy_aim_calls==aim_calls_before,"committed fixed beam never re-enters ordinary rotation after tier change")
		var numeric=GeometryAudit.new();numeric.prepare(scene,g)
		check(numeric.enemy_launch_pose(beam.source,beam).position.is_equal_approx(numeric.visual_muzzle(beam)),"numeric provider and visual publication retain birth semantics")
		check(numeric.aim_calls==0,"numeric fixed beam bypasses current Boss angle rule")
		numeric.game=null;numeric.battle_read_model.host=null;numeric.fleet_pose=null
		if tier_before==null:group_row.erase("combatTier")
		else:group_row.combatTier=tier_before

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
	# Six authored hull sizes, only in-memory presentation fixtures after handoff.
	for i in 6:
		var e=template.duplicate(true);e.uid=900+i;e.slot=i;e.size=i+1
		e.x=110.0+175.0*(i%3);e.y=180.0+220.0*(i/3);e.explicit_formation=true
		e.hp=1000.0;e.max_hp=1000.0;e.armourType=0;e.shield=0.0;e.max_shield=0.0
		e.equipment=[{"name":"missile-mon"},{"name":"longLaser-mon"}];e.cooldowns=[0.0,0.0]
		g.enemies.append(e)
	scene.enemy_poses.clear();scene.battle_read_model.invalidate_membership()
	scene.fx_time+=5.0
	await picture(scene)
	# Pose creation starts entry; reach residence without a combat tick.
	scene.fx_time+=5.0
	await picture(scene)
	for e in g.enemies:audit_ports(scene,e)
	root.get_texture().get_image().save_png("res://.runtime/ordinary-six-ports.png")
	var encounter:Dictionary=g.db.levels[g.stage-1].groups[g.group_index-1]
	var group:Dictionary=g.db.groups[str(int(encounter.id))]
	var old_tier:Variant=group.get("combatTier")
	group.combatTier="boss";scene.encounter_presentation.sync(g,0.0)
	await picture(scene)
	for e in g.enemies:
		var boss_record=retained.records[int(e.uid)]
		check(not boss_record.supported and boss_record.fallback.visible and not boss_record.ports_over.visible and not boss_record.ports_under.visible,"boss and escorts retain original painter and aimed weapons")
	check(scene.enemy_aim_calls>0,"Boss fallback still executes original turret aim")
	root.get_texture().get_image().save_png("res://.runtime/boss-original-painter.png")
	if old_tier==null:group.erase("combatTier")
	else:group.combatTier=old_tier
	g.begin_retreat();scene.queue_free();await process_frame;await process_frame
	print("Retained native display: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
