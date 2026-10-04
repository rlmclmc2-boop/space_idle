extends RefCounted
## Explicit QA decisions from earned records/current feedback; each command costs one visible-page action.
const VERSION="hyperspace-player-v7-initial-visible-majority-stable-plan"
const Bag=preload("res://scripts/drone_inventory.gd")
const Permission=preload("res://scripts/hyperspace_permissions.gd")
var last_attempt:Dictionary={}
var manual_failures:Dictionary={}
var forge_at:Dictionary={}
var reserved_crew:=""
var last_reforge:=0
var reforge_since:=-1.0
var known_weapons:Array=[]
var wanted_weapons:Array=[]
var wanted_defences:Array=[]
var seen_encounter:=""
var encounter_plans:Dictionary={}
var pending_encounters:Dictionary={}
var encounter_failures:Dictionary={}
var encounter_started:=0.0
var wanted_weapon:=""
var weapon_losses:Dictionary={}
var last_weapon_change:=-1000.0
var last_galaxy_state:=""
var galaxy_needs_reserved_crew:=false
func observe_visible(g,scene,tutorials:Array,now:float)->Dictionary:
 if g.state!=g.State.COMBAT:return {}
 var visible:Array=[];var resist:Dictionary={1:0,2:0};var attacks:Dictionary={1:0,2:0};var repairs:=0
 for enemy in g.enemies:
  if g.N.compare(enemy.hp,0)<=0:continue
  var point:Vector2=scene.enemy_render_position(enemy)
  if not Rect2(Vector2.ZERO,scene.battle_clip.size).has_point(point):continue
  var global_point:Vector2=scene.battle_clip.get_global_transform_with_canvas()*point
  if not scene.get_viewport().get_visible_rect().has_point(global_point):continue
  var kind:int=int(enemy.get("shieldType",0)) if g.N.compare(enemy.get("shield",0),0)>0 else int(enemy.get("armourType",0))
  if resist.has(kind):resist[kind]+=1
  var status:Dictionary=scene.enemy_recognition.state(enemy,g.enemy_shield_time,g.paused,scene.enemy_pose(enemy))
  if bool(status.repair):repairs+=1
  var shown_attacks:Array=scene.enemy_attack_types(enemy)
  for attack_kind in shown_attacks:
   if attacks.has(int(attack_kind)):attacks[int(attack_kind)]+=1
  visible.append({"uid":enemy.uid,"resistance":kind,"shown_attacks":shown_attacks,"drawn_repair_modules":bool(status.repair)})
 if visible.is_empty():return {}
 var route:String=str(g.profile.hyperspace.active.get("route","")) if g.manual_hyperspace.active else "main"
 var encounter:String=str([g.profile.hyperspace.round_id,route,g.stage,g.group_index])
 for key in tutorials:
  if not known_weapons.has(str(key)):known_weapons.append(str(key))
 for entry in g.weapon_entries():
  if not known_weapons.has(str(entry.key)):known_weapons.append(str(entry.key))
 var allowed:Array=known_weapons.filter(func(key):return g.content_unlocked("equipment",str(key)))
 # A plan belongs to an observed battle point, not to its shrinking survivor list.
 if encounter_plans.has(encounter):
  var cached:Dictionary=encounter_plans[encounter]
  wanted_weapons=expanded_plan(cached.weapons,g.active_slot_count("weapons"))
  wanted_defences=expanded_plan(cached.defences,g.active_slot_count("defence"))
  if encounter==seen_encounter:return {}
  seen_encounter=encounter;encounter_started=now
  return {"encounter":encounter,"weapons":wanted_weapons.duplicate(),"defences":wanted_defences.duplicate(),"visible_only":cached.visible_only,"failures_seen":int(encounter_failures.get(encounter,0)),"reason":"Reuse remembered initial visible encounter plan; survivors or dropped shields do not change it"}
 if not pending_encounters.has(encounter):
  pending_encounters[encounter]={"actors":{},"last_arrival":now}
  seen_encounter=encounter;encounter_started=now
 var pending:Dictionary=pending_encounters[encounter]
 for actor in visible:
  if not pending.actors.has(str(actor.uid)):
   pending.actors[str(actor.uid)]=actor.duplicate(true);pending.last_arrival=now
 # Observe arrival for at least three X1 seconds without a newly visible actor.
 # Initial protection/repair evidence remains after deaths or shield loss.
 if now-float(pending.last_arrival)<3.0:return {}
 visible=pending.actors.values();resist={1:0,2:0};attacks={1:0,2:0};repairs=0
 for actor in visible:
  if resist.has(int(actor.resistance)):resist[int(actor.resistance)]+=1
  if bool(actor.drawn_repair_modules):repairs+=1
  for attack_kind in actor.shown_attacks:
   if attacks.has(int(attack_kind)):attacks[int(attack_kind)]+=1
 seen_encounter=encounter;encounter_started=now
 var higgs:=false
 var physical:String="missile" if visible.size()>=4 else "cannon"
 var energy:String="laser" if visible.size()>=4 else "longLaser"
 for id in g.profile.hyperspace.inventory.equipped:
  var d:Dictionary=g.profile.hyperspace.inventory.drones[id]
  if d.legendary and d.legendary_effect.get("effect_id")=="higgs_cannon":physical="missile";higgs=true
 if not allowed.has(physical):physical="cannon" if allowed.has("cannon") else "missile" if allowed.has("missile") else ""
 if not allowed.has(energy):energy="longLaser" if allowed.has("longLaser") else "laser" if allowed.has("laser") else ""
 wanted_weapons=[];wanted_defences=[]
 var mixed:bool=int(resist[1])>0 and int(resist[2])>0
 var physical_slots:int=clampi(roundi(float(g.active_slot_count("weapons")*int(resist[1]))/float(maxi(1,int(resist[1])+int(resist[2])))),1,g.active_slot_count("weapons")-1) if mixed else 0
 for index in g.active_slot_count("weapons"):
  var desired:String=physical if int(resist[1])>int(resist[2]) else energy if int(resist[2])>int(resist[1]) else physical if not physical.is_empty() else energy
  if mixed:desired=physical if index<physical_slots else energy
  # The permanent repair-module glyph is visible feedback; the unlocked beam tutorial teaches sustained damage.
  if repairs>0 and allowed.has("longLaser"):desired="longLaser"
  if desired.is_empty():desired=str(g.slot_entry("weapons",index).key)
  wanted_weapons.append(desired)
 for index in g.active_slot_count("defence"):
  var shield:bool=index>0 and g.content_unlocked("equipment","shield") and (int(attacks[1])>int(attacks[2]) or (int(attacks[1])==int(attacks[2]) and (int(attacks[1])==0 or index%2==1)))
  wanted_defences.append("shield" if shield else "armour")
 last_weapon_change=now
 encounter_plans[encounter]={"weapons":wanted_weapons.duplicate(),"defences":wanted_defences.duplicate(),"visible_only":visible.duplicate(true),"allowed":allowed.duplicate(),"growth":growth_stamp(g),"revision":0,"last_revision_failure":0,"higgs":higgs}
 pending_encounters.erase(encounter)
 return {"encounter":encounter,"visible_only":visible,"allowed_from_seen_tutorials_or_owned":allowed,"weapons":wanted_weapons.duplicate(),"defences":wanted_defences.duplicate(),"reason":"Freeze initial observed protection/attack/repair evidence after arrival; no within-wave survivor or shield-driven refit; native equipment page only"}
func expanded_plan(plan:Array,count:int)->Array:
 var result:Array=[]
 for index in count:result.append(plan[mini(index,plan.size()-1)] if not plan.is_empty() else "")
 return result
func growth_stamp(g)->String:
 var levels:Array=[]
 for category in ["weapons","defence"]:
  for index in g.active_slot_count(category):levels.append([category,index,g.slot_entry(category,index).level])
 return str(levels)
func failed_plan_alternative(plan:Dictionary)->Dictionary:
 var weapons:Array=plan.weapons.duplicate();var counts:Dictionary={1:0,2:0};var repair:=false
 for actor in plan.visible_only:
  if counts.has(int(actor.resistance)):counts[int(actor.resistance)]+=1
  repair=repair or bool(actor.drawn_repair_modules)
 var physical:Array=[];var energy:Array=[]
 for index in weapons.size():
  if str(weapons[index]) in ["missile","cannon"]:physical.append(index)
  if str(weapons[index]) in ["laser","longLaser"]:energy.append(index)
 # Repeated real defeat despite upgrades justifies one slot correction toward
 # the initially seen majority; do not discard both coverage types.
 if int(counts[1])>0 and int(counts[2])>0 and not physical.is_empty() and not energy.is_empty():
  var desired_physical:int=clampi(roundi(float(weapons.size()*int(counts[1]))/float(int(counts[1])+int(counts[2]))),1,weapons.size()-1)
  if physical.size()>desired_physical:
   var index:int=physical.back();weapons[index]=weapons[energy[0]]
   return {"weapons":weapons,"changed_slot":index,"reason":"Repeated defeat after earned upgrades: initially seen physical protection is the majority, add one energy slot while retaining physical coverage"}
  if physical.size()<desired_physical:
   var index:int=energy.back();weapons[index]=weapons[physical[0]]
   return {"weapons":weapons,"changed_slot":index,"reason":"Repeated defeat after earned upgrades: initially seen energy protection is the majority, add one physical slot while retaining energy coverage"}
 # A second bounded trial changes one burst/sustained weapon within its
 # observed damage family. A repair glyph keeps the taught sustained beam.
 for index in weapons.size():
  var current:String=str(weapons[index])
  var alternative:String={"missile":"cannon","cannon":"missile","laser":"longLaser","longLaser":"laser"}.get(current,"")
  if alternative.is_empty() or not plan.allowed.has(alternative):continue
  if repair and current=="longLaser":continue
  if alternative=="cannon" and bool(plan.get("higgs",false)):continue
  weapons[index]=alternative
  return {"weapons":weapons,"changed_slot":index,"reason":"Repeated defeat after further earned upgrades: try one known same-family burst/sustained alternative, keep the remaining stable plan"}
 return {}
func observe_failure(g,now:float)->Dictionary:
 if seen_encounter.is_empty():return {}
 var failed:String=seen_encounter
 encounter_failures[failed]=int(encounter_failures.get(failed,0))+1
 var feedback:Dictionary={"encounter":failed,"failures":encounter_failures[failed],"combat_observed_seconds":now-encounter_started,"reason":"Actual failed attempt; remembered plan is stable between failures"}
 if encounter_plans.has(failed):
  var plan:Dictionary=encounter_plans[failed];var growth:String=growth_stamp(g)
  if int(plan.revision)<2 and int(encounter_failures[failed])-int(plan.last_revision_failure)>=3 and growth!=str(plan.growth):
   var alternative:Dictionary=failed_plan_alternative(plan)
   if not alternative.is_empty():
    feedback.alternative=alternative;feedback.before_weapons=plan.weapons.duplicate();feedback.earned_growth_before=plan.growth;feedback.earned_growth_now=growth
    plan.weapons=alternative.weapons;plan.revision+=1;plan.last_revision_failure=encounter_failures[failed];plan.growth=growth
 pending_encounters.erase(failed);seen_encounter=""
 return feedback
func pick_crew(g)->String:
 if not reserved_crew.is_empty() and Permission.crew_available(g,reserved_crew):return reserved_crew
 for member in g.profile.crew:
  if Permission.crew_available(g,str(member.crewId)):reserved_crew=str(member.crewId);return reserved_crew
 return ""
func score(d:Dictionary)->float:
 var value:=float(d.level)*0.2+20.0*int(d.ultimate)+8.0*int(d.legendary)
 for a in d.affixes:
  value+=float(6-int(a.tier))*(2.0 if str(a.key) in ["global_damage","attack_speed","repeat_chance","chain_count"] else 1.0)
 return value
func equipped(g)->Array:
 var bag:Dictionary=g.profile.hyperspace.inventory
 var ids:Array=bag.warehouse.filter(func(id):return not bag.sealed.has(id))
 ids.sort_custom(func(a,b):return score(bag.drones[a])>score(bag.drones[b]) if score(bag.drones[a])!=score(bag.drones[b]) else str(a)<str(b))
 var chosen:Array=[]
 for id in ids:
  var trial:Array=chosen+[id]
  if Bag.equipment_valid(bag,trial,Permission.hull_capacity(g,g.hyperspace.config),g.hyperspace.config) and g.hyperspace.equipment_constraints(g,trial):chosen=trial
 return chosen
func keep(g)->Array:
 var bag:Dictionary=g.profile.hyperspace.inventory
 var ids:Array=bag.warehouse.duplicate()
 ids.sort_custom(func(a,b):return score(bag.drones[a])>score(bag.drones[b]) if score(bag.drones[a])!=score(bag.drones[b]) else str(a)<str(b))
 return ids.slice(0,Bag.retention_capacity(bag,g.hyperspace.config)+int(g.hyperspace.config.retention_capacity_gain))
func forge_request(g,id:String,op:String,args:Dictionary={})->Dictionary:
 var s:Dictionary=g.profile.hyperspace
 return {"round_id":int(s.round_id),"command_seq":int(s.command_seq),"drone_id":id,"operation":op,"expected_revision":int(s.inventory.drones[id].forge_revision),"args":args}
func forge_choice(g,id:String,op:String,args:Dictionary={})->Dictionary:
 var request:Dictionary=forge_request(g,id,op,args)
 var preview:Dictionary=g.hyperspace.preview_forge(g,request)
 return {"domain":true,"kind":"space_forge","request":request,"preview":preview} if str(preview.error).is_empty() else {}
func space_action(g,now:float)->Dictionary:
 if int(g.profile.highestLevel)<7:return {}
 var h=g.hyperspace;var s:Dictionary=g.profile.hyperspace;var bag:Dictionary=s.inventory
 if not s.active.is_empty():
  if s.active.status=="completed_pending" and Bag.has_space(bag,h.config):return {"domain":true,"kind":"space_claim","round":s.active.round_id,"run":s.active.run_id}
  if s.active.mode=="manual":return {}
 # Return only sealed drones whose real planet gate was regained in this run.
 for id in bag.sealed:
  if int(g.profile.highestLevel)>=int(bag.sealed[id]):return {"domain":true,"kind":"space_unseal","id":id}
 var chosen:Array=equipped(g)
 if chosen!=bag.equipped:return {"domain":true,"kind":"space_equip","ids":chosen}
 if chosen!=bag.favorites:return {"domain":true,"kind":"space_favorite","ids":chosen}
 if not chosen.is_empty() and (bag.presets.is_empty() or bag.presets[0].drone_ids!=chosen):return {"domain":true,"kind":"space_preset","ids":chosen}
 # Full storage clears only the least useful legally unprotected object, through dismantle.
 if not Bag.has_space(bag,h.config):
  var removable:Array=bag.warehouse.filter(func(id):return not Bag.protected(bag,id))
  removable.sort_custom(func(a,b):return score(bag.drones[a])<score(bag.drones[b]))
  for id in removable:
   var dismantle:Dictionary=forge_choice(g,id,"dismantle")
   if not dismantle.is_empty():return dismantle
  return {}
 for id in chosen:
  var d:Dictionary=bag.drones[id]
  if d.ultimate:continue
  var unlocked:Array=[]
  for key in h.config.hanging_modules:
   if s.hanging_modules[key].unlocked and int(g.profile.highestLevel)>=int(h.config.hanging_modules[key].unlock_stage):unlocked.append(key)
  var layout:Array=d.hangings.duplicate()
  for key in ["resource_collector","distributed_algorithm","extra_storage","hyperspace_charge","gem_refiner"]:
   if unlocked.has(key) and not layout.has(key) and layout.size()<int(d.hanging_slots):layout.append(key)
  if layout!=d.hangings:return {"domain":true,"kind":"space_hangings","id":id,"keys":layout}
  if now-float(forge_at.get(id,-1000.0))<300.0:continue
  var operations:Array=[]
  if d.affixes.size()<Bag.affix_limit(d,h.config):operations.append("add_affix")
  # T3 is a minimum planning goal after any reforge, never a cap or injected value.
  if int(bag.reforge_count)>0 and d.affixes.any(func(a):return not a.locked and int(a.tier)>3):
   if not d.omen:operations.append("enable_omen")
   operations.append("promote_affix")
  if int(d.hanging_slots)<Bag.hanging_limit(d,h.config) and not unlocked.is_empty():operations.append("add_hanging_slot")
  operations.append("modernize")
  if int(s.ultimate_cores)>0 and chosen.find(id)==0:operations.append("ultimate")
  for op in operations:
   var choice:Dictionary=forge_choice(g,id,str(op))
   if not choice.is_empty():return choice
 # Reallocation crosses pages through separate real commands, never a hidden cross-page action.
 if galaxy_needs_reserved_crew:
  if s.auto.enabled:return {"domain":true,"kind":"space_auto_pause","reason":"Six actual galaxy workers need the reserved exploration worker"}
  return {}
 # Storage/equipment/forge remain legal while pure-progress auto is active.
 if not s.active.is_empty():return {}
 # Enable pure-progress automation immediately after the first genuine record.
 if not s.auto.enabled:
  for route in h.config.routes:
   var recorded_level:=0
   for level in s.history.get(route,{}):
    if int(level)<=int(g.profile.highestLevel):recorded_level=maxi(recorded_level,int(level))
   var crew:String=pick_crew(g)
   if recorded_level>0 and not crew.is_empty():return {"domain":true,"kind":"space_auto","route":str(route),"level":recorded_level,"crew":crew}
 # Manual first victories must be earned. Inspect records only, not future opponents.
 var routes:Array=h.config.routes.keys()
 var desired_route:String=routes[0]
 for route in routes:
  if h.config.routes[route].weapon==str(g.weapon_entries()[0].key):desired_route=route
 var ordered:Array=[desired_route]
 for route in routes:
  if not ordered.has(route):ordered.append(route)
 for route in ordered:
  var best_level:=0
  for level in s.history.get(route,{}):
   if int(level)<=int(g.profile.highestLevel):best_level=maxi(best_level,int(level))
  var target:int=int(h.config.minimum_level) if best_level==0 else int(g.profile.highestLevel)
  if best_level>0 and target<best_level+5 and not (target==60 and best_level<60):continue
  var key:String=str([s.round_id,route,target])
  if now-float(last_attempt.get(key,-1000.0))<900.0:continue
  if g.manual_hyperspace.production_accepted and float(s.energy)>=float(h.config.ticket):return {"domain":true,"kind":"space_manual","route":route,"level":target,"reason":"First earned record" if best_level==0 else "Frontier advanced five stages; no future enemy inspection"}
 var best_route:="";var best_level:=0
 for route in ordered:
  for level in s.history.get(route,{}):
   if int(level)<=int(g.profile.highestLevel) and int(level)>best_level:best_route=route;best_level=int(level)
 if best_level>0:
  var crew:String=pick_crew(g)
  if not crew.is_empty() and (not s.auto.enabled or s.auto.route!=best_route or int(s.auto.level)!=best_level):return {"domain":true,"kind":"space_auto","route":best_route,"level":best_level,"crew":crew}
 return {}
func planet_action(g)->Dictionary:
 for id in g.profile.planets:
  if not g.planet_unlocked(str(id)):continue
  for row in g.planet_buildings.rows(g,str(id)):
   var state:Dictionary=g.planet_buildings.state(g,str(id),str(row.id))
   if state.get("status","")=="ready":return {"domain":true,"kind":"planet_activate","planet":str(id),"building":str(row.id)}
   if state.get("status","")=="building" and state.crew.size()<int(row.extra_crew):
    for member in g.profile.crew:
     if g.idle_planet_crew(str(member.crewId)):return {"domain":true,"kind":"planet_builder","planet":str(id),"building":str(row.id),"crew":str(member.crewId)}
  var progress:Dictionary=g.planet_progress(str(id))
  if not progress.conquered and str(progress.crewId).is_empty():
   for member in g.profile.crew:
    if g.idle_planet_crew(str(member.crewId)):return {"domain":true,"kind":"planet_explore","planet":str(id),"crew":str(member.crewId)}
  if g.can_reforge_planet(str(id)) and int(g.profile.highestLevel)>=33+5*(int(id)-1):return {"domain":true,"kind":"planet_reforge","planet":str(id),"keep":keep(g)}
 # Reallocate one growth worker for either exploration or a blocked building.
 for id in g.profile.planets:
  var building_needs_worker:=false
  for row in g.planet_buildings.rows(g,str(id)):
   var state:Dictionary=g.planet_buildings.state(g,str(id),str(row.id))
   if state.get("status","")=="building" and state.crew.size()<int(row.extra_crew):building_needs_worker=true
  if g.planet_unlocked(str(id)) and (building_needs_worker or (not g.planet_progress(str(id)).conquered and str(g.planet_progress(str(id)).crewId).is_empty())):
   for job in ["jewel_auto","reactor_upgrade","hightech_scientists","equipment_upgrade"]:
    for member in g.profile.crew:
     if member.assignmentType==job:return {"domain":true,"kind":"crew_release","crew":str(member.crewId),"reason":"Current planet construction/exploration need"}
 return {}
func galaxy_action(g)->Dictionary:
 if not g.galaxy.available():return {}
 for key in g.galaxy.regions:
  if g.galaxy.regions[key].state.status=="available":return {"domain":true,"kind":"galaxy_start","galaxy":str(key)}
  if g.galaxy.regions[key].state.status not in ["exploring","developing"]:continue
  var target:int=mini(6,maxi(1,g.profile.crew.size()))
  if g.galaxy.crew_count(g,str(key))<target:
   for member in g.profile.crew:
    if g.idle_planet_crew(str(member.crewId)) and g.crew.can_assign(g,str(member.crewId),"galaxy_explore",str(key)):return {"domain":true,"kind":"galaxy_crew","galaxy":str(key),"crew":str(member.crewId)}
   for planet in g.profile.planets:
    var progress:Dictionary=g.planet_progress(str(planet))
    if progress.conquered and not str(progress.crewId).is_empty():return {"domain":true,"kind":"planet_recall","planet":str(planet)}
   for job in ["jewel_auto","reactor_upgrade","hightech_scientists","equipment_upgrade"]:
    for member in g.profile.crew:
     if str(member.assignmentType)==job:return {"domain":true,"kind":"crew_release","crew":str(member.crewId),"reason":"First galaxy work needs crew, old growth automation stops"}
   if not Permission.reserved_crew(g.profile.hyperspace).is_empty():galaxy_needs_reserved_crew=true
  else:galaxy_needs_reserved_crew=false
 return {}
func execute(g,choice:Dictionary,now:float)->bool:
 match choice.kind:
  "space_manual":
   if g.profile.hyperspace.auto.enabled:g.hyperspace.set_auto(g,false,"",0,"")
   last_attempt[str([g.profile.hyperspace.round_id,choice.route,choice.level])]=now
   return g.start_hyperspace(choice.route,int(choice.level))
  "space_claim":return g.hyperspace.claim(g,int(choice.round),int(choice.run))
  "space_unseal":return g.hyperspace.claim_sealed(g,choice.id)
  "space_equip":return g.hyperspace.set_equipped(g,choice.ids)
  "space_favorite":return g.hyperspace.set_favorites(g,choice.ids)
  "space_preset":return g.hyperspace.set_preset(g,0,"Earned current fleet",choice.ids)
  "space_auto_pause":return g.hyperspace.set_auto(g,false,"",0,"")
  "space_auto":return g.hyperspace.set_auto(g,true,choice.route,int(choice.level),choice.crew)
  "space_hangings":return g.hyperspace.attach_hangings(g,choice.id,choice.keys)
  "space_forge":
   forge_at[str(choice.request.drone_id)]=now
   return str(g.hyperspace.forge(g,choice.request).error).is_empty()
  "planet_activate":return g.planet_buildings.activate(g,choice.planet,choice.building)
  "planet_builder":return g.planet_buildings.assign(g,choice.planet,choice.building,choice.crew)
  "planet_recall":return g.cancel_planet_exploration(choice.planet)
  "planet_explore":return g.start_planet_exploration(choice.planet,choice.crew)
  "planet_reforge":return g.reforge_planet(choice.planet,choice.keep)
  "crew_release":return g.assign_crew(choice.crew,"","")
  "galaxy_start":return g.galaxy.start(g,choice.galaxy)
  "galaxy_crew":return g.assign_crew(choice.crew,"galaxy_explore",choice.galaxy)
 return false
