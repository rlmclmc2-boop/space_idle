extends RefCounted
const N=preload("res://scripts/growth_number.gd")
var weapons: Dictionary={}
var defenses: Dictionary={}
var incoming_sources: Dictionary={}
var memory_reduction_remaining := 0.0
var clear_reduction_remaining := 0.0

func reset() -> void:
 weapons.clear();defenses.clear();incoming_sources.clear()
 memory_reduction_remaining=0.0;clear_reduction_remaining=0.0

func category(effect: String) -> String:
 return "weapons" if effect in ["proficiency","repeat","critical"] else "defence"

func active(g, entry: Dictionary, effect: String, node: int, choice: String) -> bool:
 # A missing/different choice cannot be active; avoid resolving unlock tables
 # and constructing effect dictionaries for that overwhelmingly common case.
 if entry.is_empty() or g.enhancement_branch_choice(category(effect),effect,node)!=choice or not g.enhancement_branch_unlocked(category(effect),effect,node):return false
 return g.has_enhancement_effect(entry,effect)

func global_active(g,effect: String,node: int,choice: String) -> bool:
 return g.defense_entries().any(func(entry):return active(g,entry,effect,node,choice))

func a_count(g,entry: Dictionary,effect: String) -> int:
 var count := 0
 for node in [1,2,3]:
  if active(g,entry,effect,node,"A"):count+=1
 return count

func weapon(g,index: int) -> Dictionary:
 var entry: Dictionary=g.slot_entry("weapons",index)
 if not weapons.has(index) or not is_same(weapons[index].entry,entry):
  weapons[index]={"entry":entry,"target":{},"dwell":0.0,"next":0,"stacks":0,"stack_time":0.0}
 return weapons[index]

func defense(g,index: int) -> Dictionary:
 var entry: Dictionary=g.slot_entry("defence",index)
 if not defenses.has(index) or not is_same(defenses[index].entry,entry):
  defenses[index]={"entry":entry,"cover_elapsed":0.0,"cover_time":0.0,"cover":0.0,"resistance_type":0,"resistance_time":0.0,"lockout":0.0}
 return defenses[index]

func reconcile(g) -> void:
 # Eligibility is shared by every module in this synchronous reconciliation.
 # Resolve common choices/gates once here; retain no state across calls/ticks.
 var weapon_ready={}
 var weapon_order: Array=g.profile.enhancementOrder.get("weapons",[])
 var proficiency_index:=weapon_order.find("proficiency")
 var critical_index:=weapon_order.find("critical")
 if not weapons.is_empty():
  for pair in [["proficiency",1],["critical",1],["critical",2]]:
   weapon_ready[str(pair[0])+str(pair[1])]=g.enhancement_branch_choice("weapons",pair[0],pair[1])=="B" and g.enhancement_branch_unlocked("weapons",pair[0],pair[1])
 for index in weapons.keys():
  if int(index)>=g.weapon_entries().size():weapons.erase(index);continue
  var data: Dictionary=weapon(g,int(index));var entry: Dictionary=data.entry
  var count: int=g.active_enhancement_effect_count(entry) if str(entry.get("key","")) in g.WEAPON_KEYS and (weapon_ready.proficiency1 or weapon_ready.critical1 or weapon_ready.critical2) else 0
  var proficiency_active:=proficiency_index>=0 and proficiency_index<count
  var critical_active:=critical_index>=0 and critical_index<count
  if not weapon_ready.proficiency1 or not proficiency_active:data.target={};data.dwell=0.0
  if not weapon_ready.critical1 or not critical_active:data.next=0
  if not weapon_ready.critical2 or not critical_active:data.stacks=0;data.stack_time=0.0
 var defense_ready={}
 for pair in [["adaptation",2],["memory_material",2],["memory_material",1],["delayed_damage",1],["adaptation",1]]:
  defense_ready[str(pair[0])+str(pair[1])]=g.enhancement_branch_choice("defence",pair[0],pair[1])=="B" and g.enhancement_branch_unlocked("defence",pair[0],pair[1])
 for index in defenses.keys():
  if int(index)>=g.defense_entries().size():defenses.erase(index);continue
  var data: Dictionary=defense(g,int(index));var entry: Dictionary=data.entry
  if not defense_ready.adaptation2 or not g.has_enhancement_effect(entry,"adaptation"):data.cover=0.0;data.cover_time=0.0;data.cover_elapsed=0.0
  if not defense_ready.memory_material2 or not g.has_enhancement_effect(entry,"memory_material"):data.resistance_type=0;data.resistance_time=0.0;data.lockout=0.0
 if not defense_ready.memory_material1 or not g.defense_entries().any(func(entry):return g.has_enhancement_effect(entry,"memory_material")):memory_reduction_remaining=0.0
 if not defense_ready.delayed_damage1 or not g.defense_entries().any(func(entry):return g.has_enhancement_effect(entry,"delayed_damage")):clear_reduction_remaining=0.0
 if not defense_ready.adaptation1 or not g.defense_entries().any(func(entry):return g.has_enhancement_effect(entry,"adaptation")):incoming_sources.clear()

func advance_weapons(g,dt: float) -> void:
 reconcile(g)
 for index in g.weapon_entries().size():
  var data:=weapon(g,index)
  var before_stacks:=int(data.stacks)
  var interval: float=g.enhancement_parameter("proficiency_b1_interval")
  var before_focus:=int(floor(float(data.dwell)/interval))
  data.stack_time=maxf(0.0,float(data.stack_time)-dt)
  if data.stack_time<=0.000000001:data.stacks=0;data.stack_time=0.0
  if g.state==g.State.COMBAT and not data.target.is_empty() and g.enemies.has(data.target) and data.target.hp>0 and active(g,data.entry,"proficiency",1,"B"):
   data.dwell+=dt
  else:data.target={};data.dwell=0.0
  if before_stacks!=int(data.stacks) or before_focus!=int(floor(float(data.dwell)/interval)):
   g.invalidate_equipment_counter(str(data.entry.get("key","")))
   # Timed bonuses remain combat-only; module presentation has no dependency.

func begin_attack(g,index: int,target: Dictionary,derived := false,track_primary := true) -> Dictionary:
 var data:=weapon(g,index)
 if not derived and track_primary and not is_same(data.target,target):data.target=target;data.dwell=0.0
 var boost := 1.0
 if not derived and int(data.next)>0 and active(g,data.entry,"critical",1,"B"):
  boost+=g.enhancement_parameter("critical_b1_damage_bonus");data.next-=1
 return {"index":index,"primary":target,"derived":derived,"next_multiplier":boost,"critical":false}

func finish_attack(g,context: Dictionary) -> void:
 if context.get("derived",false) or not context.get("critical",false):return
 var data:=weapon(g,int(context.index))
 if active(g,data.entry,"critical",1,"B"):data.next=int(g.enhancement_parameter("critical_b1_attacks"))
 if active(g,data.entry,"critical",2,"B"):
  data.stacks=mini(int(g.enhancement_parameter("critical_b2_stacks")),int(data.stacks)+1)
  data.stack_time=g.enhancement_parameter("critical_b2_duration")
 g.invalidate_equipment_counter(str(data.entry.get("key","")))


func weapon_multiplier(g,entry: Dictionary,original_entry: Dictionary={},include_timed_buffs := true) -> Variant:
 var result = 1.0+float(a_count(g,entry,"proficiency"))*g.enhancement_parameter("proficiency_a_damage_bonus")
 if not include_timed_buffs:return result
 var owner: Dictionary=entry if original_entry.is_empty() else original_entry
 var index: int=g.weapon_entries().find_custom(func(candidate):return is_same(candidate,owner))
 if index<0:return result
 var data:=weapon(g,index)
 if active(g,entry,"proficiency",1,"B"):
  var jumps:=int(floor(float(data.dwell)/g.enhancement_parameter("proficiency_b1_interval")))
  result=N.multiply(result,N.power(1.0+g.enhancement_parameter("proficiency_b1_growth"),jumps))
 if active(g,entry,"critical",2,"B"):result=N.multiply(result,1.0+int(data.stacks)*g.enhancement_parameter("critical_b2_damage_bonus"))
 return result

func capacity_multiplier(g,entry: Dictionary) -> float:
 return 1.0+float(a_count(g,entry,"adaptation"))*g.enhancement_parameter("adaptation_a_capacity_bonus")

func cooldown_multiplier(g,entry: Dictionary) -> float:
 return g.enhancement_parameter("proficiency_b2_interval_multiplier") if active(g,entry,"proficiency",2,"B") else 1.0

func repeat_probability(g,entry: Dictionary) -> float:
 return clampf(g.enhancement_parameter("repeat_probability")+float(a_count(g,entry,"repeat"))*g.enhancement_parameter("repeat_a_probability"),0,1)

func underlying_critical_rate(g,entry: Dictionary,include_timed_buffs := true) -> float:
 var row: Dictionary=g.db.equip(str(entry.key),int(entry.level))
 var rate: float=g.enhancement_parameter("base_critical_rate")+float(row.get("cri",0))+float(a_count(g,entry,"critical"))*g.enhancement_parameter("critical_a_probability")
 var index: int=g.weapon_entries().find_custom(func(candidate):return is_same(candidate,entry))
 if include_timed_buffs and index>=0 and active(g,entry,"critical",2,"B"):rate+=int(weapon(g,index).stacks)*g.enhancement_parameter("critical_b2_probability")
 return clampf(rate,0,1)

func resistance(g,entry: Dictionary,base: float) -> float:
 # Existing matching resistance may be raised; neutral layers never gain one.
 if base>0 and active(g,entry,"adaptation",3,"B"):base+=g.enhancement_parameter("adaptation_b3_resistance_bonus")
 return clampf(base,0,1)

func memory_cap_multiplier(g,entry: Dictionary) -> float:
 var multiplier: float=1.0+a_count(g,entry,"memory_material")*g.enhancement_parameter("memory_a_bonus")
 if active(g,entry,"memory_material",3,"B"):
  multiplier+=g.equipment_count("armour")*g.enhancement_parameter("memory_b3_armour_capacity_bonus")
 return multiplier

func memory_heal_multiplier(g,entry: Dictionary) -> float:
 return 1.0+a_count(g,entry,"memory_material")*g.enhancement_parameter("memory_a_bonus")

func memory_charge_multiplier(g,entry: Dictionary) -> float:
 var multiplier:=memory_heal_multiplier(g,entry)
 if active(g,entry,"memory_material",3,"B"):multiplier+=g.equipment_count("shield")*g.enhancement_parameter("memory_b3_shield_charge_bonus")
 return multiplier

func clear_underlying_probability(g,prospective_node := -1,prospective_choice := "") -> float:
 var chance: float=g.enhancement_parameter("deferred_clear_probability")
 for node in [1,2,3]:
  var selected := global_active(g,"delayed_damage",node,"A")
  if node==prospective_node and g.enhancement_branch_unlocked("defence","delayed_damage",node):selected=prospective_choice=="A" and g.defense_entries().any(func(entry):return g.enhancement_effects(entry).any(func(effect):return effect.kind=="delayed_damage"))
  if selected:chance+=g.enhancement_parameter("deferred_a_clear_probability")
 return clampf(chance,0,1)

func clear_probability(g) -> float:
 if global_active(g,"delayed_damage",3,"B"):return g.enhancement_parameter("deferred_b3_forced_probability")
 if global_active(g,"delayed_damage",2,"B"):return 0.0
 return clear_underlying_probability(g)

func incoming_multiplier(g,source_uid: int) -> float:
 var multiplier:=1.0
 var chance:=clear_underlying_probability(g)
 if global_active(g,"delayed_damage",2,"B"):multiplier*=1.0-chance*g.enhancement_parameter("deferred_b2_probability_conversion")
 if global_active(g,"delayed_damage",3,"B"):multiplier*=1.0+(1.0-chance)*g.enhancement_parameter("deferred_b3_damage_scale")
 if memory_reduction_remaining>0 and global_active(g,"memory_material",1,"B"):multiplier*=1.0-g.enhancement_parameter("memory_b1_reduction")
 if clear_reduction_remaining>0 and global_active(g,"delayed_damage",1,"B"):multiplier*=1.0-g.enhancement_parameter("deferred_b1_reduction")
 if source_uid>0 and global_active(g,"adaptation",1,"B"):
  multiplier*=maxf(0.0,1.0-int(incoming_sources.get(source_uid,0))*g.enhancement_parameter("adaptation_b1_reduction"))
  incoming_sources[source_uid]=mini(int(g.enhancement_parameter("adaptation_b1_stacks")),int(incoming_sources.get(source_uid,0))+1)
 return multiplier

func memory_incoming(g,type: int) -> void:
 for index in g.defense_entries().size():
  var entry: Dictionary=g.slot_entry("defence",index)
  if not active(g,entry,"memory_material",2,"B"):continue
  var data:=defense(g,index)
  if data.lockout>0:continue
  if data.resistance_time>0 and int(data.resistance_type)!=type:
   data.resistance_type=0;data.resistance_time=0.0;data.lockout=g.enhancement_parameter("memory_b2_lockout")
  elif type in [1,2]:
   data.resistance_type=type;data.resistance_time=g.enhancement_parameter("memory_b2_duration")

func memory_resistance(g,index: int,type: int) -> float:
 var entry: Dictionary=g.slot_entry("defence",index);var data:=defense(g,index)
 if not active(g,entry,"memory_material",2,"B") or data.lockout>0 or data.resistance_time<=0 or int(data.resistance_type)!=type:return 0.0
 return resistance(g,entry,g.enhancement_parameter("memory_b2_resistance"))

func advance_defense(g,dt: float) -> void:
 reconcile(g)
 memory_reduction_remaining=maxf(0.0,memory_reduction_remaining-dt)
 clear_reduction_remaining=maxf(0.0,clear_reduction_remaining-dt)
 for source in incoming_sources.keys():
  if not g.enemies.any(func(enemy):return int(enemy.get("uid",0))==int(source) and enemy.hp>0):incoming_sources.erase(source)
 for index in g.defense_entries().size():
  var entry: Dictionary=g.slot_entry("defence",index);var data:=defense(g,index)
  data.resistance_time=maxf(0.0,float(data.resistance_time)-dt)
  data.lockout=maxf(0.0,float(data.lockout)-dt)
  if data.resistance_time<=0:data.resistance_type=0
  data.cover_time=maxf(0.0,float(data.cover_time)-dt)
  if data.cover_time<=0:data.cover=0.0
  if active(g,entry,"adaptation",2,"B"):
   data.cover_elapsed+=dt
   var interval: float=g.enhancement_parameter("adaptation_b2_interval")
   if data.cover_elapsed+0.000000001>=interval:
    data.cover_elapsed=fmod(float(data.cover_elapsed),interval)
    data.cover_time=g.enhancement_parameter("adaptation_b2_duration")
    data.cover=N.multiply(N.add(g.jewel_equipment_stat(entry),g.enhancement_module_protection_capacity(index)),g.enhancement_parameter("adaptation_b2_capacity_multiplier"))

func consume_cover(g,amount) -> Variant:
 var rest=amount
 for index in g.defense_entries().size():
  var data:=defense(g,index)
  var consumed=N.minimum(data.cover,rest);data.cover=N.subtract(data.cover,consumed);rest=N.subtract(rest,consumed)
  if N.compare(rest,0)<=0:break
 return rest

func recovery_pulse(g,positive: bool) -> void:
 if positive and global_active(g,"memory_material",1,"B") and g.rng.randf()<g.enhancement_parameter("memory_b1_probability"):
  memory_reduction_remaining=g.enhancement_parameter("memory_b1_duration")

func cleared(g) -> void:
 if global_active(g,"delayed_damage",1,"B"):clear_reduction_remaining=g.enhancement_parameter("deferred_b1_duration")
