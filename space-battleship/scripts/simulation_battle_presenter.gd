extends RefCounted
## Main-thread presenter owns UI Game, Nodes, native visual arena and event delivery.
const Display=preload("res://scripts/simulation_display_game.gd")
const Owner=preload("res://scripts/simulation_battle_owner.gd")
var owner
var geometry_restore_context:Dictionary={}
var model:BattleGame
var scene
var enemy_views:Dictionary={}
var shot_views:Dictionary={}
var published_paused:bool=false
var published_speed:float=1.0
var publications:int=0
var render_epoch:int=0
var completed_render_passes:int=0
var applied_events:int=0
var input_wait_us:int=0
var input_wait_max_us:int=0
var input_confirmations:int=0
var last_input_ack:Dictionary={}
var last_confirmed_sequence:int=0
var native_admission:Dictionary={}
var last_snapshot_step:int=-1
var snapshot_age_us_total:int=0
var snapshot_age_us_max:int=0
var snapshot_samples:int=0
var frames_without_new_logic:int=0
var consume_active:bool=false
var pending_bundles:Array=[]
var transport_failures:int=0
var native_steps_before_transfer:int=0
var skipped_helper_fields:Array=[]
var retired_shot_publications:Dictionary={}
var retired_enemy_publications:Dictionary={}
func install(root,pure_geometry)->void:
	scene=root
	var source:BattleGame=scene.game
	# A previously staged foreground may hide native shot/motion references.
	# Discard it before moving the old arena; the new model restages normal draws.
	if is_instance_valid(scene.retained_contacts):
		scene.retained_contacts.frame={};scene.retained_contacts.saved_positions.clear()
		scene.retained_contacts.foreground.queue_redraw()
	if not RenderingServer.frame_post_draw.is_connected(render_completed):RenderingServer.frame_post_draw.connect(render_completed)
	scene.simulation_geometry_view=preload("res://scripts/simulation_geometry_view.gd").new()
	owner=Owner.new();geometry_restore_context=owner.attach(source,pure_geometry)
	model=Display.new(ShipDatabase.new(),false,source.profile.duplicate(true))
	copy_database(source.db,model.db)
	model.profile=source.profile.duplicate(true)
	model.player=source.player.duplicate(true)
	model.galaxy=preload("res://scripts/simulation_galaxy_display.gd").new()
	model.galaxy.load_state(model,source.galaxy.save_data())
	for effect in ["crew_exp","equipment_value","charge_max","gem_fragment"]:model.galaxy.display_multipliers[effect]=source.galaxy.multiplier(effect)
	# Copy value fields only once at transfer. RefCounted helpers are independently
	# constructed by Display; they never borrow a simulation helper/Game reference.
	for property in source.get_property_list():
		var key=str(property.name)
		if key in ["script","profile","player","enemies","projectiles","_projectiles","_native_readonly_observers"]:continue
		var value=source.get(key)
		if not value is Object and not value is Callable and not value is Signal:
			var copied=decode(owner.encode(value))
			if value is Array and model.get(key) is Array:model.get(key).assign(copied)
			else:model.set(key,copied)
	model.native_pipeline=source.native_pipeline
	native_steps_before_transfer=int(source.native_pipeline.lifecycle_stats().managed_steps)
	# Existing UI visual records are explicitly rebound before the original arena
	# becomes main-owned. Native visual leases contain values, no motion/Game link.
	consume_initial(source)
	for key in ["crew","galaxy","reactor_vitals","damage_stats","enhancement_branches","enhancement_plan","planet_buildings","planet_buffs","hyperspace","drone_combat"]:
		copy_helper_values(source.get(key),model.get(key))
	model.invalidate_stat_cache()
	for property in scene.get_property_list():
		var key=str(property.name)
		if key in ["script","game","db","simulation_presenter","simulation_owner","data_geometry"]:continue
		var value=scene.get(key)
		if value is Array:value.assign(rebind_ui(value,source))
		elif value is Dictionary:scene.set(key,rebind_ui(value,source))
	# Start a clean motion-only native arena. Restore exact doubles before rebinding;
	# the visual arena now owns detached UI shots and receives compact value updates.
	source.native_pipeline=ClassDB.instantiate("SpaceNativePipeline")
	for shot in source.projectiles:
		var lease=shot.get("motion_lease")
		if lease==null:continue
		shot.x=lease.x();shot.y=lease.y();shot.direction=lease.direction();shot.speed=lease.speed()
		if lease.missile_fields():shot.motion_age=lease.age();shot.orphan_age=lease.orphan();shot.last_target_point=lease.last_aim()
		shot.erase("motion_lease")
	source.native_pipeline.replace_records(source.projectiles)
	for shot in source.projectiles:source.bind_projectile_motion(shot)
	scene.game=model;scene.db=model.db
	model.launch_provider=scene._prototype_launch_pose;model.drone_launch_provider=scene._prototype_drone_launch_pose
	model.target_provider=scene._prototype_target_point;model.target_spatial_source=scene.battle_read_model
	model.rail_geometry_provider=scene._rail_geometry;model.rail_target_point_provider=scene.entity_render_position
	model.event.connect(scene.on_event)
	model.command_gateway=dispatch_command;model.display_ready=true
	# Rebuild panels/captured UI closures against Display, rather than retaining an
	# old Game reference in a hidden panel or anonymous signal callback.
	var guide_visible=scene.beginner_guide.visible if is_instance_valid(scene.beginner_guide) else true
	var equipment_amount:int=scene.equipment_panel.upgrade_amount if is_instance_valid(scene.equipment_panel) else 1
	scene.build_ui();scene.refresh_structure();scene.refresh_tab_visibility()
	if is_instance_valid(scene.equipment_panel):scene.equipment_panel.set_upgrade_amount(equipment_amount)
	if is_instance_valid(scene.beginner_guide):scene.beginner_guide.visible=guide_visible
	model.projectiles=active_views(source.projectiles)
	rewrite_script_objects(scene,source,{})
	published_paused=model.paused;published_speed=model.speed
func consume_initial(source:BattleGame)->void:
	var packet=owner.base_packet(true)
	packet.entities_added=owner.new_entities;owner.new_entities=[]
	packet.shots_added=owner.new_shots;owner.new_shots=[]
	apply_packet(packet)
func rebind_ui(value:Variant,source:BattleGame)->Variant:
	if value is Dictionary:
		if value.has("uid") and value.has("hp"):return decode(owner.entity_token(value))
		if value.has("serial") and value.has("key") and value.has("target"):
			var token=owner.shot_token(value)
			if not owner.new_shots.is_empty():
				for row in owner.new_shots:shot_views[int(row.serial)]=decode(row.metadata)
				owner.new_shots=[]
			return decode(token)
		if is_same(value,source.player):return model.player
		var result={}
		for key in value:
			if str(key)=="motion_lease":continue
			result[key]=rebind_ui(value[key],source)
		return result
	if value is Array:
		var result=[]
		for member in value:result.append(rebind_ui(member,source))
		return result
	return value
func decode(value:Variant)->Variant:
	if value is Dictionary:
		if value.has("$player"):return model.player
		if value.has("$enemy"):return enemy_views.get(str(value["$enemy"])+":"+str(value.generation),{})
		if value.has("$shot"):return shot_views.get(int(value["$shot"]),{})
		var result={}
		for key in value:result[key]=decode(value[key])
		return result
	if value is Array:
		var result=[]
		for member in value:result.append(decode(member))
		return result
	return value
func apply_packet(packet:Dictionary)->void:
	if packet.has("snapshot_built_us"):
		var age=maxi(0,Time.get_ticks_usec()-int(packet.snapshot_built_us))
		snapshot_age_us_total+=age;snapshot_age_us_max=maxi(snapshot_age_us_max,age);snapshot_samples+=1
		last_snapshot_step=int(packet.logical_steps)
	if packet.has("configuration"):
		model.profile=packet.configuration.duplicate(true);model.combat_sources_dirty=true;model.invalidate_stat_cache()
	for row in packet.get("entities_added",[]):
		var identity=str(row.uid)+":"+str(row.generation)
		enemy_views[identity]=decode(row.metadata)
		if row.has("geometry_descriptor"):scene.simulation_geometry_view.descriptor(int(row.uid),row.geometry_descriptor)
	for row in packet.get("shots_added",[]):
		var shot=decode(row.metadata)
		var mount=int(shot.get("mount",-1))
		if not bool(shot.get("hostile",false)) and mount>=0 and mount<model.combat_weapon_entries().size():shot.entry=model.combat_entry(mount)
		if shot_views.has(int(row.serial)):
			var existing:Dictionary=shot_views[int(row.serial)];existing.merge(shot,true);shot=existing
		else:shot_views[int(row.serial)]=shot
		if not model.projectiles.has(shot):model.projectile_append(shot)
	for index in packet.get("weapon_states",{}):
		var data=decode(packet.weapon_states[index]);data.entry=model.combat_entry(int(index));model.enhancement_branches.weapons[index]=data
	for index in packet.get("defense_states",{}):
		var data=decode(packet.defense_states[index]);data.entry=model.slot_entry("defence",int(index));model.enhancement_branches.defenses[index]=data
	for key in packet.get("fields",{}):
		if key in ["paused","speed"] and int(packet.get("input_sequence",last_confirmed_sequence))<last_confirmed_sequence:continue
		model.set(key,decode(packet.fields[key]))
	for key in packet.get("profile_dynamic",{}):model.profile[key]=decode(packet.profile_dynamic[key])
	if packet.has("drops"):model.drops.assign(decode(packet.drops))
	if packet.has("cooldowns"):model.cooldowns=decode(packet.cooldowns)
	if packet.has("defense_projection"):model.display_defense_projection=packet.defense_projection
	if packet.has("deferred_projection"):model.display_deferred_projection=packet.deferred_projection
	var player=decode(packet.get("player",{}))
	for key in player:model.player[key]=player[key]
	var enemies:Array[Dictionary]=[]
	for row in packet.get("enemies",packet.get("enemy_changes",[])):
		var enemy:Dictionary=decode(row.token)
		for key in ["hp","shield","x","y","shield_hit_at","shield_updated_at","interference"]:enemy[key]=decode(row[key])
		enemies.append(enemy)
	if packet.has("enemies"):model.enemies=enemies
	for row in packet.get("shot_values",[]):
		var shot:Dictionary=shot_views.get(int(row.serial),{})
		if shot.is_empty():continue
		model.display_chain_targets[int(row.serial)]=decode(row.get("chain_targets",[]))
		var values:PackedFloat64Array=row.values
		shot.x=values[0];shot.y=values[1];shot.direction=Vector2(values[2],values[3]);shot.speed=values[4]
		shot.motion_age=values[5];shot.charge=values[6];shot.ticks=int(values[7]);shot.elapsed=values[8]
		var target:Dictionary=decode(row.target)
		if not is_same(shot.get("target",{}),target):model.projectile_set_target(shot,target)
		if row.dead:model.projectile_mark_dead(shot)
	for identity in packet.get("retired_shots",[]):retired_shot_publications[int(identity)]=completed_render_passes
	if packet.has("active_shots"):
		var active:Array[Dictionary]=[]
		for serial in packet.active_shots:
			if shot_views.has(serial):active.append(shot_views[serial])
		model.projectiles=active
	if packet.has("fx_time"):scene.fx_time=packet.fx_time
	if packet.has("demo_time"):scene.demo_time=packet.demo_time
	if packet.has("orbit_elapsed"):scene.ship_view.orbit_elapsed=packet.orbit_elapsed
	if packet.has("geometry_shapes"):scene.simulation_geometry_view.apply({"shapes":packet.geometry_shapes})
	if packet.has("geometry"):scene.simulation_geometry_view.apply(packet.geometry)
	if packet.has("turrets"):scene.turret_visuals=decode(packet.turrets)
	for index in packet.get("turret_changes",{}):scene.turret_visuals[index]=decode(packet.turret_changes[index])
	if packet.has("turret_ship"):scene.turret_ship=packet.turret_ship
	# Entries are identity-bearing UI configuration values, never simulation refs.
	for index in scene.turret_visuals:
		scene.turret_visuals[index].entry=model.slot_entry("weapons",int(index))
	if packet.has("shield_before_hit"):scene.shield_before_hit=decode(packet.shield_before_hit)
	published_paused=model.paused;published_speed=model.speed;publications+=1
func active_views(source:Array)->Array[Dictionary]:
	var result:Array[Dictionary]=[]
	for shot in source:
		if shot_views.has(int(shot.serial)):result.append(shot_views[int(shot.serial)])
	return result
func consume()->void:
	if consume_active:return
	consume_active=true
	pending_bundles.append(owner.mailbox.consume_bundle())
	while not pending_bundles.is_empty():consume_ordered_bundle(pending_bundles.pop_front())
	consume_active=false
func collect_during_confirmation()->void:
	# A UI subscriber can submit another command. Drain transport to release
	# backpressure, but finish the current event prefix before emitting later events.
	var bundle=owner.mailbox.consume_bundle()
	if not bundle.snapshot.is_empty():
		var lease:Dictionary=bundle.snapshot
		owner.mailbox.release(int(lease.slot))
		bundle.snapshot={"slot":-1,"frame":lease.frame,"sequence":lease.sequence,"event_watermark":lease.event_watermark}
	if not bundle.events.is_empty() or not bundle.snapshot.is_empty():pending_bundles.append(bundle)
func consume_ordered_bundle(bundle:Dictionary)->void:
	var lease:Dictionary=bundle.snapshot
	var applied_frame=false
	for envelope in bundle.events:
		# Never apply an older snapshot after a newer discrete state transition.
		if not lease.is_empty() and not applied_frame and int(envelope.sequence)>int(lease.event_watermark):
			apply_frame_lease(lease);applied_frame=true
		var packet:Dictionary=envelope.payload
		apply_packet(packet)
		if bool(packet.get("transport_only",false)):continue
		scene.simulation_event_muzzles=decode(packet.get("event_muzzle",{}))
		model.event.emit(packet.kind,decode(packet.payload));applied_events+=1
		scene.simulation_event_muzzles={}
	if not lease.is_empty() and not applied_frame:apply_frame_lease(lease)
	reclaim_visual_records()
func apply_frame_lease(lease:Dictionary)->void:
	render_epoch+=1;apply_packet(lease.frame)
	if int(lease.slot)>=0:owner.mailbox.release(int(lease.slot))
func start_worker()->Error:
	# Both native arenas must exclude the other side before concurrent use.
	# This also inspects replacements/leases, not just script-visible records.
	var source=owner._kernel
	if source.native_pipeline!=null and model.native_pipeline!=null:
		var checks=[source.native_pipeline.audit_reference_isolation(model.enemies,model.player,model.projectiles,model.native_pipeline),model.native_pipeline.audit_reference_isolation(source.enemies,source.player,source.projectiles,source.native_pipeline)]
		for check in checks:
			for key in ["foreign_shots","foreign_targets","foreign_visuals","source_motion_leases"]:
				if int(check[key])!=0:return ERR_UNAUTHORIZED
		native_admission={"both_arenas_exclude_foreign_records":true,"scope":"live and replacement native records/leases; deferred visual frames remain main-owned"}
	return owner.start_worker()
func wait_for_ack(sequence:int)->Dictionary:
	var started=Time.get_ticks_usec()
	var ack=owner.mailbox.take_ack(sequence)
	while ack.is_empty() and not owner.mailbox.should_stop() and owner.worker.is_alive():
		if consume_active:collect_during_confirmation()
		else:consume()
		OS.delay_usec(100)
		ack=owner.mailbox.take_ack(sequence)
	var elapsed=Time.get_ticks_usec()-started
	input_wait_us+=elapsed;input_wait_max_us=maxi(input_wait_max_us,elapsed);input_confirmations+=1
	return ack if not ack.is_empty() else {"accepted":false,"reason":"worker_stopped"}
func synchronize()->bool:
	if not owner.worker_active:return true
	return bool(dispatch_command("__barrier",[]))
func advance(seconds:float)->void:
	if owner.worker_active:
		var prior_step=last_snapshot_step
		var request=owner.dispatch("__advance",[seconds])
		while not request.accepted and not owner.mailbox.should_stop():
			consume();OS.delay_usec(100);request=owner.dispatch("__advance",[seconds])
		consume()
		if last_snapshot_step==prior_step:frames_without_new_logic+=1
		return
	var complete=owner.advance(seconds)
	consume()
	while not complete:
		complete=owner.advance(0.0);consume()
func dispatch_command(name:String,args:Array)->Variant:
	var ack=owner.dispatch(name,args)
	if bool(ack.get("pending",false)):ack=wait_for_ack(int(ack.sequence))
	consume()
	if not bool(ack.get("accepted",false)):
		push_error("Simulation input rejected: "+str(ack.get("reason","unknown")));return false
	# A nested subscriber may already have confirmed a later input. The outer
	# result still returns to its caller, but cannot roll back newer UI fields.
	if int(ack.sequence)>=last_confirmed_sequence:
		last_confirmed_sequence=int(ack.sequence);last_input_ack=ack
		for key in ack.get("authoritative_fields",{}):model.set(key,ack.authoritative_fields[key])
	published_paused=model.paused;published_speed=model.speed
	return decode(ack.get("result"))
func capture_inputs()->void:
	# Direct pause/speed UI fields are converted to ordered input writes. No other
	# direct mutable display field may silently become authoritative.
	if model.paused!=published_paused:dispatch_command("set_field",["paused",model.paused])
	if model.speed!=published_speed:dispatch_command("set_speed",[model.speed])
func metrics()->Dictionary:
	var result=owner.metrics();result.UI_events=applied_events;result.UI_publications=publications
	result.production_single_thread_connected=not owner.worker_active;result.thread_started=owner.worker_active
	result.input_wait_us=input_wait_us;result.input_wait_max_us=input_wait_max_us;result.input_confirmations=input_confirmations
	result.snapshot_samples=snapshot_samples;result.snapshot_age_us_total=snapshot_age_us_total;result.snapshot_age_us_max=snapshot_age_us_max;result.frames_without_new_logic=frames_without_new_logic
	result.native_steps_before_transfer=native_steps_before_transfer;result.skipped_helper_fields=skipped_helper_fields
	result.completed_render_passes=completed_render_passes
	result.UI_shot_records=shot_views.size();result.UI_enemy_records=enemy_views.size();result.sim_shot_records=result.get("sim_shot_records",0);result.sim_enemy_records=result.get("sim_enemy_records",0)
	return result
func close()->void:
	if RenderingServer.frame_post_draw.is_connected(render_completed):RenderingServer.frame_post_draw.disconnect(render_completed)
	model.command_gateway=Callable()
	owner.stop_worker() # join before any main access to authority or restore data.
	var geometry=owner.geometry
	var source=owner._kernel
	owner.close()
	# The worker must already be stopped before shutdown restores main-only data.
	for callback in geometry_restore_context.get("native_observers",[]):source.native_transaction_observer(callback)
	if geometry!=null and geometry.has_method("close"):geometry.close(geometry_restore_context)
	scene.simulation_geometry_view=null
	geometry_restore_context={};owner=null;model=null;scene=null

func rewrite_script_objects(value:Variant,source:BattleGame,seen:Dictionary)->void:
	if not value is Object or not is_instance_valid(value):return
	if value==source or value==model or value==owner or value==self:return
	var identity=value.get_instance_id()
	if seen.has(identity):return
	seen[identity]=true
	if value.get_script()!=null:
		for property in value.get_property_list():
			var key=str(property.name)
			if key in ["script","simulation_presenter","data_geometry","db","simulation_bridge"]:continue
			if not int(property.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE:continue
			var member=value.get(key)
			if member is Object and member==source:value.set(key,model);continue
			if member is Array or member is Dictionary:
				var replaced=rebind_ui(member,source)
				if member is Array:member.assign(replaced)
				else:value.set(key,replaced)
			elif member is Object:rewrite_script_objects(member,source,seen)
	if value is Node:
		for child in value.get_children():rewrite_script_objects(child,source,seen)

func copy_database(source,display)->void:
	# Configuration is detached once, including authored QA/parsed projections.
	# Loading a fresh raw DB alone loses resolved equipment/crew/reactor modifiers.
	for key in ["data","equipment","enemies","groups","levels","config","defaults","ships"]:
		var value=source.get(key)
		if value is Array:display.get(key).assign(value.duplicate(true))
		elif value is Dictionary:display.set(key,value.duplicate(true))
	if source.has_meta("prototype_enemy_source"):
		var enemy_db=ShipDatabase.new();copy_database(source.get_meta("prototype_enemy_source"),enemy_db)
		display.set_meta("prototype_enemy_source",enemy_db)
func copy_helper_values(source,display)->void:
	if source==null or display==null:return
	for property in source.get_property_list():
		if not int(property.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE:continue
		var key=str(property.name);var value=source.get(key)
		if value is Object or value is Callable or value is Signal:continue
		if not owner.mailbox._is_value_packet(value):
			skipped_helper_fields.append({"source":source.get_script().resource_path,"field":key});continue
		var encoded=owner.encode(value)
		if not owner.mailbox._is_value_packet(encoded):continue
		var copied=decode(encoded)
		if value is Array and display.get(key) is Array:display.get(key).assign(copied)
		else:display.set(key,copied)

func audit_ui_references(root,source:BattleGame)->Array:
	var findings=[];_audit_value(root,source,"UI",{},findings)
	return findings
func _audit_value(value:Variant,source:BattleGame,path:String,seen:Dictionary,findings:Array)->void:
	if value is Object:
		if not is_instance_valid(value):return
		if value==source:findings.append(path+":live Game");return
		if value==owner or value==self or value==owner.geometry:return
		if value is WeakRef:
			if value.get_ref()==source:findings.append(path+":weak live Game")
			return
		var identity=value.get_instance_id()
		if seen.has(identity):return
		seen[identity]=true
		if value.get_script()!=null:
			for property in value.get_property_list():
				var key=str(property.name)
				if not int(property.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE or key in ["simulation_presenter","data_geometry"]:continue
				_audit_value(value.get(key),source,path+"."+key,seen,findings)
		if value is Node:
			for child in value.get_children():_audit_value(child,source,path+"/"+child.name,seen,findings)
	elif value is Dictionary:
		if is_same(value,source.profile) or is_same(value,source.player):findings.append(path+":live profile/player");return
		if value.has("uid") and value.has("hp"):
			var original:Dictionary=owner.entity_records.get(int(value.uid),{}).get("record",{})
			if is_same(value,original):findings.append(path+":live enemy");return
		if value.has("serial") and value.has("target"):
			if is_same(value,owner.shot_records.get(int(value.serial),{})):findings.append(path+":live shot");return
		for key in value:_audit_value(value[key],source,path+"."+str(key),seen,findings)
	elif value is Array:
		for index in value.size():_audit_value(value[index],source,path+"["+str(index)+"]",seen,findings)
	elif value is Callable:
		if value.get_object()==source:findings.append(path+":live Game callback")
		for bound in value.get_bound_arguments():_audit_value(bound,source,path+".bound",seen,findings)

func render_completed()->void:
	# Main-thread renderer submission fence, not a claim of GPU completion.
	completed_render_passes+=1
func reclaim_visual_records()->void:
	# Retired metadata survives explicit visual references and two completed
	# renderer passes, regardless of how many snapshots were consumed. Deferred native frames may retain their own UI-only record;
	# erasing the registry never invalidates those independently owned references.
	var needed_shots={};var needed_entities={}
	for shot in model.projectiles:needed_shots[int(shot.serial)]=true
	for collection in [scene.projectile_visuals,scene.beam_visuals]:
		for visual in collection:
			var shot:Dictionary=visual.get("shot",{})
			if shot.has("serial"):needed_shots[int(shot.serial)]=true
	if scene is Node and is_instance_valid(scene.retained_contacts):
		for shot in scene.retained_contacts.frame.get("shots",[]):
			if shot.has("serial"):needed_shots[int(shot.serial)]=true
	for identity in retired_shot_publications.keys():
		if needed_shots.has(identity) or completed_render_passes-int(retired_shot_publications[identity])<2:continue
		shot_views.erase(identity);model.display_chain_targets.erase(identity);retired_shot_publications.erase(identity)
	for enemy in model.enemies:needed_entities[str(enemy.uid)]=true
	for shot in shot_views.values():
		for key in ["target","source","locked_target"]:
			var record:Dictionary=shot.get(key,{})
			if record.has("uid"):needed_entities[str(record.uid)]=true
	for targets in model.display_chain_targets.values():
		for target in targets:
			if target.has("uid"):needed_entities[str(target.uid)]=true
	for key in enemy_views.keys():
		if needed_entities.has(str(enemy_views[key].uid)):retired_enemy_publications.erase(key);continue
		if not retired_enemy_publications.has(key):retired_enemy_publications[key]=completed_render_passes
		elif completed_render_passes-int(retired_enemy_publications[key])>=2:
			scene.simulation_geometry_view.retire(int(enemy_views[key].uid))
			enemy_views.erase(key);retired_enemy_publications.erase(key)
