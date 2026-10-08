extends RefCounted
## Exception to ordinary journey-only saves: a paid manual receipt owns a frozen main return.
const N=preload("res://scripts/growth_number.gd")
const C=preload("res://scripts/hyperspace_config.gd")
const VERSION=2
const Actors=preload("res://scripts/hyperspace_battle_return.gd")
static func schema()->Dictionary:
 var module={"key":"s","owner":"s"}
 var weapon=module.duplicate();weapon.merge({"next":"i","stacks":"i","stack_time":"n"})
 var defense=module.duplicate();defense.merge({"cover_elapsed":"n","cover_time":"n","cover":"g","resistance_type":"i","resistance_time":"n","lockout":"n"})
 return {"battle_json":"s","version":"i","paused":"b","armour":"g","shield":"g","since_hit":"n","clear_timer":"n","travel_origin_ready":"b","travel_origin":"n","run_resources":{"*":"g"},"cooldowns":{"*":{"key":"s","remaining":"n"}},"charged":{"*":{"key":"s","multiplier":"n"}},"defense_losses":{"*":{"key":"s","damage":"g","time":"n"}},"buffers":{"*":{"key":"s","amount":"g"}},"weapons":{"*":weapon},"defenses":{"*":defense},"incoming_sources":{"*":"i"},"memory_reduction_remaining":"n","clear_reduction_remaining":"n","enhancement_memory_elapsed":"n","enhancement_defense_time":"n","enhancement_deferred_elapsed":"n","enhancement_deferred_tick":"i","enhancement_deferred":{"*":{"shield":"g","armour":"g"}},"drone":{"disabled":["s"],"rebuild_bonus":"n","rebuild_stacks":"i","dodge_cooldown":"n","black_hole_elapsed":"n","black_hole_remaining":"n","black_hole_damage":"g","missile_attacks":"i"}}
static func shape(value,spec)->bool:
 if spec is String:
  if spec=="s":return value is String
  if spec=="b":return value is bool
  if spec=="g":return N.valid(value)
  if spec=="i":return C.integer(value) and value>=0
  return C.number(value) and value>=0
 if spec is Array:return value is Array and value.all(func(item):return shape(item,spec[0]))
 if not value is Dictionary:return false
 if spec.has("*"):
  for key in value:
   if not key is String or not shape(value[key],spec["*"]):return false
 else:
  if value.size()!=spec.size():return false
  for key in spec:
   if not value.has(key) or not shape(value[key],spec[key]):return false
 return true
static func valid(state:Dictionary,journey:Dictionary,max_stage:int)->bool:
 var spec:=schema()
 if state.get("version")==1:spec.erase("battle_json")
 if not shape(state,spec) or int(state.version) not in [1,VERSION]:return false
 if state.version==VERSION and not Actors.valid(state.battle_json):return false
 if state.version==1 and (not C.integer(journey.get("state")) or int(journey.state) not in [0,1,2,4,6] or journey.get("loop")!=false or not journey.get("pendingUnlocks") is Array or not journey.pendingUnlocks.is_empty()):return false
 for key in ["stage","groupIndex","state"]:
  if not C.integer(journey.get(key)):return false
 if journey.stage<1 or journey.stage>max_stage or journey.groupIndex<0 or not int(journey.state) in [0,1,2,3,4,5,6,7]:return false
 if not C.number(journey.get("distance")) or journey.distance<0 or not journey.get("loop") is bool or not journey.get("pendingUnlocks") is Array or not journey.pendingUnlocks.all(func(key):return key is String):return false
 for key in ["guardArrived","retreatBossPending"]:
  if not journey.get(key) is bool:return false
 for key in ["defense_losses","buffers","weapons","defenses","enhancement_deferred"]:
  for index in state[key]:
   if not index.is_valid_int() or str(int(index))!=index or int(index)<0:return false
 for index in state.enhancement_deferred:
  if int(index)<=int(state.enhancement_deferred_tick):return false
 for data in state.defenses.values():
  if not int(data.resistance_type) in [0,1,2]:return false
 return state.run_resources.keys().all(func(key):return key in ["1","2"])
static func binding_valid(point:Dictionary,profile:Dictionary,data:Dictionary)->bool:
 var index=int(point.get("stage",0))-1;var levels:Array=data.get("levels",[])
 if index<0 or index>=levels.size() or index+1>int(profile.get("highestLevel",1)):return false
 var row:Dictionary=levels[index]
 if float(point.distance)>float(row.length) or int(point.groupIndex)>row.groups.size():return false
 if int(point.state)==4 and (int(point.groupIndex)!=row.groups.size() or not profile.get("cleared",[]).any(func(level):return C.integer(level) and int(level)==index+1)):return false
 return true
static func journey(g)->Dictionary:
 return {"stage":g.stage,"distance":g.distance,"groupIndex":g.group_index,"state":int(g.state),"guardArrived":g.guard_arrived,"retreatBossPending":g.retreat_boss_pending,"pendingUnlocks":g.pending_unlocks.duplicate(),"loop":g.profile.loop}
static func capture(g)->Dictionary:
 var out={"battle_json":Actors.capture(g),"version":VERSION,"paused":g.paused,"armour":g.player.armour,"shield":g.player.shield,"since_hit":g.since_hit,"clear_timer":maxf(0.0,g.clear_timer) if is_finite(g.clear_timer) else g.clear_timer,"travel_origin_ready":is_finite(g.travel_origin),"travel_origin":g.travel_origin if is_finite(g.travel_origin) else 0.0,"run_resources":g.run_resources.duplicate(true),"cooldowns":{},"charged":{},"defense_losses":{},"buffers":{},"weapons":{},"defenses":{},"incoming_sources":{},"enhancement_deferred":{},"drone":{}}
 for index in g.combat_weapon_entries().size():
  var entry=g.combat_entry(index);var owner=g.slot_id("weapons",index)
  if g.cooldowns.has(owner):out.cooldowns[owner]={"key":str(entry.key),"remaining":g.cooldowns[owner]}
  if g.jewel_charged.has(owner):out.charged[owner]={"key":str(entry.key),"multiplier":g.jewel_charged[owner]}
 for index in g.defense_entries().size():
  var entry=g.slot_entry("defence",index)
  out.defense_losses[str(index)]={"key":str(entry.key),"damage":g.jewel_defence_damage.get(index,0.0),"time":g.jewel_defence_times.get(index,g.since_hit)}
 for index in g.enhancement_buffers:
  var entry=g.slot_entry("defence",int(index))
  if not entry.is_empty():out.buffers[str(index)]={"key":str(entry.key),"amount":g.enhancement_buffers[index]}
 for pair in [["weapons",g.enhancement_branches.weapons],["defenses",g.enhancement_branches.defenses]]:
  for index in pair[1]:
   var source:Dictionary=pair[1][index];var data:Dictionary=source.duplicate();data.erase("entry");data.erase("target");data.erase("dwell")
   data.key=str(source.entry.key);data.owner=g.slot_id("weapons" if pair[0]=="weapons" else "defence",int(index));out[pair[0]][str(index)]=data
 for index in g.enhancement_branches.incoming_sources:out.incoming_sources[str(index)]=g.enhancement_branches.incoming_sources[index]
 for key in ["memory_reduction_remaining","clear_reduction_remaining"]:out[key]=g.enhancement_branches.get(key)
 for key in ["enhancement_memory_elapsed","enhancement_defense_time","enhancement_deferred_elapsed","enhancement_deferred_tick"]:out[key]=g.get(key)
 for index in g.enhancement_deferred:out.enhancement_deferred[str(index)]=g.enhancement_deferred[index].duplicate(true)
 for key in schema().drone:out.drone[key]=g.drone_combat.get(key)
 return out.duplicate(true)
static func restore(g,saved:Dictionary,point:Dictionary)->void:
 # No start()/spawn_group(): completed main actors stay dead. Global serials/RNG/economy keep advancing.
 g.stage=int(point.stage);g.distance=float(point.distance);g.group_index=int(point.groupIndex);g.profile.loop=bool(point.loop)
 g.guard_arrived=bool(point.guardArrived);g.retreat_boss_pending=bool(point.retreatBossPending);g.pending_unlocks.assign(point.pendingUnlocks)
 g.enemies.clear();g.projectiles.clear()
 if g.get("missile_queue") is Array:g.get("missile_queue").clear()
 g.reset_player();g.drone_combat.reset()
 g.state=int(point.state);g.paused=bool(saved.paused);g.clear_timer=float(saved.clear_timer);g.cooldowns.clear()
 if g.state==g.State.TRAVEL:
  for index in g.combat_weapon_entries().size():
   var entry=g.combat_entry(index)
   if not str(entry.key).is_empty():
    var cd=float(g.player_weapon_row(entry).cd)
    if cd>0:g.cooldowns[g.slot_id("weapons",index)]=cd
 g.travel_origin=float(saved.travel_origin) if saved.travel_origin_ready else INF
 g.run_resources=saved.run_resources.duplicate(true)
 for key in schema().drone:g.drone_combat.set(key,saved.drone[key].duplicate() if saved.drone[key] is Array else saved.drone[key])
 g.drone_combat.disabled=g.drone_combat.disabled.filter(func(id):return g.profile.hyperspace.inventory.equipped.has(id))
 g.invalidate_stat_cache();g.player.armour=N.minimum(saved.armour,g.stat("armour"));g.player.shield=N.minimum(saved.shield,g.max_shield());g.since_hit=float(saved.since_hit)
 g.refit_health_ratios={"armour":N.ratio(g.player.armour,N.maximum(0.001,g.stat("armour"))),"shield":N.ratio(g.player.shield,N.maximum(0.001,g.max_shield()))}
 for index in g.combat_weapon_entries().size():
  var entry=g.combat_entry(index);var owner=g.slot_id("weapons",index)
  if saved.cooldowns.has(owner) and saved.cooldowns[owner].key==entry.key:g.cooldowns[owner]=float(saved.cooldowns[owner].remaining)
  if saved.charged.has(owner) and saved.charged[owner].key==entry.key:g.jewel_charged[owner]=float(saved.charged[owner].multiplier)
 for key in saved.defense_losses:
  var index=int(key);var entry=g.slot_entry("defence",index)
  if not entry.is_empty() and entry.key==saved.defense_losses[key].key:
   g.jewel_defence_damage[index]=saved.defense_losses[key].damage;g.jewel_defence_times[index]=float(saved.defense_losses[key].time)
 for key in saved.buffers:
  var index=int(key);var entry=g.slot_entry("defence",index)
  if not entry.is_empty() and entry.key==saved.buffers[key].key:
   g.enhancement_buffers[index]=saved.buffers[key].amount;g.enhancement_buffer_owners[index]={"entry":entry,"key":str(entry.key)}
 for pair in [["weapons",g.enhancement_branches.weapons],["defenses",g.enhancement_branches.defenses]]:
  for key in saved[pair[0]]:
   var index=int(key);var data:Dictionary=saved[pair[0]][key].duplicate();var entry=g.combat_entry(index) if pair[0]=="weapons" else g.slot_entry("defence",index)
   if entry.is_empty() or entry.key!=data.key or data.owner!=g.slot_id("weapons" if pair[0]=="weapons" else "defence",index):continue
   data.erase("key");data.erase("owner");data.entry=entry
   if pair[0]=="weapons":data.target={};data.dwell=0.0
   pair[1][index]=data
 for key in saved.incoming_sources:g.enhancement_branches.incoming_sources[int(key)]=int(saved.incoming_sources[key])
 for key in ["memory_reduction_remaining","clear_reduction_remaining"]:g.enhancement_branches.set(key,float(saved[key]))
 for key in ["enhancement_memory_elapsed","enhancement_defense_time","enhancement_deferred_elapsed"]:g.set(key,float(saved[key]))
 g.enhancement_deferred_tick=int(saved.enhancement_deferred_tick)
 for key in saved.enhancement_deferred:g.enhancement_deferred[int(key)]=saved.enhancement_deferred[key].duplicate(true)
 g.sync_jewel_defence_damage();g.enhancement_branches.reconcile(g);g.sync_enhancement_buffers();g.save_dirty=true
 if saved.get("version")==VERSION:Actors.restore(g,saved.battle_json)
 g.event.emit("state",{"state":g.state})
