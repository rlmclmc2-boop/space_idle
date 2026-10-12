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

func admit(game:RefCounted,descriptor:Dictionary)->bool:
	if descriptor.get("execution_scope","") not in ["native_low_contract","native_rich15_layer2"]:return false
	if not ClassDB.class_exists("SpaceCombatKernel"):return false
	if descriptor.get("requires_drop_rules",false) and not descriptor.get("drop_rules_compiled",false):return false
	if descriptor.get("enemies",[]).size()>(15 if descriptor.execution_scope=="native_rich15_layer2" else 2):return false
	var candidate:RefCounted=ClassDB.instantiate("SpaceCombatKernel")
	if not candidate.configure(descriptor):return false
	kernel=candidate
	execution_scope=descriptor.execution_scope
	weapons=descriptor.weapons
	actor_rows=kernel.enemy_views()
	for row in actor_rows:actor_by_uid[int(row.uid)]=row
	# Retire old queues and bodies before publishing the new owner. These are
	# one-time bindings to stable rows; tick never serializes the world back.
	game.projectile_clear()
	game.native_pipeline=ClassDB.instantiate("SpaceNativePipeline") # rendering helpers only; never advance battle
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
	game.projectiles=kernel.projectile_views()
	return true

func upgrade_numeric_configuration(game,category:String,index:int,levels:int)->bool:
	var entry:Dictionary=game.slot_entry(category,index)
	var projected=entry.duplicate();projected.level=int(entry.level)+levels
	var descriptor:Dictionary=preload("res://scripts/native_execution_compiler.gd").new().compile(game,execution_scope,{"category":category,"index":index,"level":projected.level})
	if descriptor.has("error"):return false
	if category=="defence" and str(entry.key) in ["armour","shield"] and game.state!=game.State.RETREAT:
		var difference=game.N.subtract(game.jewel_equipment_stat(projected),game.jewel_equipment_stat(entry))
		descriptor.player[entry.key]=game.N.add(game.player[entry.key],difference)
	if not kernel.update_configuration(descriptor):return false
	weapons=descriptor.weapons
	return true

func handoff_to_legacy(game:RefCounted,reason:String)->bool:
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

func advance(game:RefCounted,dt:float)->void:
	if kernel==null:return
	kernel.advance(dt)
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
	consume_feedback(game)
	if handed_off:return
	game.since_hit=float(kernel.metrics().get("since_hit",game.since_hit+dt))
	if float(game.player.armour)<=0:
		game.event.emit("explode",{"x":game.player.x,"y":game.player.y,"boss":true})
		game.begin_retreat()
	elif not game.has_alive_enemy():
		# Existing finish_combat_step owns the original clear/travel filtering.
		# Transfer first so non-final waves keep their already-fired carriers.
		if handoff_to_legacy(game,"wave_complete"):game.finish_combat_step(dt)

func prepare_geometry(geometry:RefCounted,game:RefCounted)->void:
	var points=PackedVector2Array();var muzzles=PackedVector2Array()
	for actor in actor_rows:points.append(geometry.target_point(actor))
	var aim:Vector2=geometry.target_point(game.player)
	for weapon in weapons:
		if bool(weapon.hostile):
			var actor:Dictionary=actor_rows[int(weapon.source)]
			var position:Vector2=geometry.enemy_render_position(actor)
			muzzles.append(geometry.battle_logical_point(position+geometry.enemy_port_offset(actor,int(weapon.slot),position)))
		elif weapon.entry.has("drone_id"):
			muzzles.append(geometry.drone_launch_pose(str(weapon.entry.drone_id),aim,0).position)
		else:muzzles.append(geometry.launch_pose(int(weapon.slot),aim,0).position)
	kernel.input_geometry(points,muzzles)
	kernel.input_player_point(aim)

func consume_feedback(game:RefCounted)->void:
	for row in kernel.take_feedback():
		feedback_rows+=1
		var p:Vector2=row.position
		match int(row.kind):
			0:
				game.event.emit("fire",{"x":p.x,"y":p.y,"type":row.type,"shot":row.shot,"spread":0.0})
				if row.shot.get("beam",false):game.event.emit("beam_started",{"shot":row.shot})
			1:game.event.emit("projectile_impact",{"shot":row.shot,"pos":p})
			2:game.event.emit("hit",{"x":p.x,"y":p.y,"amount":row.amount,"absorbed":row.absorbed,"player":row.player,"type":row.type,"uid":row.uid,"critical":row.critical})
			3:game.event.emit("explode",actor_by_uid[int(row.uid)])
			4:game.event.emit("enhancement_chain",{"source":p,"target":Vector2(row.shot.target.x,row.shot.target.y),"weapon":row.shot.key,"shot":row.shot})
			9:game.event.emit("critical_impact",{"pos":p,"direction":row.direction})
			7:game.drops.append(row.shot)
			8:game.event.emit("enhancement_secondary",{"source":p,"target":Vector2(row.shot.x,row.shot.y),"weapon":"native","beam":true})
			6:game.event.emit("beam_hit",{"shot":row.shot})
			5:
				if row.shot.get("prototype_missile",false) and not bool(row.shot.hostile):
					game.event.emit("prototype_missile_retired",{"serial":row.shot.serial,"reason":"native_retire","time":row.clock,"position":p,"direction":row.direction,"speed":game.projectile_speed(row.shot),"coast":false})

func cancel(game:RefCounted)->void:
	if kernel==null:return
	var released:Dictionary=kernel.exit_state()
	game.projectile_serial=int(released.projectile_serial);game.main_attack_serial=int(released.attack_serial)
	game.attack_instance_serial=int(released.instance_serial);game.uid=int(released.drop_uid)
	game.enhancement_deferred=released.deferred
	game.enhancement_defense_time=float(released.defence_time);game.enhancement_memory_elapsed=float(released.memory_elapsed)
	game.enhancement_deferred_elapsed=float(released.deferred_elapsed);game.enhancement_deferred_tick=int(released.deferred_tick)
	consume_feedback(game)

func configuration_changed()->void:
	# A mutation cannot resume the old executor. Later rich admission will
	# replace this pause with explicit typed configuration commands.
	paused_by_configuration=true
