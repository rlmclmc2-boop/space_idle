extends RefCounted
## Cold import of the currently supported native contract into the SAME Game.
## Preparation does not advance, settle, reroll, spend, emit, or mutate live views.
var state:Dictionary
var patches:Array=[]
var shots:Array[Dictionary]=[]
var missile_queue:Array[Dictionary]=[]
var repeats:Array[Dictionary]=[]
var cooldowns:Dictionary={}
var enemy_cooldowns:Array=[]
var snapshots:Dictionary={}
var instances:Dictionary={}
var flight_by_handle:Dictionary={}
var error:=""

func entry_for(game,weapon:Dictionary)->Dictionary:
	return state.enemies[int(weapon.source)].equipment[int(weapon.slot)] if bool(weapon.hostile) else game.combat_entry(int(weapon.slot))
func bind_snapshot(raw:Dictionary,game,weapon:Dictionary)->Dictionary:
	var id=int(raw.id)
	if snapshots.has(id):return snapshots[id]
	var row=raw.duplicate()
	row.effects=raw.effects.duplicate(true)
	for effect in row.effects:
		effect.source=int(weapon.slot);effect.weapon_key=str(weapon.entry.get("key",weapon.row.get("name","")));effect.main_attack_id=id
	row.combat_context=game.CombatContext.root(id,"enemy:"+str(state.enemies[int(weapon.source)].uid) if bool(weapon.hostile) else "drone:"+str(weapon.entry.drone_id) if weapon.entry.has("drone_id") else "module:%d"%int(weapon.slot),str(weapon.entry.get("key",weapon.row.get("name",""))))
	snapshots[id]=row
	return row
func bind_instance(raw:Dictionary,snapshot:Dictionary,game)->Dictionary:
	var id=int(raw.id)
	if instances.has(id):return instances[id]
	var row=raw.duplicate();row.chain=raw.chain.duplicate()
	# Link objects remain the same target identities; mutable used/broken state
	# is copied once into the new owner, not deep-copied per carrier.
	row.chain.links=[]
	for link in raw.chain.get("links",[]):row.chain.links.append(link.duplicate())
	if game.compiled_combat_rules!=null:game.compiled_combat_rules.bind_instance(snapshot,row)
	else:
		row.effects=[]
		for source in snapshot.effects:
			var effect=source.duplicate()
			if effect.get("chain",false):effect.chain_state=row.chain
			row.effects.append(effect)
	instances[id]=row
	return row
func context(snapshot:Dictionary,derived:bool,game)->Dictionary:
	return game.CombatContext.derive(snapshot.combat_context,"native_committed_derived") if derived else snapshot.combat_context
func attack(snapshot:Dictionary,instance:Dictionary,multiplier:float,derived:bool,game)->Dictionary:
	return {"damage":float(snapshot.damage)*multiplier,"effects":instance.effects,"critical":snapshot.critical,"critical_bonus_applied":snapshot.critical_bonus_applied,"main_attack_id":snapshot.id,"attack_instance_id":instance.id,"combat_context":context(snapshot,derived,game)}
func prepare(game,session,snapshot:Dictionary)->bool:
	state=snapshot
	if state.is_empty() or int(state.get("schema",0))!=1:error="invalid_native_handoff_schema";return false
	if not is_finite(float(state.clock)):error="invalid_native_handoff_clock";return false
	var weapons:Array=session.weapons
	for enemy in state.enemies:enemy_cooldowns.append(enemy.get("cooldowns",[]).duplicate())
	for pending in state.cooldowns:
		var weapon:Dictionary=weapons[int(pending.weapon_index)]
		if bool(weapon.hostile):enemy_cooldowns[int(weapon.source)][int(weapon.slot)]=float(pending.remaining)
		else:cooldowns[game.slot_id("weapons",int(weapon.slot))]=float(pending.remaining)
	for native in state.flights:
		var weapon:Dictionary=weapons[int(native.weapon_index)]
		var root=bind_snapshot(native.snapshot,game,weapon)
		var instance=bind_instance(native.instance,root,game)
		var view:Dictionary=native.view
		var patch={"x":native.position.x,"y":native.position.y,"direction":native.direction,"speed":native.speed,"damage":native.damage,"entry":entry_for(game,weapon),"source":state.enemies[int(weapon.source)] if bool(weapon.hostile) else state.player,"source_uid":int(state.enemies[int(weapon.source)].uid) if bool(weapon.hostile) else 0,"main_attack_id":root.id,"attack_instance_id":instance.id,"attack_instance":instance,"attack_snapshot":root,"jewelEffects":instance.effects,"critical_bonus_applied":root.critical_bonus_applied,"combat_context":context(root,bool(native.instance_derived) or bool(native.chain),game)}
		if bool(native.beam):
			patch.elapsed=native.age;patch.ticks=native.ticks;patch.charge=native.charge;patch.next_hit_at=native.next_hit
			patch.repeat_multiplier=native.multiplier;patch.repeat_origin_multiplier=1.0;patch.repeat_depth=1 if bool(native.repeated) else 0
			patch.weapon=root.weapon;patch.charged_multiplier=1.0
			patch.locked_target=view.target
		if view.get("prototype_missile",false):
			patch.motion_age=native.motion_age;patch.orphan_age=native.orphan_age;patch.last_target_point=native.last_aim;patch.cruise_speed=native.cruise_speed
			patch.closest_range=INF;patch.ignition_at=game.MISSILE_IGNITION;patch.seek_at=game.MISSILE_SEEK_START;patch.cruise_at=game.MISSILE_CRUISE_AT
		patches.append({"view":view,"values":patch});shots.append(view)
		flight_by_handle["%d:%d"%[native.native_index,native.native_generation]]=view
	for native in state.ejections:
		var weapon:Dictionary=weapons[int(native.weapon_index)]
		var root=bind_snapshot(native.snapshot,game,weapon)
		if native.instance.is_empty():error="missing_ejection_shared_instance";return false
		var instance=bind_instance(native.instance,root,game)
		missile_queue.append({"mount":int(weapon.slot),"entry":entry_for(game,weapon),"source":state.player,"target":native.target,"aim":Vector2(native.target.get("x",0),native.target.get("y",0)),"weapon":root.weapon,"attack":attack(root,instance,float(native.multiplier),bool(native.get("derived",false)),game),"offset":game.player_weapon_offset(int(weapon.slot)),"spread":game.missile_visual_spread(int(native.ordinal),int(weapon.salvo)),"ordinal":int(native.ordinal),"count":int(weapon.salvo),"due":float(native.due)})
	for native in state.repeats:
		var weapon:Dictionary=weapons[int(native.weapon_index)]
		var root=bind_snapshot(native.snapshot,game,weapon)
		var pending={"index":int(weapon.slot),"entry":entry_for(game,weapon),"remaining":float(native.remaining),"multiplier":float(native.multiplier),"depth":1,"origin_multiplier":1.0,"snapshot":root,"execution":{"launched":false},"parent_execution":{}}
		if int(native.owner_index)>=0:pending.beam=flight_by_handle.get("%d:%d"%[native.owner_index,native.owner_generation],{})
		repeats.append(pending)
	return true
func commit_views(game)->void:
	for item in patches:item.view.merge(item.values,true)
	game.enemies=state.enemies;game.player=state.player
	game.enhancement_buffers=state.buffers;game.jewel_defence_damage=state.losses;game.jewel_defence_times=state.defence_times
	game.enhancement_deferred=state.deferred;game.since_hit=float(state.since_hit)
	game.enhancement_defense_time=float(state.defence_time);game.enhancement_memory_elapsed=float(state.memory_elapsed)
	game.enhancement_deferred_elapsed=float(state.deferred_elapsed);game.enhancement_deferred_tick=int(state.deferred_tick)
	game.enemy_shield_time=float(state.clock);game.motion_clock=float(state.clock)
	game.profile.enhancementAttacks=int(state.attack_counter);game.profile.enhancementHits=int(state.incoming_counter)
	game.projectile_serial=int(state.projectile_serial);game.main_attack_serial=int(state.attack_serial);game.attack_instance_serial=int(state.instance_serial);game.uid=int(state.drop_uid);game.rng=state.rng
	game.cooldowns=cooldowns
	for index in enemy_cooldowns.size():game.enemies[index].cooldowns=enemy_cooldowns[index]
	game.projectiles=shots;game.missile_queue=missile_queue;game.jewel_repeats=repeats
	game.refresh_missile_target_registry()
