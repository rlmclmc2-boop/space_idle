extends RefCounted
## Explicit low-load execution boundary. Rich content stays refused until its
## rule compiler is complete; this session never runs a shadow Game battle.
var kernel:RefCounted
var actor_rows:Array[Dictionary]=[]
var actor_by_uid:Dictionary={}
var paused_by_configuration:=false
var execution_scope:=""
var weapons:Array=[]
var production_seconds:=0.0
var ticks:=0
var feedback_rows:=0
var handed_off:=false
var laser_view_revision:=0
var advance_blocked:=false
var galaxy_refit_blocked:=false
var blocked_shared_step:=0.0
var target_geometry_revision:int=-1
var fleet_geometry_revision:int=-1
var hostile_weapon_indices:Array[int]=[]
var friendly_weapon_indices:Array[int]=[]
var weapon_geometry_keys:Dictionary={}
var geometry_muzzles:=PackedVector2Array()
var geometry_player:=Vector2.INF

# Check only at configuration boundaries, including an already-running old DLL.
func supports_configuration(candidate:RefCounted,descriptor:Dictionary)->bool:
	if descriptor.get("requires_endless_beam",false) and (not candidate.has_method("supports_endless_beam") or not candidate.supports_endless_beam()):return false
	if descriptor.get("requires_missile_legends",false) and (not candidate.has_method("supports_missile_legends") or not candidate.supports_missile_legends()):return false
	if descriptor.get("requires_strange_matter",false) and (not candidate.has_method("supports_strange_matter") or not candidate.supports_strange_matter()):return false
	return not descriptor.get("requires_laser_charge",false) or (candidate.has_method("supports_laser_charge") and candidate.supports_laser_charge())

func admit(game:RefCounted,descriptor:Dictionary)->bool:
	if descriptor.get("execution_scope","") not in ["native_low_contract","native_rich15_layer2"]:return false
	if not ClassDB.class_exists("SpaceCombatKernel"):return false
	if descriptor.get("requires_drop_rules",false) and not descriptor.get("drop_rules_compiled",false):return false
	if descriptor.get("enemies",[]).size()>(15 if descriptor.execution_scope=="native_rich15_layer2" else 2):return false
	var candidate:RefCounted=ClassDB.instantiate("SpaceCombatKernel")
	if game.damage_stats.enabled and (not candidate.has_method("set_damage_stats_enabled") or not candidate.has_method("take_damage_stats")):return false
	if not supports_configuration(candidate,descriptor):return false
	if not candidate.configure(descriptor):return false
	if game.damage_stats.enabled:candidate.set_damage_stats_enabled(true)
	kernel=candidate
	execution_scope=descriptor.execution_scope
	weapons=descriptor.weapons
	geometry_muzzles=PackedVector2Array();geometry_player=Vector2.INF
	actor_rows=kernel.enemy_views()
	for row in actor_rows:actor_by_uid[int(row.uid)]=row
	# Retire old queues and bodies before publishing the new owner. These are
	# one-time bindings to stable rows; tick never serializes the world back.
	game.projectile_clear()
	game.cooldowns.clear()
	game.jewel_repeats.clear()
	if "missile_queue" in game:game.missile_queue.clear()
	game.enemies=actor_rows
	game.player=kernel.player_view()
	game.rng=kernel.rng_source()
	game.enhancement_buffers=kernel.buffer_view()
	game.jewel_defence_damage=kernel.loss_view()
	game.jewel_defence_times=kernel.defence_time_view()
	game.enhancement_buffer_owners.clear()
	for index in game.defense_entries().size():
		var entry:Dictionary=game.slot_entry("defence",index)
		game.enhancement_buffer_owners[index]={"entry":entry,"key":str(entry.key)}
	# Internal compatibility/presentation subset while kernel owns combat.
	# Explicit complete consumers use projectile_views(), which can fail with null.
	game.projectiles=kernel.presentation_projectile_rows() if kernel.has_method("presentation_projectile_rows") else kernel.projectile_views()
	return true

func upgrade_numeric_configuration(game,category:String,index:int,levels:int)->bool:
	var entry:Dictionary=game.slot_entry(category,index)
	var projected=entry.duplicate();projected.level=int(entry.level)+levels
	var descriptor:Dictionary=preload("res://scripts/native_execution_compiler.gd").new().compile(game,execution_scope,{"category":category,"index":index,"level":projected.level})
	if descriptor.has("error") or not supports_configuration(kernel,descriptor):return false
	if category=="defence" and str(entry.key) in ["armour","shield"] and game.state!=game.State.RETREAT:
		var difference=game.N.subtract(game.jewel_equipment_stat(projected),game.jewel_equipment_stat(entry))
		descriptor.player[entry.key]=game.N.add(game.player[entry.key],difference)
	if not kernel.update_configuration(descriptor):return false
	weapons=descriptor.weapons
	geometry_muzzles=PackedVector2Array();geometry_player=Vector2.INF
	return true

func prepare_galaxy_refit(game,values:Dictionary)->Dictionary:
	if not kernel.has_method("can_refit_configuration"):return {}
	for key in ["equipment_value","charge_max"]:
		if not values.has(key) or not is_finite(float(values[key])) or float(values[key])<0:return {}
	var energy:float=game.reactor_energy(-1,float(values.charge_max))
	if not is_finite(energy) or energy<0 or energy>=9223372036854775808.0:return {}
	var descriptor:Dictionary=preload("res://scripts/native_execution_compiler.gd").new().compile(game,execution_scope,{},values)
	if descriptor.has("error") or not supports_configuration(kernel,descriptor):return {}
	var ratios:Dictionary=game.refit_health_ratios.duplicate()
	for key in ["armour","shield"]:
		var old_max=game.stat(key)
		if game.N.compare(old_max,0)>0:ratios[key]=clampf(game.N.ratio(game.player[key],old_max),0,1)
		var maximum=0.0
		for defence in descriptor.defences:
			if int(defence.layer)==(1 if key=="armour" else 0):maximum=game.N.add(maximum,defence.maximum)
		descriptor.player[key]=game.N.multiply(maximum,ratios[key])
	descriptor.refit_token=kernel.refit_token()
	if not kernel.can_refit_configuration(descriptor):return {}
	return {"descriptor":descriptor,"ratios":ratios}

func commit_galaxy_refit(game,plan:Dictionary)->bool:
	if not supports_configuration(kernel,plan.descriptor):return false
	if not kernel.refit_configuration(plan.descriptor):return false
	weapons=plan.descriptor.weapons
	geometry_muzzles=PackedVector2Array();geometry_player=Vector2.INF
	game.refit_health_ratios=plan.ratios
	return true

func handoff_to_legacy(game:RefCounted,reason:String)->bool:
	if galaxy_refit_blocked:return false # Partial shared work cannot be replayed by another owner.
	if handed_off:return game.native_execution==null
	var exported:Dictionary=kernel.export_handoff()
	var prepared=preload("res://scripts/native_execution_handoff.gd").new()
	if not prepared.prepare(game,self,exported):return false
	if not kernel.commit_handoff(int(exported.revision)):return false
	# No events/callbacks between stopping the old owner and binding the new
	# owner. Published body/shot identities and leases are retained.
	handed_off=true;game.native_execution=null;game.native_execution_requested=false;game.native_wave_waiting=false
	prepared.commit_views(game)
	game.native_handoff_count+=1
	game.event.emit("native_execution_handoff",{"reason":reason,"clock":exported.clock})
	return true

func advance(game:RefCounted,dt:float)->bool:
	if kernel==null:return false
	if not kernel.advance(dt):
		if not handoff_to_legacy(game,"numeric_range"):
			advance_blocked=true;game.paused=true;game.native_step_phase="blocked"
			push_error("Native numeric boundary could not transfer its untouched combat step")
			return false
		return false
	game.native_step_phase="native_done";game.native_step_remaining=0.0
	production_seconds+=dt
	var values:Dictionary=kernel.metrics()
	var attacks=int(values.attack_counter);var incoming=int(values.incoming_counter)
	if attacks!=int(game.profile.enhancementAttacks):
		game.profile.enhancementAttacks=attacks
		for key in game.WEAPON_KEYS:game.invalidate_equipment_counter(key)
		game.event.emit("equipment_stats",{"category":"weapons","counter_only":true})
	if incoming!=int(game.profile.enhancementHits):
		game.profile.enhancementHits=incoming
		for key in game.DEFENSE_KEYS:game.invalidate_equipment_counter(key)
		game.event.emit("equipment_stats",{"category":"defence","counter_only":true})
	game.uid=int(values.drop_uid);game.enemy_shield_time=float(values.clock)
	game.enhancement_defense_time=float(values.defence_time);game.enhancement_memory_elapsed=float(values.memory_elapsed)
	game.enhancement_deferred_elapsed=float(values.deferred_elapsed);game.enhancement_deferred_tick=int(values.deferred_tick)
	if "motion_clock" in game:game.motion_clock=float(values.clock)
	ticks+=1
	if game.damage_stats.enabled:
		for row in kernel.take_damage_stats():
			game.damage_stats.record(str(row.source),game.N.add(row.shield,row.health))
	consume_feedback(game)
	if handed_off:return true
	game.since_hit=float(kernel.metrics().get("since_hit",game.since_hit+dt))
	if bool(kernel.metrics().get("final_cleared",false)):
		if handoff_to_legacy(game,"final_complete"):game.finish_combat_step(dt)
	elif not game.player_alive():
		game.event.emit("explode",{"x":game.player.x,"y":game.player.y,"boss":true})
		game.begin_retreat()
	elif not game.has_alive_enemy():
		# Existing finish_combat_step owns the original clear/travel filtering.
		# Transfer first so non-final waves keep their already-fired carriers.
		if handoff_to_legacy(game,"wave_complete"):game.finish_combat_step(dt)
	return true

func prepare_geometry(geometry:RefCounted,game:RefCounted)->void:
	geometry.battle_read_model.ensure_clock()
	geometry.refresh_target_geometry()
	geometry.refresh_fleet_geometry()
	var topology_changed:bool=geometry_muzzles.size()!=weapons.size()
	if topology_changed:
		hostile_weapon_indices.clear();friendly_weapon_indices.clear();weapon_geometry_keys.clear()
		geometry_muzzles.resize(weapons.size())
		for index in weapons.size():
			if bool(weapons[index].hostile):hostile_weapon_indices.append(index)
			else:friendly_weapon_indices.append(index)
	var targets_changed:bool=topology_changed or target_geometry_revision!=geometry.target_geometry_revision
	var fleet_changed:bool=topology_changed or fleet_geometry_revision!=geometry.fleet_geometry_revision
	var aim:Vector2=geometry.target_point(game.player)
	if not targets_changed and not fleet_changed and geometry_player==aim:return
	var points=PackedVector2Array();var hulls:Array=[];var screen_points=PackedVector2Array();var stationary=PackedByteArray()
	if targets_changed:
		for actor in actor_rows:
			var shape:Dictionary=geometry.battle_read_model.ballistic_shape(actor)
			points.append(geometry.battle_logical_point(shape.center))
			hulls.append(shape.hull);screen_points.append(shape.center)
			var pose:Dictionary=geometry.enemy_pose(actor)
			stationary.append(1 if geometry.fx_time>=float(pose.born)+float(pose.duration) and Vector2(actor.x,actor.y)==pose.logical_position else 0)
	var muzzles_changed:bool=false
	if targets_changed or geometry_player!=aim:
		for index in hostile_weapon_indices:
			var weapon:Dictionary=weapons[index]
			var actor:Dictionary=actor_rows[int(weapon.source)]
			var position:Vector2=geometry.enemy_render_position(actor)
			var point:Vector2=geometry.battle_logical_point(position+geometry.execution_enemy_port_offset(actor,int(weapon.slot),position))
			if topology_changed or geometry_muzzles[index]!=point:muzzles_changed=true;geometry_muzzles[index]=point
	if fleet_changed:
		for index in friendly_weapon_indices:
			var weapon:Dictionary=weapons[index]
			var key:Array=[]
			if weapon.entry.has("drone_id"):
				var drone:Dictionary=geometry.fleet_pose.drone_by_id.get(str(weapon.entry.drone_id),{})
				key=[drone.get("transform"),geometry.fleet_pose.rendered_position]
			else:
				var module:Dictionary=geometry.fleet_pose.module_by_slot.get(int(weapon.slot),{})
				key=[module.get("mount_root"),module.get("pivot"),geometry.current_hull]
			if weapon_geometry_keys.get(index,[])==key:continue
			weapon_geometry_keys[index]=key
			var point:Vector2
			if weapon.entry.has("drone_id"):point=geometry.drone_launch_pose(str(weapon.entry.drone_id),aim,0).position
			else:point=geometry.launch_pose(int(weapon.slot),aim,0).position
			if topology_changed or geometry_muzzles[index]!=point:muzzles_changed=true;geometry_muzzles[index]=point
	var muzzles=PackedVector2Array();var screen_muzzles=PackedVector2Array()
	if muzzles_changed:
		muzzles=geometry_muzzles
		for muzzle in muzzles:screen_muzzles.append(geometry.battle_point(muzzle))
	if targets_changed or muzzles_changed:
		kernel.input_ballistic_geometry(hulls,screen_points,screen_muzzles,stationary)
		kernel.input_geometry(points,muzzles)
	target_geometry_revision=geometry.target_geometry_revision;fleet_geometry_revision=geometry.fleet_geometry_revision
	if geometry_player!=aim:geometry_player=aim;kernel.input_player_point(aim)

func consume_feedback(game:RefCounted)->void:
	for row in kernel.take_feedback():
		feedback_rows+=1
		var p:Vector2=row.position
		if row.has("native_laser"):
			# Frozen value feedback, including same-step retired births. No shot
			# lookup or complete compatibility Dictionary is created here.
			var info={"native_laser":row.native_laser,"x":p.x,"y":p.y,"pos":p,"type":row.type,"direction":row.direction,"aim":row.target_position,"critical":row.critical}
			match int(row.kind):
				0:game.event.emit("fire",info)
				1:game.event.emit("projectile_impact",info)
				5:pass # Original retirement publishes only friendly missile retirement.
				9:game.event.emit("critical_impact",{"pos":p,"direction":row.direction})
				_:push_error("Unexpected compact laser feedback kind: "+str(row.kind))
			continue
		match int(row.kind):
			0:
				game.event.emit("fire",{"x":p.x,"y":p.y,"type":row.type,"shot":row.shot,"spread":0.0,"direction":row.direction,"aim":row.target_position})
				if row.shot.get("beam",false):game.event.emit("beam_started",{"shot":row.shot})
			1:game.event.emit("projectile_impact",{"shot":row.shot,"pos":p})
			2:
				var hit_feedback := {"x":p.x,"y":p.y,"amount":row.amount,"absorbed":row.absorbed,"player":row.player,"type":row.type,"uid":row.uid,"critical":row.critical}
				if row.has("reactive_stacks"):
					hit_feedback.reactive_stacks = row.reactive_stacks
					hit_feedback.reactive_multiplier = row.reactive_multiplier
				game.event.emit("hit",hit_feedback)
			3:game.event.emit("explode",actor_by_uid[int(row.uid)])
			4:game.event.emit("enhancement_chain",{"source":p,"target":Vector2(row.target_position),"target_uid":row.target_uid,"weapon":row.shot.key,"shot":row.shot})
			9:game.event.emit("critical_impact",{"pos":p,"direction":row.direction})
			7:game.drops.append(row.shot)
			8:game.event.emit("enhancement_secondary",{"source":p,"target":Vector2(row.target_position),"target_uid":row.target_uid,"weapon":"native","beam":true})
			6:game.event.emit("beam_hit",{"shot":row.shot,"pos":p})
			5:
				if row.shot.get("prototype_missile",false) and not bool(row.shot.hostile):
					game.event.emit("prototype_missile_retired",{"serial":row.shot.serial,"reason":"native_retire","time":row.clock,"position":p,"direction":row.direction,"speed":game.projectile_speed(row.shot),"coast":false})

func cancel(game:RefCounted)->void:
	if kernel==null:return
	if game.damage_stats.enabled:
		for row in kernel.take_damage_stats():
			game.damage_stats.record(str(row.source),game.N.add(row.shield,row.health))
	if galaxy_refit_blocked:
		game.native_cancelled_step+=blocked_shared_step;blocked_shared_step=0.0
		game.native_step_phase="idle";game.native_step_remaining=0.0
	var released:Dictionary=kernel.exit_state()
	game.projectile_serial=int(released.projectile_serial);game.main_attack_serial=int(released.attack_serial)
	game.attack_instance_serial=int(released.instance_serial);game.uid=int(released.drop_uid)
	game.drone_combat.delayed=released.get("strange_pending",[])
	game.drone_combat.missile_attacks=int(released.get("missile_attacks",game.drone_combat.missile_attacks))
	game.enhancement_deferred=released.deferred
	game.enhancement_defense_time=float(released.defence_time);game.enhancement_memory_elapsed=float(released.memory_elapsed)
	game.enhancement_deferred_elapsed=float(released.deferred_elapsed);game.enhancement_deferred_tick=int(released.deferred_tick)
	consume_feedback(game)

func configuration_changed()->void:
	# A mutation cannot resume the old executor. Later rich admission will
	# replace this pause with explicit typed configuration commands.
	paused_by_configuration=true

func prepare_numeric_batch(game,mode:String)->Dictionary:
	var wallet:Dictionary=game.profile.resources.duplicate()
	wallet["degenerate_matter"]=game.upgrade_currency("degenerate_matter")
	var weapon_levels:Dictionary={};var defence_levels:Dictionary={};var planned:Dictionary={}
	var player:Dictionary=game.player.duplicate(true)
	for category in ["weapons","defence"]:
		for index in game.loadout_entries(category).size():
			var levels:int=game.max_upgrade_amount_slot(category,index,wallet) if mode=="max" else int(mode)
			if levels<=0:continue
			var costs:Dictionary=game.slot_upgrade_cost(category,index,levels)
			if costs.is_empty():continue
			if not costs.keys().all(func(id):return (id!="degenerate_matter" or game.hyperspace.is_unlocked(game)) and is_finite(float(costs[id])) and game.N.compare(wallet.get(id,0),costs[id])>=0):continue
			for id in costs:wallet[id]=game.N.subtract(wallet.get(id,0),costs[id])
			var entry:Dictionary=game.slot_entry(category,index)
			var projected=entry.duplicate();projected.level=int(entry.level)+levels
			planned[game.slot_id(category,index)]={"levels":levels,"before":int(entry.level)}
			if category=="weapons":weapon_levels[index]=int(projected.level)
			else:
				defence_levels[index]=int(projected.level)
				if str(entry.key) in ["armour","shield"] and game.state!=game.State.RETREAT:
					player[entry.key]=game.N.add(player[entry.key],game.N.subtract(game.jewel_equipment_stat(projected),game.jewel_equipment_stat(entry)))
	if planned.is_empty():return {"skip":true}
	var descriptor:Dictionary=preload("res://scripts/native_execution_compiler.gd").new().compile(game,execution_scope,{"weapon_levels":weapon_levels,"defence_levels":defence_levels})
	if descriptor.has("error") or not supports_configuration(kernel,descriptor):return {}
	descriptor.player=player
	if not kernel.can_update_configuration(descriptor):return {}
	return {"descriptor":descriptor,"planned":planned}

func commit_numeric_batch(game,batch:Dictionary)->bool:
	# Main performed its original sequential purchases and defence deltas. No
	# combat advances inside this synchronous, prevalidated command boundary.
	var descriptor:Dictionary=batch.descriptor
	if not supports_configuration(kernel,descriptor):return false
	descriptor.player=game.player.duplicate(true)
	if not kernel.update_configuration(descriptor):return false
	weapons=descriptor.weapons
	geometry_muzzles=PackedVector2Array();geometry_player=Vector2.INF
	return true
