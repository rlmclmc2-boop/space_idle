extends RefCounted
## Single-thread ownership prototype. The kernel and native motion arena never
## escape through packets; renderer receives IDs/value records and owns its arena.
const Display=preload("res://scripts/simulation_display_game.gd")
const Mailbox=preload("res://scripts/simulation_render_mailbox.gd")
var _kernel:BattleGame
var geometry
var mailbox=Mailbox.new()
var pending_events:Array=[]
var command_serial:int=0
var command_acks:Dictionary={}
var last_command_sequence:int=0
var command_queue_active:bool=false
var command_signatures:Dictionary={}
var remainder:float=0.0
var logical_steps:int=0
var event_count:int=0
var event_backpressure:int=0
var publication_us:int=0
var configuration_version:int=1
var configuration_dirty:bool=true
var entity_records:Dictionary={}
var shot_records:Dictionary={}
var new_entities:Array=[]
var new_shots:Array=[]
var pending_configuration:Dictionary={}
var event_packets:Array=[]
var full_frame:Dictionary={}
var pending_frame_retired:PackedInt64Array=PackedInt64Array()
var _generation:int=0
var _step_shield:Variant=0.0
var last_weapon_publication:Dictionary={}
var dirty_weapon_states:Dictionary={}
var dirty_defense_states:Dictionary={}
var last_defense_publication:Dictionary={}
const CORE_FIELDS=["state","stage","group_index","distance","since_hit","paused","speed","clear_timer","guard_index","guard_elapsed","guard_engaged","guard_arrived","enemy_shield_time","enemy_shield_hit_time","motion_clock","uid","projectile_serial","first_clear"]
const PROFILE_DYNAMIC=["productionElapsed","chronoParticles","enhancementAttacks","enhancementHits","resources","techPoints","furnaceElapsed","jewelFurnaceElapsed"]
const SHOT_OMIT=["motion_lease","attack_instance","attack_snapshot","jewelEffects","higgs","guidance_layers"]
const DOMAIN_COMMANDS={"crew": ["assign"], "planet_buildings": ["activate", "assign"], "hyperspace": ["exchange_materials", "equip_drone", "unequip_drone", "set_equipped", "set_favorites", "set_preset", "clear_preset", "remove_unprotected", "claim_sealed", "forge", "attach_hangings", "set_filter", "import_filter", "set_legendary_collection", "apply_preset"]}
func attach(kernel:BattleGame,pure_geometry)->Dictionary:
	_kernel=kernel;geometry=pure_geometry
	var restoration:Dictionary=geometry.take_restore_context() if geometry.has_method("take_restore_context") else {}
	# Old provider observer classifications can retain the scene even when their
	# callback is no longer installed in a Game field or signal connection.
	var detached_observers:Array[Callable]=[]
	for callback in _kernel._native_readonly_observers.duplicate():
		if callback.get_object() is Node:
			detached_observers.append(callback);_kernel.native_forget_observer(callback)
	restoration.native_observers=detached_observers
	for method in _kernel.get_method_list():
		if str(method.name) in COMMANDS:command_signatures[str(method.name)]={"arguments":method.args.duplicate(true),"defaults":method.default_args.size()}
	for domain in DOMAIN_COMMANDS:
		for method in _kernel.get(domain).get_method_list():
			if str(method.name) in DOMAIN_COMMANDS[domain]:
				command_signatures[str(domain)+"."+str(method.name)]={"arguments":method.args.slice(1).duplicate(true),"defaults":method.default_args.size()}
	_kernel.simulation_descriptor_publisher=descriptor_ready
	_kernel.simulation_mutation_sink=mark_state_changed
	# Only pure semantic subscribers remain attached to the kernel. UI subscribers
	# are reconnected to Display by the main-thread presenter during transfer.
	for row in _kernel.event.get_connections():
		var callback:Callable=row.callable
		var receiver=callback.get_object()
		var source=receiver.get_script() if receiver!=null else null
		var path=str(source.resource_path) if source!=null else ""
		if receiver==_kernel or receiver==geometry or path=="res://scripts/crew_system.gd":continue
		if not receiver is Node and _kernel._native_readonly_observers.has(callback) and path not in ["res://scripts/system_upgrade_badges.gd"]:continue
		_kernel.event.disconnect(callback);_kernel.native_forget_observer(callback)
	_kernel.event.connect(capture_event);_kernel.native_transaction_observer(capture_event)
	for enemy in _kernel.enemies:entity_token(enemy)
	for shot in _kernel.projectiles:shot_token(shot)
	return restoration
func entity_token(record:Dictionary)->Dictionary:
	if is_same(record,_kernel.player):return {"$player":true}
	var identity=int(record.uid)
	if not entity_records.has(identity) or not is_same(entity_records[identity].record,record):
		_generation+=1;entity_records[identity]={"record":record,"generation":identity}
		var metadata={}
		for key in record:
			if key in ["hp","shield","cooldowns","guidance_layers"]:continue
			metadata[key]=encode(record[key])
		new_entities.append({"uid":identity,"generation":identity,"metadata":metadata})
	return {"$enemy":identity,"generation":entity_records[identity].generation}
func descriptor_ready(record:Dictionary)->void:
	shot_token(record,true)
func shot_token(record:Dictionary,refresh:bool=false)->Dictionary:
	var identity=int(record.serial)
	if refresh or not shot_records.has(identity):
		shot_records[identity]=record
		var metadata={}
		for key in record:
			if key in SHOT_OMIT:continue
			metadata[key]=encode(record[key])
		metadata.x=_kernel.projectile_x(record);metadata.y=_kernel.projectile_y(record)
		metadata.direction=_kernel.projectile_direction(record);metadata.speed=_kernel.projectile_speed(record)
		new_shots.append({"serial":identity,"metadata":metadata})
	return {"$shot":identity}
func encode(value:Variant)->Variant:
	if value is Dictionary:
		if is_same(value,_kernel.player):return {"$player":true}
		if value.has("uid") and value.has("hp"):return entity_token(value)
		if value.has("serial") and value.has("key") and value.has("target"):return shot_token(value)
		var result={}
		for key in value:
			if key in SHOT_OMIT:continue
			result[key]=encode(value[key])
		return result
	if value is Array:
		var result=[]
		for entry in value:result.append(encode(entry))
		return result
	if value is Object or value is Callable or value is Signal:
		assert(false,"Uncompiled object at simulation publication boundary");return null
	return value.duplicate() if typeof(value)>=TYPE_PACKED_BYTE_ARRAY else value
func capture_event(kind:String,payload:Dictionary)->void:
	var started=Time.get_ticks_usec()
	if kind in ["ship_changed","module_changed","upgrade","crew_changed","hightech_changed","reactor_changed","jewels_changed","enhancement_changed","hyperspace_changed","planet_changed","onboarding_changed","tutorial_read"] or (kind=="equipment_stats" and not bool(payload.get("counter_only",false))):configuration_dirty=true
	var info=encode(payload)
	var packet=event_packet(kind,payload)
	packet.kind=kind;packet.payload=info;packet.shield_before_hit=encode(_step_shield)
	if payload.has("shot"):
		packet.shot_values=[shot_values(payload.shot)]
		packet.event_muzzle={int(payload.shot.serial):geometry.visual_muzzle(payload.shot)}
	else:packet.shot_values=[]
	packet.entities_added=new_entities;new_entities=[];packet.shots_added=new_shots;new_shots=[]
	# A failed enqueue retains this event. No later event may overtake it, and
	# no following simulation step may run until the presenter drains the FIFO.
	pending_events.append(packet);event_count+=1
	flush_events()
	publication_us+=Time.get_ticks_usec()-started
func flush_events()->bool:
	while not pending_events.is_empty():
		if not mailbox.append_owned_event(pending_events[0]):event_backpressure+=1;return false
		pending_events.pop_front()
	return true
func base_packet(with_motion:bool)->Dictionary:
	var fields={}
	for key in CORE_FIELDS:fields[key]=_kernel.get(key)
	var profile={}
	for key in PROFILE_DYNAMIC:
		if _kernel.profile.has(key):profile[key]=encode(_kernel.profile[key])
	var enemies=[]
	for record in _kernel.enemies:
		var token=entity_token(record)
		enemies.append({"token":token,"hp":encode(record.hp),"shield":encode(record.get("shield",0)),"x":record.x,"y":record.y,"shield_hit_at":record.get("shield_hit_at",0),"shield_updated_at":record.get("shield_updated_at",0),"interference":record.get("interference",0)})
	var weapon_states={}
	for index in _kernel.enhancement_branches.weapons:
		var data=_kernel.enhancement_branches.weapons[index];weapon_states[index]={}
		for key in ["target","dwell","next","stacks","stack_time"]:weapon_states[index][key]=encode(data[key])
	var defense_states={}
	for index in _kernel.enhancement_branches.defenses:
		var data=_kernel.enhancement_branches.defenses[index];defense_states[index]={}
		for key in ["cover","cover_elapsed","cover_time","resistance_type","resistance_time","lockout"]:defense_states[index][key]=encode(data[key])
	var packet={"weapon_states":weapon_states,"defense_states":defense_states,"fields":fields,"profile_dynamic":profile,"player":encode(_kernel.player.duplicate()),"drops":encode(_kernel.drops),"cooldowns":encode(_kernel.cooldowns),"defense_projection":encode(_kernel.enhancement_protection_status()),"deferred_projection":encode(_kernel.enhancement_deferred_total()),"enemies":enemies,"fx_time":geometry.fx_time,"demo_time":geometry.demo_time,"orbit_elapsed":geometry.fleet_pose.orbit_elapsed,"turrets":encode(geometry.turret_visuals),"turret_ship":geometry.turret_ship,"configuration_version":configuration_version}
	# Snapshot data is compact dynamic state; static profile/configuration only
	# travels on a structural generation. No Game/object graph is cloned per frame.
	if configuration_dirty:
		configuration_version+=1;packet.configuration_version=configuration_version
		packet.configuration=_kernel.profile.duplicate(true);configuration_dirty=false
	if with_motion:
		var rows=[];var order=PackedInt64Array()
		for shot in _kernel.projectiles:shot_token(shot);rows.append(shot_values(shot));order.append(int(shot.serial))
		packet.shot_values=rows;packet.active_shots=order
	return packet
func shot_values(shot:Dictionary)->Dictionary:
	var position=Vector2(_kernel.projectile_x(shot),_kernel.projectile_y(shot))
	var direction=_kernel.projectile_direction(shot)
	return {"serial":int(shot.serial),"target":encode(shot.get("target",{})),"values":PackedFloat64Array([position.x,position.y,direction.x,direction.y,_kernel.projectile_speed(shot),_kernel.projectile_motion_age(shot,0),float(shot.get("charge",0)),float(shot.get("ticks",0)),float(shot.get("elapsed",0))]),"dead":bool(shot.get("dead",false)),"chain_targets":encode(_kernel.beam_chain_targets(shot)) if bool(shot.get("beam",false)) and shot.has("locked_target") and shot.has("attack_instance") else []}
func advance(seconds:float)->bool:
	# Time debt survives backpressure. A staged frame/delta is constructed once.
	remainder+=seconds
	if not flush_events():return false
	if not full_frame.is_empty() and not publish_pending_frame():return false
	const STEP=1.0/60.0
	while remainder+0.0000000001>=STEP:
		if not pending_events.is_empty():return false
		_step_shield=_kernel.player.shield
		geometry.before_tick(STEP);_kernel.tick(STEP);geometry.after_tick()
		logical_steps+=1;remainder=maxf(0,remainder-STEP)
	var started=Time.get_ticks_usec()
	geometry.finish_display_boundary()
	full_frame=base_packet(true)
	pending_frame_retired=retired_shot_ids(full_frame.active_shots)
	var retired=pending_frame_retired
	# Birth/configuration/retirement are lossless protocol records. A PUBLISHED
	# dynamic snapshot may be replaced, so it must never own a one-shot delta.
	var delta={"transport_only":true,"entities_added":new_entities,"shots_added":new_shots,"retired_shots":retired}
	new_entities=[];new_shots=[]
	if full_frame.has("configuration"):
		delta.configuration=full_frame.configuration;delta.configuration_version=full_frame.configuration_version
		full_frame.erase("configuration")
	if not delta.entities_added.is_empty() or not delta.shots_added.is_empty() or not retired.is_empty() or delta.has("configuration"):
		pending_events.append(delta)
	if not flush_events():return false
	var complete=publish_pending_frame()
	publication_us+=Time.get_ticks_usec()-started
	return complete
func publish_pending_frame()->bool:
	var slot=mailbox.begin_write()
	if slot<0:return false
	if not mailbox.publish_owned(slot,full_frame):return false
	for identity in pending_frame_retired:shot_records.erase(identity)
	retire_entity_records()
	full_frame={};pending_frame_retired=PackedInt64Array()
	return true
const COMMANDS=["resume_progress","equip_slot","unequip_slot","upgrade_reactor","set_reactor_allocation","equalize_reactor_allocation","scientist_purchase","generate_scientist","distribute_scientists","assign_scientist","set_planet_auto","start_planet_exploration","cancel_planet_exploration","change_state","select_loop_level","set_guard_death","set_hyperspace_auto","start_hyperspace_challenge","claim_hyperspace","advance_after_clear","clear_level","upgrade_slot","upgrade_equipment_batch","upgrade_enhancement","set_speed","set_save_interval","check_timed_save","save_progress","assign_crew","toggle_loop","start","begin_retreat","acknowledge_unlocks","collect_uid","collect_near","chrono_affordable_seconds","set_onboarding_flag","read_tutorial_unlock","upgrade","upgrade_max","set_enhancement_branch","set_enhancement_order","set_field"]
func dispatch(name:String,args:Array)->Dictionary:
	var failure=validate_command(name,args)
	if not failure.is_empty():return {"accepted":false,"reason":failure}
	# enqueue_input detaches every array/dictionary and rejects objects/callbacks.
	# Display identities are never handed to a method expecting authoritative data.
	var sequence=mailbox.enqueue_input(name,args)
	if sequence<0:return {"accepted":false,"reason":"input_capacity_or_nonvalue_argument"}
	command_serial=sequence
	process_commands()
	var ack:Dictionary=command_acks.get(sequence,{"accepted":false,"reason":"command_still_pending","sequence":sequence})
	command_acks.erase(sequence)
	return ack
func validate_command(name:String,arguments:Array)->String:
	if not name in COMMANDS and not command_signatures.has(name):return "uncompiled_command"
	if name=="collect_uid":
		return "" if arguments.size()==2 and typeof(arguments[0])==TYPE_INT and typeof(arguments[1])==TYPE_BOOL else "invalid_collect_identity"
	if name=="set_field":
		if arguments.size()!=2:return "invalid_field_arguments"
		if str(arguments[0])=="paused":return "" if typeof(arguments[1])==TYPE_BOOL else "invalid_pause_value"
		return "uncompiled_field"
	if not command_signatures.has(name):return "missing_command_signature"
	var signature:Dictionary=command_signatures[name]
	var parameters:Array=signature.arguments
	if arguments.size()<parameters.size()-int(signature.defaults) or arguments.size()>parameters.size():return "invalid_argument_count"
	for index in arguments.size():
		var expected=int(parameters[index].type);var actual=typeof(arguments[index])
		if expected==TYPE_NIL:continue # Variant still passes mailbox value validation.
		if expected==TYPE_FLOAT and actual in [TYPE_INT,TYPE_FLOAT]:continue
		if actual!=expected:return "invalid_argument_type:"+str(index)
	return ""
func process_commands()->void:
	if command_queue_active:return
	command_queue_active=true
	for command in mailbox.drain_inputs():
		assert(int(command.sequence)==last_command_sequence+1)
		last_command_sequence=int(command.sequence)
		var arguments:Array=command.arguments.duplicate(true)
		var result:Variant=null;var accepted=true;var reason=""
		var failure=validate_command(str(command.name),arguments)
		if not failure.is_empty():accepted=false;reason=failure
		elif command.name=="collect_uid":
			var actual:Dictionary={}
			for drop in _kernel.drops:
				if int(drop.get("uid",-1))==int(arguments[0]):actual=drop;break
			if actual.is_empty():accepted=false;reason="retired_drop"
			else:_kernel.collect(actual,bool(arguments[1]))
		elif command.name=="set_field":
			if arguments.size()!=2 or not str(arguments[0]) in ["paused"]:accepted=false;reason="uncompiled_field"
			else:_kernel.set(str(arguments[0]),arguments[1])
		elif str(command.name).contains("."):
			var route=String(command.name).split(".")
			arguments.push_front(_kernel)
			result=_kernel.get(route[0]).callv(route[1],arguments)
		else:result=_kernel.callv(command.name,arguments)
		command_acks[int(command.sequence)]={"sequence":int(command.sequence),"accepted":accepted,"reason":reason,"result":encode(result),"authoritative_fields":{"paused":_kernel.paused,"speed":_kernel.speed},"applied_tick":logical_steps,"queued_us":int(command.queued_us),"ack_us":Time.get_ticks_usec()}
	command_queue_active=false

func metrics()->Dictionary:
	return {"logical_steps":logical_steps,"events":event_count,"event_backpressure":event_backpressure,"pending_events":pending_events.size(),"publication_us":publication_us,"configuration_version":configuration_version,"battle_thread_admission":false}
func close()->void:
	if _kernel.event.is_connected(capture_event):_kernel.event.disconnect(capture_event)
	_kernel.native_forget_observer(capture_event);_kernel.simulation_descriptor_publisher=Callable();_kernel.simulation_mutation_sink=Callable()
	mailbox.stop();pending_events.clear();shot_records.clear();entity_records.clear();geometry=null;_kernel=null

func event_packet(kind:String,payload:Dictionary)->Dictionary:
	# Discrete events carry event-time changes, not a full world snapshot. The
	# complete dynamic state is published once at the render boundary below.
	var packet={"fx_time":geometry.fx_time,"demo_time":geometry.demo_time,"orbit_elapsed":geometry.fleet_pose.orbit_elapsed,"fields":{},"profile_dynamic":{"enhancementAttacks":_kernel.profile.enhancementAttacks,"enhancementHits":_kernel.profile.enhancementHits},"enemy_changes":[],"weapon_states":{},"defense_states":{}}
	if kind in ["state","encounter","wave_clear","retreat","explode"]:
		for key in CORE_FIELDS:packet.fields[key]=_kernel.get(key)
	if kind in ["collect","jewel_pickup"]:packet.drops=encode(_kernel.drops)
	if kind=="hit":
		if bool(payload.get("player",false)):packet.player=encode(_kernel.player.duplicate())
		else:
			var record:Dictionary=entity_records.get(int(payload.uid),{}).get("record",{})
			if not record.is_empty():packet.enemy_changes.append({"token":entity_token(record),"hp":encode(record.hp),"shield":encode(record.get("shield",0)),"x":record.x,"y":record.y,"shield_hit_at":record.get("shield_hit_at",0),"shield_updated_at":record.get("shield_updated_at",0),"interference":record.get("interference",0)})
	for index in dirty_weapon_states:
		if not _kernel.enhancement_branches.weapons.has(index):continue
		var data=_kernel.enhancement_branches.weapons[index];var row={}
		for key in ["target","dwell","next","stacks","stack_time"]:row[key]=encode(data[key])
		packet.weapon_states[index]=row
	for index in dirty_defense_states:
		if not _kernel.enhancement_branches.defenses.has(index):continue
		var data=_kernel.enhancement_branches.defenses[index];var row={}
		for key in ["cover","cover_elapsed","cover_time","resistance_type","resistance_time","lockout"]:row[key]=encode(data[key])
		packet.defense_states[index]=row
	dirty_weapon_states.clear();dirty_defense_states.clear()
	if kind in ["fire","beam_started","beam_hit","projectile_impact"] and payload.has("shot"):
		packet.turrets=encode(geometry.turret_visuals);packet.turret_ship=geometry.turret_ship
	if configuration_dirty:
		configuration_version+=1;packet.configuration_version=configuration_version
		packet.configuration=_kernel.profile.duplicate(true);configuration_dirty=false
	return packet

func retired_shot_ids(active:PackedInt64Array)->PackedInt64Array:
	var present={};var result=PackedInt64Array()
	for identity in active:present[identity]=true
	for identity in shot_records:
		if not present.has(identity):result.append(int(identity))
	return result
func retire_entity_records()->void:
	# Monotonic Game UID is the generation for declared production births. No
	# old record graph is retained merely to remember its former UI descriptor.
	var required={}
	for enemy in _kernel.enemies:required[int(enemy.uid)]=true
	for shot in _kernel.projectiles:
		for key in ["target","source","locked_target"]:
			var record:Dictionary=shot.get(key,{})
			if record.has("uid"):required[int(record.uid)]=true
	for packet in _kernel.missile_queue:
		for key in ["target","source","locked_target"]:
			var record:Dictionary=packet.get(key,{})
			if record.has("uid"):required[int(record.uid)]=true
	for data in _kernel.enhancement_branches.weapons.values():
		var target:Dictionary=data.get("target",{})
		if target.has("uid"):required[int(target.uid)]=true
	for identity in entity_records.keys():
		if not required.has(identity):entity_records.erase(identity)
	if _kernel.simulation_bridge!=null:_kernel.simulation_bridge.retire_unreferenced(required)

func mark_state_changed(kind:String,index:int)->void:
	if kind=="weapon":dirty_weapon_states[index]=true
	elif kind=="defense":dirty_defense_states[index]=true
