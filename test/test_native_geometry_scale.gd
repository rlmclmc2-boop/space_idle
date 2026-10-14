extends SceneTree
class UI extends "res://scripts/battlefield.gd":
	func show_qa_tools()->void:pass
	func show_chrono_login_report()->void:pass
	func create_battle_game(_persist:bool)->BattleGame:
		var g=preload("res://scripts/presented_battle_game.gd").new(db,false)
		g.stat_cache_enabled=true;g.invalidate_stat_cache()
		db=g.db;g.native_execution_auto=false
		g.launch_provider=_prototype_launch_pose;g.drone_launch_provider=_prototype_drone_launch_pose
		g.target_provider=_prototype_target_point;g.rail_geometry_provider=_rail_geometry;g.rail_target_point_provider=entity_render_position
		g.enable_compiled_combat_rules()
		return g
var checks:=0
var failures:=0
var evidence:Array=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize()->void:call_deferred("run")
func contract(scene)->Dictionary:
	var g=scene.game;var runtime=scene.battle_slice_runtime
	return {"kernel":g.native_execution.kernel.export_handoff().duplicate(true),"rng":g.rng.state,"production":g.production_time(),"motion":g.motion_clock,"fx":runtime.geometry.fx_time,"demo":runtime.geometry.demo_time,"steps":runtime.logical_steps,"remainder":runtime.remainder,"since_hit":g.since_hit,"debts":g.enhancement_deferred.duplicate(true)}
func resize_zero(scene,size:Vector2i,label:String,same_bucket:bool=false)->void:
	var runtime=scene.battle_slice_runtime;var geometry=runtime.geometry
	var before=contract(scene);var old_scale=geometry.screen_scale
	var enemy:Dictionary=scene.game.enemies.back();var old_row:Dictionary=runtime.view.row(enemy).duplicate()
	DisplayServer.window_set_size(size)
	await process_frame;await RenderingServer.frame_post_draw
	scene._process(0.0)
	check(contract(scene)==before,label+": zero-step preserves time, CD, birth values, queues, damage and RNG")
	check(not is_equal_approx(old_scale,geometry.screen_scale) and is_equal_approx(geometry.screen_scale,scene.enemy_recognition_screen_scale()),label+": actual viewport scale synchronized")
	for actor in scene.game.enemies:
		var at:Vector2=geometry.enemy_render_position(actor)
		for slot in actor.equipment.size():
			check(geometry.execution_enemy_port_offset(actor,slot,at)==geometry.enemy_port_offset(actor,slot,at),label+": execution-only muzzle equals complete display pose")
	var row:Dictionary=runtime.view.row(enemy)
	check(row.width==geometry.enemy_render_width(enemy) and row.components==geometry.display_enemy(enemy).components,label+": authority width and components published")
	check(row.recognition==geometry.enemy_recognition_geometry(enemy,row.width),label+": display protection outline matches authority")
	check(row.recognition!=old_row.recognition,label+": new outline packet delivered")
	if same_bucket:check(row.recognition_id==old_row.recognition_id,label+": same ID replaces packet")
	# Retained Canvas parts consume the publication on the actual draw boundary.
	await process_frame;await RenderingServer.frame_post_draw
	var record=scene.retained_contacts.records.get(int(enemy.uid))
	check(record!=null and record.packet==row.recognition and is_equal_approx(record.hull.scale.x,row.width),label+": retained body and outline refreshed")
	for shot in scene.game.projectiles:
		if bool(shot.get("beam",false)) and scene.game.long_laser_valid(shot):
			check(runtime.muzzle(shot)==geometry.visual_muzzle(shot),label+": beam muzzle uses same publication")
			if not bool(shot.hostile) and int(shot.get("mount",-1))>=0:
				var drawn:Vector2=scene.battle_logical_point(scene.ship_view.screen_muzzle_for_slot(int(shot.mount)))
				check(drawn.distance_to(runtime.muzzle(shot))<0.05,label+": actual 3D beam socket matches published muzzle")
	var builds=geometry.display_row_builds;var revision=geometry.battle_read_model.shape_revision
	check(not runtime.sync_screen_scale(geometry.screen_scale) and geometry.display_row_builds==builds and geometry.battle_read_model.shape_revision==revision,label+": unchanged scale does not rebuild")
	scene.battle_layer.queue_redraw();scene.pulse_layer.queue_redraw();scene.battle_hud_layer.queue_redraw()
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/native-scale-"+label+".png")
	evidence.append({"label":label,"window":str(DisplayServer.window_get_size()),"scale":geometry.screen_scale,"width":row.width,"shape":row.recognition_id,"steps":runtime.logical_steps,"paused":scene.game.paused})
func rail_charge_contract(scene)->void:
	var g=scene.game;var owner=g.native_execution;var kernel=owner.kernel
	var fires=[0];var seen=[false,false];var enemy_seen=false;var upgraded=false
	var watcher=func(kind:String,info:Dictionary):
		if kind=="fire" and not bool(info.shot.hostile) and int(info.shot.get("mount",-1))==3:fires[0]+=1
	g.event.connect(watcher)
	var enemy:Dictionary=g.enemies.back();var component
	for candidate in scene.enemy_weapon_components(enemy):
		if str(candidate.profile.get("visual_class",""))=="gun" and candidate.slots.has(1):component=candidate;break
	check(component!=null,"enemy rail component uses normal presentation")
	var interval:float=maxf(float(g.player_weapon_row(g.combat_entry(3)).cd),float(g.db.enemy_weapon(enemy.equipment[1].name).cd))
	for i in ceili(interval*3.0*60.0)+60:
		scene._process(1.0/60.0)
		var progress:float=scene.player_railgun_charge(3)
		if fires[0]<2 and progress>0.0:seen[fires[0]]=true
		if component!=null and scene.railgun_component_charge(component,enemy)>0.0:enemy_seen=true
		if progress>0.0 and not upgraded:
			var deadline:float=kernel.cooldown_remaining(3);var clock:float=kernel.metrics().clock;var rng=g.rng.state
			check(g.upgrade_slot("weapons",3,1) and g.native_execution==owner,"ordinary numeric rail upgrade retains sole kernel")
			check(kernel.cooldown_remaining(3)==deadline and kernel.metrics().clock==clock and g.rng.state==rng,"mid-cycle numeric upgrade preserves cooldown deadline, clock and RNG")
			check(scene.player_railgun_charge(3)>0.0,"charge remains visible after mid-cycle upgrade")
			upgraded=true
		if fires[0]>=2 and enemy_seen:break
	check(fires[0]>=2 and seen[0] and seen[1] and upgraded,"player rail charge rises in two actual firing cycles")
	check(enemy_seen,"enemy rail charge reads its native root deadline")
	g.event.disconnect(watcher)
func fixed_layout_contract(geometry,g)->void:
	var enemy:Dictionary=g.enemies.back();var pose:Dictionary=geometry.enemy_pose(enemy)
	var before:Vector2=geometry._source_enemy_render_position(enemy)
	var old_x:float=enemy.x;enemy.x+=1.0
	check(geometry._source_enemy_render_position(enemy).x!=before.x,"fixed layout follows live logical movement without a stale position key")
	enemy.x=old_x
	var old_enemies:Array[Dictionary]=g.enemies
	for size_class in range(1,7):
		for explicit in [false,true]:
			var sample:Dictionary=enemy.duplicate(true);sample.uid=9000+size_class;sample.slot=100+size_class
			sample.size=size_class;sample.explicit_formation=explicit;sample.formation_count=4
			var sample_enemies:Array[Dictionary]=[sample]
			g.enemies=sample_enemies
			var sample_pose:Dictionary=geometry.enemy_pose(sample)
			var low:float=geometry._source_enemy_render_width_at_y(sample,90.0)
			var high:float=geometry._source_enemy_render_width_at_y(sample,900.0)
			check(low>0.0 and low==high,"one model width across depth, size %d explicit %s"%[size_class,explicit])
			check(sample_pose.fixed_layout.frontline>=sample_pose.fixed_layout.top,"fixed bounds are ordered for every model size")
			geometry.enemy_poses.erase(int(sample.slot))
	g.enemies=old_enemies

func steady_position_publication(geometry,g)->void:
	var enemy:Dictionary=g.enemies.back();var pose:Dictionary=geometry.enemy_pose(enemy)
	pose.born=geometry.fx_time-2.0
	for key in ["unchanged","target","rotation","phase","variance","logical_position","entry_x","duration","born","logical_enemy"]:
		geometry.enemy_entry_batch_active=true;geometry.enemy_provider_query_active=true
		geometry._source_enemy_render_position(enemy)
		geometry.enemy_provider_query_active=false;geometry.after_tick()
		if key=="logical_enemy":enemy.x+=1.0
		elif key!="unchanged":
			pose[key]+=Vector2(1,2) if pose[key] is Vector2 else 0.03
		var cached:Vector2=geometry._source_enemy_render_position(enemy)
		pose.erase("steady_position_key");pose.erase("steady_position_time")
		var original:Vector2=geometry._source_enemy_render_position(enemy)
		check(cached==original,"post-step exact position and same-clock mutation: "+key)

class GeometrySink extends RefCounted:
	var hulls:Array=[]
	var centers:=PackedVector2Array()
	var points:=PackedVector2Array()
	var muzzles:=PackedVector2Array()
	var screen_muzzles:=PackedVector2Array()
	var player:=Vector2.ZERO
	var submissions:=0
	func input_ballistic_geometry(h:Array,p:PackedVector2Array,m:PackedVector2Array)->void:
		submissions+=1
		if not h.is_empty():hulls=h.duplicate(true);centers=p.duplicate()
		if not m.is_empty():screen_muzzles=m.duplicate()
	func input_geometry(p:PackedVector2Array,m:PackedVector2Array)->void:
		if not p.is_empty():points=p.duplicate()
		if not m.is_empty():muzzles=m.duplicate()
	func input_player_point(p:Vector2)->void:player=p

func incremental_geometry_contract(scene)->void:
	var geometry=scene.battle_slice_runtime.geometry;var game=scene.game
	var session=game.native_execution;var actual_kernel=session.kernel
	var sink=GeometrySink.new();session.kernel=sink;session.geometry_muzzles=PackedVector2Array();session.geometry_player=Vector2.INF
	for phase in 4:
		if phase==2:game.enemies.back().x+=3.0
		if phase==3:game.enemies.back().x-=3.0
		var before:int=sink.submissions
		session.prepare_geometry(geometry,game)
		if phase==1:check(sink.submissions==before,"unchanged publication makes no native geometry submission")
		var expected_points:=PackedVector2Array();var expected_hulls:Array=[];var expected_centers:=PackedVector2Array()
		for actor in session.actor_rows:
			var shape:Dictionary=geometry.battle_read_model.ballistic_shape(actor)
			expected_hulls.append(shape.hull);expected_centers.append(shape.center);expected_points.append(geometry.battle_logical_point(shape.center))
		var expected_muzzles:=PackedVector2Array();var aim:Vector2=geometry.target_point(game.player)
		for weapon in session.weapons:
			if bool(weapon.hostile):
				var actor:Dictionary=session.actor_rows[int(weapon.source)];var point:Vector2=geometry.enemy_render_position(actor)
				expected_muzzles.append(geometry.battle_logical_point(point+geometry.execution_enemy_port_offset(actor,int(weapon.slot),point)))
			elif weapon.entry.has("drone_id"):expected_muzzles.append(geometry.drone_launch_pose(str(weapon.entry.drone_id),aim,0).position)
			else:expected_muzzles.append(geometry.launch_pose(int(weapon.slot),aim,0).position)
		check(sink.hulls==expected_hulls and sink.centers==expected_centers and sink.points==expected_points,"incremental target publication equals full reference phase "+str(phase))
		check(sink.muzzles==expected_muzzles and sink.player==aim,"incremental muzzle publication equals full reference phase "+str(phase))
	session.kernel=actual_kernel;session.geometry_muzzles=PackedVector2Array();session.prepare_geometry(geometry,game)

func residence_contract(scene)->void:
	var runtime=scene.battle_slice_runtime;var geometry=runtime.geometry;var g=scene.game
	var enemy:Dictionary=g.enemies.back();var pose:Dictionary=geometry.enemy_pose(enemy)
	var row:Dictionary=geometry.display_enemy(enemy)
	var shape:Dictionary=geometry.battle_read_model.ballistic_shape(enemy)
	var key:Array=pose.residence_key
	var body:Transform3D=geometry.fleet_pose.ship_transform
	var builds:int=geometry.display_row_builds;var applied:int=runtime.view.applied_rows
	for i in 30:scene._process(1.0/60.0)
	check(geometry.fleet_pose.ship_transform==body,"stationary player root unchanged across logical steps")
	check(is_same(pose.residence_key,key),"stationary position solver exits without replacing its owner publication")
	check(is_same(geometry.display_enemy(enemy),row) and geometry.display_row_builds==builds,"stationary enemy rows not rebuilt across steps")
	check(runtime.view.applied_rows==applied,"stationary display rows not recopied across frames")
	check(is_same(geometry.battle_read_model.ballistic_shape(enemy),shape),"stationary collision hull reused across steps")
	incremental_geometry_contract(scene)
	var clock:float=geometry.fx_time;var born:float=pose.born
	pose.born=clock
	var entry:Vector2=geometry.enemy_render_position(enemy)
	geometry.fx_time=clock+float(pose.duration)
	var settled:Vector2=geometry.enemy_render_position(enemy)
	geometry.fx_time+=0.5
	check(entry!=settled and geometry.enemy_render_position(enemy)==settled,"entry reaches exact fixed endpoint without hover")
	pose.born=born;geometry.fx_time=clock
	var old_x:float=enemy.x;enemy.x+=3.0
	var moved:Dictionary=geometry.display_enemy(enemy)
	check(moved.position.x!=row.position.x and not is_same(geometry.battle_read_model.ballistic_shape(enemy),shape),"logical movement invalidates display and collision together")
	enemy.x=old_x;geometry.battle_read_model.invalidate_membership();runtime.snapshot()
	# Descriptor-only fleet fixture checks fixed drone bodies and moving carriers.
	var fleet=preload("res://scripts/logical_fleet_pose.gd").new();fleet.prepare(scene.ship_view)
	var entries:Array=[]
	for i in 8:entries.append({"key":"laser"})
	var bag={"generation":1,"equipped":["fixed-drone"],"drones":{"fixed-drone":{"weapon":"laser"}}}
	fleet.configure("Heavy_Battleship",entries,8,bag)
	fleet.pose_base(Vector2(286,800),200,0,0,false,1.0/60.0)
	var fixture_body:Transform3D=fleet.ship_transform
	var drone:Transform3D=fleet.drones[0].transform;var carrier:Transform3D=fleet.carriers[0].transform
	var muzzle:Vector2=fleet.screen_muzzle_for_drone("fixed-drone",0)
	fleet.pose_base(Vector2(286,800),200,0,1,false,1.0/60.0)
	check(fleet.drones[0].transform==drone and fleet.screen_muzzle_for_drone("fixed-drone",0)==muzzle,"fixed drone body and muzzle do not bob")
	check(fleet.carriers[0].transform!=carrier,"carrier orbit remains dynamic")
	fleet.pose_base(Vector2(286,800),220,0,1,false,0)
	check(fleet.ship_transform!=fixture_body,"fleet scale change rebuilds base")

func run()->void:
	var scene=load("res://main.tscn").instantiate();scene.set_script(UI)
	scene.automation_args=["--capture"];scene.music_on=false
	root.add_child(scene);current_scene=scene;scene.set_process(false);scene.automation_args=[]
	var g=scene.game;g.save_enabled=false;g.speed=1;g.rng.seed=1975
	g.profile.onboarding.completed=true;scene.beginner_guide.hide()
	g.profile.unlocked=BattleGame.EQUIPMENT.duplicate();g.pending_unlocks.clear()
	g.profile.selectedShip="Heavy_Battleship";g.profile.resources={"1":1e20,"2":1e20}
	g.profile.loadout={"weapons":[{"key":"laser","level":1},{"key":"missile","level":1},{"key":"longLaser","level":1},{"key":"cannon","level":1}],"defence":[{"key":"armour","level":1},{"key":"shield","level":1}]}
	g.invalidate_stat_cache();g.reset_player();g.state=BattleGame.State.COMBAT;g.spawn_group()
	var template:Dictionary=g.enemies[0].duplicate(true);g.enemies.clear()
	for i in 2:
		var enemy=template.duplicate(true);enemy.uid=500+i;enemy.slot=i;enemy.x=160+170*i;enemy.y=340
		enemy.hp=1e7;enemy.max_hp=1e7;enemy.size=4;enemy.explicit_formation=true;enemy.formation_count=4
		enemy.equipment=[{"name":"longLaser-mon" if i==0 else "laser_mon"},{"name":"cannon-mon"}];enemy.cooldowns=[0.0,0.0]
		enemy.armourType=i%2+1;enemy.shieldType=i%2+1;enemy.max_shield=1000.0;enemy.shield=1000.0;enemy.shieldRecovery=0.05
		g.enemies.append(enemy)
	scene.refresh_structure();scene.refresh_tab_visibility();scene.select_system(0)
	check(g.admit_native_compiled_execution("native_low_contract"),"sole native kernel admitted")
	g.native_execution_auto=true
	check(scene.attach_native_display(),"sole native geometry owner attached")
	var missile_origin_match=[true,0]
	var muzzle_watcher=func(kind:String,info:Dictionary):
		if kind=="fire" and not bool(info.shot.hostile) and str(info.shot.key)=="missile":
			var published:Vector2=Vector2(info.x,info.y)
			missile_origin_match[0]=missile_origin_match[0] and published.distance_to(Vector2(info.shot.launch_point))<0.001 and published.distance_to(scene.battle_slice_runtime.geometry.visual_muzzle(info.shot))<0.001
			missile_origin_match[1]+=1
	g.event.connect(muzzle_watcher)
	for i in 120:scene._process(1.0/60.0)
	for i in 120:
		if g.native_execution.kernel.metrics().ejection_queue>0:break
		scene._process(1.0/60.0)
	check(g.projectiles.any(func(shot):return bool(shot.get("beam",false))) and g.native_execution.kernel.metrics().ejection_queue>0,"fixture includes live beam and pending immutable missile birth")
	var runtime=scene.battle_slice_runtime;var geometry=runtime.geometry
	var width_before:float=runtime.view.row(g.enemies.back()).width
	await resize_zero(scene,Vector2i(800,515),"combat-small")
	check(runtime.view.row(g.enemies.back()).width<width_before,"compact explicit formation updates actual hull width")
	await resize_zero(scene,Vector2i(1560,1004),"combat-large")
	await resize_zero(scene,Vector2i(1561,1005),"same-bucket",true)
	g.paused=true
	await resize_zero(scene,Vector2i(1000,644),"paused-small")
	await resize_zero(scene,Vector2i(1373,883),"paused-large")
	# The live config dictionary may change without a notification; even a
	# paused zero-step boundary must publish one coherent fixed model width.
	var config_key:="enemyVisualScaleSize4";var old_scale_config=g.db.config.get(config_key,1.0)
	var config_before=contract(scene);var old_model_width:float=runtime.view.row(g.enemies.back()).width
	g.db.config[config_key]=float(old_scale_config)*0.8
	scene._process(0.0)
	check(contract(scene)==config_before and runtime.view.row(g.enemies.back()).width<old_model_width,"paused unnotified config edit updates model without advancing gameplay")
	check(runtime.view.row(g.enemies.back()).width==geometry.enemy_render_width(g.enemies.back()),"config edit keeps view and collision authority at one width")
	g.db.config[config_key]=old_scale_config;scene._process(0.0)
	var steps:int=runtime.logical_steps;g.paused=false;scene._process(1.0/60.0)
	check(runtime.logical_steps==steps+1,"resume advances exactly one next logical step")
	residence_contract(scene)
	await rail_charge_contract(scene)
	var dead:Dictionary=g.enemies[0];var uid:int=int(dead.uid)
	var hostile_beam:Dictionary={}
	for shot in g.projectiles:
		if bool(shot.get("beam",false)) and bool(shot.hostile) and is_same(shot.get("source",{}),dead):hostile_beam=shot;break
	check(not hostile_beam.is_empty() and g.long_laser_valid(hostile_beam),"live hostile beam participates in display before death")
	check(g.native_execution.kernel.hit_handle(g.native_execution.kernel.actor_handle(uid),1e9,1),"real native lethal settlement accepted")
	g.native_execution.consume_feedback(g);scene._process(0.0)
	check(not hostile_beam.is_empty() and not g.long_laser_valid(hostile_beam),"dead source beam is invalid for actual foreground display")
	check(dead.hp==0.0 and geometry.boundary_dead_geometry.has(uid),"death captured original frozen geometry")
	var frozen_position:Vector2=runtime.view.row(dead).position;var original_pose:Dictionary=geometry.boundary_dead_geometry[uid].pose
	var born:float=original_pose.born;var phase:float=original_pose.phase
	var shield_history=runtime.view.pose(dead).duplicate()
	for slot in dead.equipment.size():
		check(geometry.execution_enemy_port_offset(dead,slot,frozen_position)==geometry.enemy_port_offset(dead,slot,frozen_position),"dead muzzle keeps frozen publication")
	check(scene.floats.any(func(entry):return is_same(entry.get("target_entity",{}),dead)) or scene.damage_pending.any(func(entry):return is_same(entry.get("target_entity",{}),dead)),"actual death label retains departed entity")
	# Remove only the public display membership; the kernel retains its actor table.
	g.enemies=g.enemies.filter(func(enemy):return not is_same(enemy,dead))
	await resize_zero(scene,Vector2i(900,579),"death-small")
	check(runtime.view.row(dead).position==frozen_position and is_same(geometry.boundary_dead_geometry[uid].pose,original_pose) and original_pose.born==born and original_pose.phase==phase,"departed entity retains death position, original pose and phase")
	for key in ["recognition_shield_clock","recognition_shield_amount","recognition_recovering"]:
		check(runtime.view.pose(dead).get(key)==shield_history.get(key),"resize preserves shield display history: "+key)
	await resize_zero(scene,Vector2i(1373,883),"death-large")
	for i in 180:
		if not runtime.view.rows.has(uid):break
		scene._process(1.0/60.0)
	check(not runtime.view.rows.has(uid) and not geometry.boundary_dead_geometry.has(uid),"existing reference lifetime retires departed geometry")
	check(missile_origin_match[0] and missile_origin_match[1]>0,"ordinal0 input, actual missile birth and fire feedback share the muzzle")
	g.event.disconnect(muzzle_watcher)
	steady_position_publication(geometry,g)
	fixed_layout_contract(geometry,g)
	var transferred_poses:Dictionary=geometry.enemy_poses;var transferred_turrets:Dictionary=geometry.turret_visuals
	var remaining_enemy:Dictionary=g.enemies.back();var old_pose:Dictionary=geometry.enemy_pose(remaining_enemy)
	var pose_values=[old_pose.born,old_pose.phase,old_pose.rotation]
	var fixed_position:Vector2=geometry.enemy_render_position(remaining_enemy)
	var fixed_width:float=geometry.enemy_render_width(remaining_enemy)
	var turret_values:Dictionary={}
	for slot in transferred_turrets:
		var value:Dictionary=transferred_turrets[slot]
		turret_values[slot]={"pose":value,"entry":value.entry,"target":value.target,"angle":value.angle,"recoil":value.recoil,"fired_at":value.get("fired_at",-INF)}
	check(g.native_before_configuration_change(),"one cold whole-owner display handoff")
	check(scene.battle_slice_runtime==null and is_same(scene.enemy_poses,transferred_poses) and is_same(scene.turret_visuals,transferred_turrets),"handoff transfers original containers once")
	check(not transferred_poses.is_empty() and not transferred_turrets.is_empty() and geometry.enemy_poses.is_empty() and geometry.turret_visuals.is_empty(),"retired geometry cleanup cannot empty receiver state")
	check(is_same(scene.enemy_poses[int(remaining_enemy.slot)],old_pose) and [old_pose.born,old_pose.phase,old_pose.rotation]==pose_values,"handoff preserves original entity pose and entrance age")
	for slot in turret_values:
		var before:Dictionary=turret_values[slot];var after:Dictionary=scene.turret_visuals[slot]
		check(is_same(after,before.pose) and is_same(after.entry,before.entry) and is_same(after.target,before.target) and after.angle==before.angle and after.recoil==before.recoil and after.get("fired_at",-INF)==before.fired_at,"handoff preserves turret identity, target, angle and recoil "+str(slot))
	check(scene.enemy_render_position(remaining_enemy).distance_to(fixed_position)<0.001 and scene.enemy_render_width(remaining_enemy)==fixed_width,"handoff preserves shared fixed model position and width")
	check(g.target_spatial_source==scene.battle_read_model and scene.battle_read_model.host==scene,"handoff binds fixed-ray collision to live legacy host")
	check(not g.target_spatial_source.ballistic_shape(remaining_enemy).hull.is_empty(),"handoff can publish an in-flight fixed-ray hull before another frame")
	scene._process(0.0)
	check(is_same(scene.enemy_poses[int(remaining_enemy.slot)],old_pose) and old_pose.born==pose_values[0],"legacy zero step does not replay entry")
	old_pose.erase("fixed_layout")
	check(scene.fixed_enemy_layout and scene.enemy_render_width_at_y(remaining_enemy,90.0)==scene.enemy_render_width_at_y(remaining_enemy,900.0),"handoff policy survives layout cache eviction")
	var replacement:Dictionary=remaining_enemy.duplicate(true);replacement.uid=9800;replacement.slot=int(remaining_enemy.slot)
	var saved_members:Array[Dictionary]=g.enemies;var replacement_members:Array[Dictionary]=[replacement]
	g.enemies=replacement_members;g.notify_configuration_changed();scene._process(0.0)
	check(scene.enemy_render_width_at_y(replacement,90.0)==scene.enemy_render_width_at_y(replacement,900.0),"new identity after handoff keeps fixed dimensions")
	check(is_same(scene.enemy_pose(replacement).entity,replacement),"slot reuse does not inherit the previous pose owner")
	g.enemies=saved_members
	FileAccess.open("res://.runtime/native-scale-result.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	print("NATIVE_SCALE_RESULT ",checks," checks, ",failures," failures")
	g.begin_retreat();scene.queue_free();await process_frame;await process_frame
	quit(1 if failures else 0)