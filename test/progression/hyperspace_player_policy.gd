extends RefCounted
## Explicit QA decisions from earned records/current feedback; each command costs one visible-page action.
const VERSION="hyperspace-player-v21-sparse-reserved-crew-ultimate-chain"
var idle_salvage_enabled:=OS.get_environment("QA_IDLE_SALVAGE")=="1"
var idle_salvage_budget:Dictionary={"round":-1,"used":0,"tour_started":-1.0}
var idle_salvage_success_times:Array=[]
const IDLE_SALVAGE_WINDOW_LIMIT:=3
const IDLE_SALVAGE_WINDOW_SECONDS:=300.0
const Bag=preload("res://scripts/drone_inventory.gd")
const Permission=preload("res://scripts/hyperspace_permissions.gd")
const Rewards=preload("res://scripts/drone_rewards.gd")
var last_attempt:Dictionary={}
var manual_failures:Dictionary={}
var last_frontier_attempt:Dictionary={}
var manual_frontier_failures:Dictionary={}
var manual_pending:Dictionary={}
var manual_watch:Dictionary={}
var last_manual_boundary:=""
const MANUAL_CHECK_SECONDS:=300.0
const MANUAL_STALL_SECONDS:=600.0
const MANUAL_BUDGET_SECONDS:=900.0
func manual_key(g,route:String,level:int)->String:
 return str([g.profile.hyperspace.round_id,route,level])
static func manual_growth(profile:Dictionary)->Dictionary:
 var levels:Dictionary={}
 for category in ["weapons","defence"]:
  for index in profile.loadout[category].size():levels[str([category,index])]=int(profile.loadout[category][index].level)
 return {"levels":levels,"scientists":int(profile.scientists),"reactorLevel":int(profile.reactorLevel),"enhancementLevel":int(profile.enhancementLevel)}
static func earned_manual_growth(before:Dictionary,after:Dictionary)->bool:
 for key in before.get("levels",{}):
  if int(after.get("levels",{}).get(key,0))>=int(before.levels[key])+5:return true
 for key in ["scientists","reactorLevel","enhancementLevel"]:
  if int(after.get(key,0))>int(before.get(key,0)):return true
 return false
func manual_frontier_key(g)->String:
 return str([g.profile.hyperspace.round_id,g.profile.highestLevel])
func frontier_failure(g)->Dictionary:
 var key:String=manual_frontier_key(g);var latest:Dictionary=manual_frontier_failures.get(key,{})
 # An old failure at the exact current frontier proves this same gate; do not infer older paid-route frontiers.
 for old_key in manual_failures:
  var parsed=JSON.parse_string(str(old_key))
  if not parsed is Array or parsed.size()!=3 or int(parsed[0])!=int(g.profile.hyperspace.round_id) or int(parsed[2])!=int(g.profile.highestLevel):continue
  var failure:Dictionary=manual_failures[old_key]
  if float(failure.get("failed_at",-1.0))>float(latest.get("failed_at",-1.0)):latest=failure
 return latest
func manual_retry_allowed(g,route:String,level:int,now:float)->bool:
 var key:String=manual_key(g,route,level)
 if now-float(last_frontier_attempt.get(manual_frontier_key(g),-1000.0))<MANUAL_CHECK_SECONDS:return false
 var frontier:Dictionary=frontier_failure(g)
 if not frontier.is_empty() and (now-float(frontier.failed_at)<900.0 or not earned_manual_growth(frontier.growth,manual_growth(g.profile))):return false
 if now-float(last_attempt.get(key,-1000.0))<900.0:return false
 return not manual_failures.has(key) or earned_manual_growth(manual_failures[key].growth,manual_growth(g.profile))
func main_boundary(g)->String:
 return str([g.profile.hyperspace.round_id,g.stage,g.group_index])
func safe_main_boundary(g)->bool:
 if not g.manual_hyperspace.queued.is_empty() or not g.manual_hyperspace.boundary_reason(g).is_empty():return false
 if g.state not in [g.State.TRAVEL,g.State.LEVEL_CLEAR] or g.group_index<=0:return false
 for enemy in g.enemies:
  if g.N.compare(enemy.hp,0)>0:return false
 return main_boundary(g)!=last_manual_boundary
func pending_manual_action(g,now:float)->Dictionary:
 return validated_pending_manual_action(g,now,true)
func queue_manual_action(g,now:float)->Dictionary:
 return validated_pending_manual_action(g,now,false)
func validated_pending_manual_action(g,now:float,require_main_boundary:bool)->Dictionary:
 if manual_pending.is_empty() or (require_main_boundary and not safe_main_boundary(g)) or not g.profile.hyperspace.active.is_empty():return {}
 var choice:Dictionary=manual_pending
 if choice.has("paid_affix_supply"):
  var needed:Dictionary=growth_supply(g);var planned:Dictionary=choice.paid_affix_supply
  if needed.is_empty() or str(needed.route)!=str(planned.route) or (planned.has("desired_tier") and not needed.has("desired_tier")) or (not needed.get("record_prerequisite",false) and int(needed.available)>=int(needed.get("minimum",1))):manual_pending={};return {}
  if g.profile.hyperspace.auto.enabled:return {}
 if int(choice.round)!=int(g.profile.hyperspace.round_id) or int(choice.frontier)!=int(g.profile.highestLevel):
  manual_pending={};return {}
 if not manual_retry_allowed(g,str(choice.route),int(choice.level),now):return {}
 if not g.manual_hyperspace.production_accepted or not g.hyperspace.eligible_level(g,str(choice.route),int(choice.level)) or float(g.profile.hyperspace.energy)<float(g.hyperspace.config.ticket):return {}
 return choice.duplicate(true)
func manual_started(g,route:String,level:int,now:float)->void:
 var planned:Dictionary=manual_pending.duplicate(true)
 if bool(planned.get("queued_for_hold60",false)):
  var journey:Dictionary=g.manual_hyperspace.return_journey
  last_manual_boundary=str([g.profile.hyperspace.round_id,journey.get("stage",g.stage),journey.get("groupIndex",g.group_index)])
  last_attempt[str([g.profile.hyperspace.round_id,route,level])]=now
  last_frontier_attempt[manual_frontier_key(g)]=now
 manual_pending={}
 manual_watch={"key":manual_key(g,route,level),"frontier":manual_frontier_key(g),"route":route,"level":level,"start":now,"next_check":now+MANUAL_CHECK_SECONDS,"last_progress":now,"group":-1,"bars":{},"exit_reason":""}
 if planned.has("paid_affix_supply"):manual_watch.paid_affix_supply=planned.paid_affix_supply.duplicate(true)
func manual_finished(g,success:bool,now:float)->Dictionary:
 if manual_watch.is_empty():return {}
 var result:Dictionary={"key":manual_watch.key,"success":success,"seconds":now-float(manual_watch.start),"exit_reason":manual_watch.exit_reason,"paid_affix_supply":manual_watch.get("paid_affix_supply",{}).duplicate(true)}
 var frontier:String=str(manual_watch.get("frontier",manual_frontier_key(g)))
 if not success:
  var failure:Dictionary={"growth":manual_growth(g.profile),"failed_at":now,"reason":manual_watch.exit_reason}
  manual_failures[str(manual_watch.key)]=failure;manual_frontier_failures[frontier]=failure.duplicate(true)
 else:
  manual_failures.erase(str(manual_watch.key));manual_frontier_failures.erase(frontier)
 manual_watch={};return result
# Bars come only from actors actually drawn in the clipped viewport.
func manual_visible_bars(g,scene)->Dictionary:
 var bars:Dictionary={}
 for enemy in g.enemies:
  if g.N.compare(enemy.hp,0)<=0:continue
  var point:Vector2=scene.enemy_render_position(enemy)
  if not Rect2(Vector2.ZERO,scene.battle_clip.size).has_point(point):continue
  if not scene.get_viewport().get_visible_rect().has_point(scene.battle_clip.get_global_transform_with_canvas()*point):continue
  bars[str(enemy.uid)]={"hp":clampf(float(enemy.hp)/maxf(1.0,float(enemy.max_hp)),0,1),"shield":clampf(float(enemy.get("shield",0))/maxf(1.0,float(enemy.get("max_shield",0))),0,1)}
 return bars
func check_manual_budget(g,bars:Dictionary,now:float)->Dictionary:
 if not g.manual_hyperspace.active or manual_watch.is_empty() or now<float(manual_watch.next_check):return {}
 manual_watch.next_check=now+MANUAL_CHECK_SECONDS
 var progressed:bool=int(g.group_index)>int(manual_watch.group)
 for uid in bars:
  if manual_watch.bars.has(uid):
   for layer in ["hp","shield"]:
    if float(manual_watch.bars[uid][layer])-float(bars[uid][layer])>=0.01:progressed=true
 if progressed:manual_watch.last_progress=now
 manual_watch.group=g.group_index
 if progressed or manual_watch.bars.is_empty():manual_watch.bars=bars.duplicate(true)
 var elapsed:float=now-float(manual_watch.start)
 if elapsed>=MANUAL_BUDGET_SECONDS:manual_watch.exit_reason="900 X1 seconds manual budget reached; return to main"
 elif not bars.is_empty() and now-float(manual_watch.last_progress)>=MANUAL_STALL_SECONDS:manual_watch.exit_reason="Visible bars/wave made no material progress for 600 X1 seconds"
 return {"elapsed":elapsed,"visible_bars":bars,"group":g.group_index,"last_progress":manual_watch.last_progress,"exit_reason":manual_watch.exit_reason}

var forge_at:Dictionary={}
var reserved_crew:=""
var crew_transfer:Dictionary={}
var crew_transfer_history:Array=[]
var last_crew_transfer:=-300.0
var reforge_observed:Dictionary={}
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
func visible_loadout_plan(g,allowed:Array,resist:Dictionary,attacks:Dictionary,repairs:int,visible_count:int)->Dictionary:
 var higgs:=false
 var physical:String="missile" if visible_count>=4 else "cannon"
 var energy:String="laser" if visible_count>=4 else "longLaser"
 for id in g.profile.hyperspace.inventory.equipped:
  var d:Dictionary=g.profile.hyperspace.inventory.drones[id]
  if d.legendary and d.legendary_effect.get("effect_id")=="higgs_cannon":physical="missile";higgs=true
 if not allowed.has(physical):physical="cannon" if allowed.has("cannon") else "missile" if allowed.has("missile") else ""
 if not allowed.has(energy):energy="longLaser" if allowed.has("longLaser") else "laser" if allowed.has("laser") else ""
 var weapons:Array=[];var defences:Array=[]
 var mixed:bool=int(resist[1])>0 and int(resist[2])>0
 var physical_slots:int=clampi(roundi(float(g.active_slot_count("weapons")*int(resist[1]))/float(maxi(1,int(resist[1])+int(resist[2])))),1,g.active_slot_count("weapons")-1) if mixed else 0
 for index in g.active_slot_count("weapons"):
  var desired:String=physical if int(resist[1])>int(resist[2]) else energy if int(resist[2])>int(resist[1]) else physical if not physical.is_empty() else energy
  if mixed:desired=physical if index<physical_slots else energy
  # The permanent repair-module glyph is visible feedback; the unlocked beam tutorial teaches sustained damage.
  if repairs>0 and desired in ["laser","longLaser"] and allowed.has("longLaser"):desired="longLaser"
  if desired.is_empty():desired=str(g.slot_entry("weapons",index).key)
  weapons.append(desired)
 for index in g.active_slot_count("defence"):
  var shield:bool=index>0 and g.content_unlocked("equipment","shield") and (int(attacks[1])>int(attacks[2]) or (int(attacks[1])==int(attacks[2]) and (int(attacks[1])==0 or index%2==1)))
  defences.append("shield" if shield else "armour")
 return {"weapons":weapons,"defences":defences,"higgs":higgs}
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
 var layout:Dictionary=visible_loadout_plan(g,allowed,resist,attacks,repairs,visible.size())
 wanted_weapons=layout.weapons;wanted_defences=layout.defences
 var higgs:bool=layout.higgs
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
func transfer_crew(id:String)->bool:
 return not crew_transfer.is_empty() and id in [str(crew_transfer.veteran),str(crew_transfer.replacement)]
var space_crew_reservation:Dictionary={}
func reserved_growth_crew(g)->String:
 var actual:String=Permission.reserved_crew(g.profile.hyperspace)
 if not actual.is_empty():return actual
 if int(space_crew_reservation.get("round",-1))==int(g.profile.hyperspace.round_id):return str(space_crew_reservation.get("crew",""))
 return ""
func space_worker_demand(g)->Dictionary:
 var s:Dictionary=g.profile.hyperspace
 if int(g.profile.highestLevel)<int(g.hyperspace.config.unlock_stage) or s.auto.enabled or not s.active.is_empty() or g.manual_hyperspace.active or not manual_pending.is_empty() or galaxy_needs_reserved_crew:return {}
 # Do not stop a growth worker while an auto ticket cannot actually dispatch.
 if float(s.energy)<float(g.hyperspace.online_config(g).energy_cap) or not Bag.has_space(s.inventory,g.hyperspace.config):return {}
 var supply:Dictionary=growth_supply(g)
 if not supply.is_empty():
  if not g.profile.cleared.has(60) or supply.get("record_prerequisite",false) or supply.get("ready",false):return {}
  var record:int=best_record(g,str(supply.route))
  return {"route":str(supply.route),"level":record,"purpose":"Actual recorded paid material auto"} if record>0 else {}
 for route in g.hyperspace.config.routes:
  var record:int=best_record(g,str(route))
  if record>0:return {"route":str(route),"level":record,"purpose":"Actual eligible recorded progress auto"}
 return {}
func space_crew_reservation_action(g,visible_ids:Array,now:float)->Dictionary:
 var demand:Dictionary=space_worker_demand(g)
 if demand.is_empty():space_crew_reservation={};return {}
 var candidate:Dictionary={}
 if int(space_crew_reservation.get("round",-1))==int(g.profile.hyperspace.round_id) and str(space_crew_reservation.get("route",""))==str(demand.route):candidate=g.crew.entry(g,str(space_crew_reservation.get("crew","")))
 if not candidate.is_empty() and (not visible_ids.has(str(candidate.crewId)) or not g.crew.unlocked(g,str(candidate.crewId)) or transfer_crew(str(candidate.crewId)) or not g.crew_exploration(str(candidate.crewId)).is_empty() or not g.planet_buildings.occupied(g,str(candidate.crewId)).is_empty()):candidate={}
 if candidate.is_empty():
  space_crew_reservation={}
  for member in g.profile.crew:
   var id:String=str(member.crewId)
   if visible_ids.has(id) and not transfer_crew(id) and Permission.crew_available(g,id):candidate=member;break
  if candidate.is_empty():
   for job in ["jewel_auto","reactor_upgrade","hightech_scientists","equipment_upgrade"]:
    for member in g.profile.crew:
     var id:String=str(member.crewId)
     if visible_ids.has(id) and g.crew.unlocked(g,id) and not transfer_crew(id) and str(member.assignmentType)==job and g.crew_exploration(id).is_empty() and g.planet_buildings.occupied(g,id).is_empty():candidate=member;break
    if not candidate.is_empty():break
 if candidate.is_empty():return {}
 space_crew_reservation={"round":int(g.profile.hyperspace.round_id),"crew":str(candidate.crewId),"route":str(demand.route),"level":int(demand.level),"purpose":str(demand.purpose),"phase":"reserved" if str(candidate.assignmentType).is_empty() else "release","planned_at":float(space_crew_reservation.get("planned_at",now))}
 if not str(candidate.assignmentType).is_empty():return {"domain":true,"kind":"crew_release","crew":str(candidate.crewId),"reason":"Release only the selected reserved worker for an available funded space operation","reservation":space_crew_reservation.duplicate(true)}
 return {}
func pick_crew(g)->String:
 var current:String=reserved_growth_crew(g)
 if not current.is_empty() and Permission.crew_available(g,current):reserved_crew=current;return current
 if not reserved_crew.is_empty() and not transfer_crew(reserved_crew) and Permission.crew_available(g,reserved_crew):return reserved_crew
 var available:Array=[]
 for member in g.profile.crew:
  if not transfer_crew(str(member.crewId)) and Permission.crew_available(g,str(member.crewId)):available.append(member)
 available.sort_custom(func(a,b):return int(a.level)<int(b.level))
 if not available.is_empty():reserved_crew=str(available[0].crewId);return reserved_crew
 return ""
func equipment_crew_level(g)->int:
 var level:=-1
 for member in g.profile.crew:
  if member.assignmentType=="equipment_upgrade" and g.crew.active(g,member):level=maxi(level,int(member.level))
 return level
func crew_transfer_page(g)->int:
 if crew_transfer.is_empty():return -1
 var plan:Dictionary=crew_transfer;var replacement:Dictionary=g.crew.entry(g,str(plan.replacement));var veteran:Dictionary=g.crew.entry(g,str(plan.veteran));var progress:Dictionary=g.planet_progress(str(plan.planet))
 if int(plan.round)!=int(g.profile.hyperspace.round_id) or replacement.is_empty() or veteran.is_empty() or progress.is_empty():return -1
 if reserved_growth_crew(g) in [str(plan.veteran),str(plan.replacement)]:return -1
 if not str(replacement.assignmentType).is_empty():return 5
 if not g.idle_planet_crew(str(plan.replacement)):return -1
 for member in g.profile.crew:
  if member.assignmentType=="equipment_upgrade" and str(member.crewId)!=str(plan.veteran):return 5
 if str(progress.crewId)==str(plan.veteran):return 6
 if not str(progress.crewId).is_empty():return -1
 return 6 if veteran.assignmentType=="equipment_upgrade" else 5
func crew_redeploy_action(g,page:int,visible_ids:Array,now:float)->Dictionary:
 if not crew_transfer.is_empty() and int(crew_transfer.round)!=int(g.profile.hyperspace.round_id):crew_transfer={}
 if crew_transfer.is_empty():
  if page!=5 or not g.crew.levels_unlocked(g) or now-last_crew_transfer<300.0:return {}
  var veteran:Dictionary={};var planet:=""
  for id in g.profile.planets:
   var member:Dictionary=g.crew.entry(g,str(g.planet_progress(str(id)).crewId))
   if member.is_empty() or not visible_ids.has(str(member.crewId)) or not g.crew.unlocked(g,str(member.crewId)):continue
   if int(member.level)<=maxi(0,equipment_crew_level(g)) or (not veteran.is_empty() and int(member.level)<=int(veteran.level)):continue
   veteran=member;planet=str(id)
  if veteran.is_empty():return {}
  var candidates:Array=[]
  for member in g.profile.crew:
   var id:String=str(member.crewId)
   if id==str(veteran.crewId) or not visible_ids.has(id) or not g.crew.unlocked(g,id) or id==reserved_growth_crew(g) or not g.crew_exploration(id).is_empty():continue
   if str(member.assignmentType) not in ["","equipment_upgrade","hightech_scientists","reactor_upgrade","jewel_auto"]:continue
   candidates.append(member)
  candidates.sort_custom(func(a,b):return int(a.level)<int(b.level) if str(a.assignmentType).is_empty()==str(b.assignmentType).is_empty() else str(a.assignmentType).is_empty())
  if candidates.is_empty():return {}
  crew_transfer={"round":int(g.profile.hyperspace.round_id),"planet":planet,"veteran":str(veteran.crewId),"replacement":str(candidates[0].crewId),"visible_level":int(veteran.level),"planned_at":now,"phase":"prepare"}
 var plan:Dictionary=crew_transfer;var veteran:Dictionary=g.crew.entry(g,str(plan.veteran));var replacement:Dictionary=g.crew.entry(g,str(plan.replacement));var progress:Dictionary=g.planet_progress(str(plan.planet))
 if veteran.is_empty() or replacement.is_empty() or progress.is_empty() or Permission.reserved_crew(g.profile.hyperspace) in [str(plan.veteran),str(plan.replacement)]:crew_transfer={};return {}
 if page==5:
  if not visible_ids.has(str(plan.veteran)) or not visible_ids.has(str(plan.replacement)):return {}
  if plan.phase=="prepare" and not str(replacement.assignmentType).is_empty():return {"domain":true,"kind":"crew_release","crew":str(plan.replacement),"reason":"Visible higher-level explorer will take equipment; release the actual replacement job first"}
  if not g.idle_planet_crew(str(plan.replacement)):crew_transfer={};return {}
  for member in g.profile.crew:
   if member.assignmentType=="equipment_upgrade" and str(member.crewId)!=str(plan.veteran):return {"domain":true,"kind":"crew_release","crew":str(member.crewId),"reason":"One equipment target; prepare earned higher-level replacement"}
  if str(progress.crewId).is_empty() and g.crew.can_assign(g,str(plan.veteran),"equipment_upgrade","equipment") and veteran.assignmentType!="equipment_upgrade":
   if str(veteran.upgradeMode)!="10":return {"domain":true,"kind":"crew_equipment_mode","crew":str(plan.veteran),"mode":"10"}
   return {"domain":true,"kind":"crew_assign_equipment","crew":str(plan.veteran),"reason":"Visible earned level improves equipment; actual explorer already recalled"}
 elif page==6:
  if not g.idle_planet_crew(str(plan.replacement)):crew_transfer={};return {}
  if str(progress.crewId)==str(plan.veteran) and plan.phase=="prepare":return {"domain":true,"kind":"crew_transfer_recall","planet":str(plan.planet),"crew":str(plan.veteran),"replacement":str(plan.replacement),"lost_exploration_seconds":float(progress.elapsed)}
  if str(progress.crewId).is_empty() and veteran.assignmentType=="equipment_upgrade":return {"domain":true,"kind":"crew_transfer_explore","planet":str(plan.planet),"crew":str(plan.replacement)}
 return {}
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
func forge_choice(g,id:String,op:String,args:Dictionary={},chain_step:bool=false)->Dictionary:
 var request:Dictionary=forge_request(g,id,op,args)
 var preview:Dictionary=g.hyperspace.preview_forge(g,request)
 if not chain_step and not forge_preserves_ultimate_reservation(g,preview.get("cost",{})):return {}
 return {"domain":true,"kind":"space_forge","request":request,"preview":preview} if str(preview.error).is_empty() else {}
var affix_target_tier:=0 # Optional QA spending preference; never a progression/acceptance gate.
var affix_paid_windows:Dictionary={}
func affix_supply(g)->Dictionary:
 var s:Dictionary=g.profile.hyperspace
 if int(s.inventory.reforge_count)<=0 or affix_target_tier<=0:return {}
 var targets:Array=[]
 for id in equipped(g):
  var d:Dictionary=s.inventory.drones[id]
  if not d.ultimate and d.affixes.any(func(a):return not a.locked and int(a.tier)>affix_target_tier):targets.append(id)
 if targets.is_empty():return {}
 return {"route":"gamma","material":"antiproton","available":int(s.materials.antiproton),"minimum":1,"targets":targets,"goal":"Optional spending preference, never a progression/acceptance gate; natural stronger results accepted","desired_tier":affix_target_tier}
const ForgePlanner=preload("res://scripts/drone_forge.gd")
var ultimate_upgrade_chain:Dictionary={}
func ultimate_upgrade_offer(g,id:String)->Dictionary:
 var s:Dictionary=g.profile.hyperspace;var c:Dictionary=g.hyperspace.config
 if not s.inventory.drones.has(id) or s.inventory.sealed.has(id):return {}
 var d:Dictionary=s.inventory.drones[id]
 if not d.ultimate:return {}
 var route:String=""
 for key in c.routes:
  if str(c.routes[key].weapon)==str(d.weapon):route=str(key)
 if route.is_empty():return {}
 var recorded:int=best_record(g,route)
 var target:int=maxi(recorded,manual_challenge_level(g,route))
 if target<=int(d.level):return {}
 var material:String=str(c.routes[route].material)
 var required_cores:int=int(c.forge_costs.restore_ultimate.get("ultimate_cores",0))+int(c.forge_costs.ultimate.get("ultimate_cores",0))
 var offer:Dictionary={"ultimate_chain":true,"route":route,"material":material,"drone":id,"available":int(s.materials.get(material,0)),"minimum":0,"operation":"ultimate_upgrade_chain","target_level":target,"recorded_target":recorded,"required_cores":required_cores,"core_available":int(s.ultimate_cores),"ready":false,"goal":"Earn actual same-route record and reserve the complete real modernization price plus restore/reultimate cores before lowering this equipped ultimate"}
 if target>recorded:
  offer.record_prerequisite=true;offer.required_route_level=target;return offer
 if int(s.ultimate_cores)<int(c.forge_costs.restore_ultimate.get("ultimate_cores",0)):offer.core_blocked=true;return offer
 # Native pure planner, disposable copy; no injected record, core or material.
 var private:Dictionary=s.duplicate(true)
 var restored:Dictionary=ForgePlanner.plan(private,c,forge_request(g,id,"restore_ultimate"),g)
 if not str(restored.error).is_empty():return {}
 var request:Dictionary=forge_request(g,id,"modernize",{"target_level":target})
 request.expected_revision=private.inventory.drones[id].forge_revision
 var quote:Dictionary=ForgePlanner.plan(private,c,request,g)
 if str(quote.error) not in ["","insufficient_materials"]:return {}
 offer.minimum=int(quote.get("cost",{}).get(material,0));offer.modernize_cost=quote.get("cost",{}).duplicate(true)
 offer.restore_cost=restored.cost.duplicate(true);offer.reultimate_cost=c.forge_costs.ultimate.duplicate(true)
 offer.reserved_cost={}
 for payment in [offer.restore_cost,offer.modernize_cost,offer.reultimate_cost]:
  for key in payment:offer.reserved_cost[key]=int(offer.reserved_cost.get(key,0))+int(payment[key])
 offer.core_blocked=int(s.ultimate_cores)<required_cores
 offer.ready=ForgePlanner.can_pay(s,offer.reserved_cost)
 var reward:int=Rewards.material_amount(g.hyperspace.online_config(g),recorded)
 offer.expected_recorded_reward=reward
 offer.needed_recorded_claims=ceili(float(maxi(0,int(offer.minimum)-int(offer.available)))/maxi(1,reward))
 return offer
func ultimate_upgrade_supply(g)->Dictionary:
 if not ultimate_upgrade_chain.is_empty() and str(ultimate_upgrade_chain.get("phase","")) in ["modernize","reultimate"]:return {}
 var ids:Array=equipped(g)
 if not ultimate_upgrade_chain.is_empty() and int(ultimate_upgrade_chain.get("round",-1))==int(g.profile.hyperspace.round_id):
  var selected:String=str(ultimate_upgrade_chain.get("drone",""))
  if selected in ids:ids.erase(selected);ids.push_front(selected)
 for id in ids:
  var offer:Dictionary=ultimate_upgrade_offer(g,str(id))
  if offer.is_empty():continue
  # No known paid core farm is invented. Other real first victories may earn cores.
  if offer.get("core_blocked",false) and int(offer.available)>=int(offer.minimum) and not offer.get("record_prerequisite",false):continue
  return offer
 return {}
func ultimate_chain_in_transaction()->bool:
 return str(ultimate_upgrade_chain.get("phase","")) in ["modernize","reultimate"]
func ultimate_chain_action(g,now:float)->Dictionary:
 var s:Dictionary=g.profile.hyperspace
 if not ultimate_upgrade_chain.is_empty() and int(ultimate_upgrade_chain.get("round",-1))!=int(s.round_id):ultimate_upgrade_chain={}
 if ultimate_upgrade_chain.is_empty() or str(ultimate_upgrade_chain.get("phase","")) in ["complete","recovered"]:
  var supply:Dictionary=ultimate_upgrade_supply(g)
  if supply.is_empty():return {}
  var id:String=str(supply.drone);var d:Dictionary=s.inventory.drones[id]
  ultimate_upgrade_chain={"round":int(s.round_id),"drone":id,"route":str(supply.route),"material":str(supply.material),"source_level":int(d.level),"source_ultimate_affix":d.ultimate_affix.duplicate(true),"target_level":int(supply.target_level),"minimum":int(supply.minimum),"phase":"funding","created_at":now,"receipts":[],"core_reserve":int(supply.required_cores)}
 var plan:Dictionary=ultimate_upgrade_chain;var id:String=str(plan.drone)
 if not s.inventory.drones.has(id) or s.inventory.sealed.has(id):return {}
 var d:Dictionary=s.inventory.drones[id]
 if d.ultimate_affix!=plan.source_ultimate_affix:plan.last_error="Ultimate extra affix changed outside this chain";return {}
 var op:String=""
 if plan.phase=="funding":
  if not d.ultimate:plan.last_error="Unowned ordinary state before a paid chain restore";return {}
  var offer:Dictionary=ultimate_upgrade_offer(g,id)
  if offer.is_empty():return {}
  plan.target_level=int(offer.target_level);plan.minimum=int(offer.minimum);plan.core_reserve=int(offer.required_cores);plan.source_level=int(d.level)
  plan.record_prerequisite=bool(offer.get("record_prerequisite",false));plan.core_available=int(s.ultimate_cores)
  if not offer.get("ready",false):return {}
  plan.recorded_target=int(offer.recorded_target);plan.modernize_cost=offer.modernize_cost.duplicate(true)
  plan.reserved_cost=offer.reserved_cost.duplicate(true);plan.reultimate_cost=offer.reultimate_cost.duplicate(true)
  op="restore_ultimate"
 elif plan.phase=="modernize":
  if d.ultimate:return {}
  var quote:Dictionary=g.hyperspace.preview_forge(g,forge_request(g,id,"modernize",{"target_level":int(plan.recorded_target)}))
  if str(quote.error).is_empty() and quote.cost==plan.modernize_cost and ForgePlanner.can_pay(s,plan.reserved_cost):op="modernize"
  else:
   plan.last_error=str(quote.error) if not str(quote.error).is_empty() else "Reserved modernization quote changed"
   plan.recovery=true;plan.phase="reultimate";op="ultimate"
 elif plan.phase=="reultimate":
  if d.ultimate:return {}
  op="ultimate"
 if op.is_empty():return {}
 var args:Dictionary={"target_level":int(plan.recorded_target)} if op=="modernize" else {}
 var choice:Dictionary=forge_choice(g,id,op,args,true)
 if choice.is_empty():return {}
 choice.ultimate_chain=true;choice.chain_phase=str(plan.phase);choice.chain_target=int(plan.get("recorded_target",plan.target_level))
 return choice
func ultimate_chain_step_valid(g,choice:Dictionary)->bool:
 var plan:Dictionary=ultimate_upgrade_chain;var s:Dictionary=g.profile.hyperspace
 if plan.is_empty() or int(plan.round)!=int(s.round_id) or str(choice.request.drone_id)!=str(plan.drone) or not s.inventory.drones.has(str(plan.drone)):return false
 var d:Dictionary=s.inventory.drones[plan.drone]
 if d.ultimate_affix!=plan.source_ultimate_affix:return false
 var op:String=str(choice.request.operation)
 if op=="restore_ultimate":
  return d.ultimate and plan.phase=="funding" and best_record(g,str(plan.route))==int(plan.recorded_target) and ForgePlanner.can_pay(s,plan.reserved_cost)
 if op=="modernize":return not d.ultimate and plan.phase=="modernize" and ForgePlanner.can_pay(s,plan.reserved_cost) and best_record(g,str(plan.route))==int(plan.recorded_target)
 return op=="ultimate" and not d.ultimate and plan.phase=="reultimate" and ForgePlanner.can_pay(s,plan.reultimate_cost)
func ultimate_chain_result(g,choice:Dictionary,result:Dictionary,now:float,advanced:bool)->void:
 var plan:Dictionary=ultimate_upgrade_chain
 if plan.is_empty():return
 var d:Dictionary=g.profile.hyperspace.inventory.drones.get(str(plan.drone),{})
 if not str(result.error).is_empty() or not advanced:
  plan.last_error=str(result.error) if not str(result.error).is_empty() else "No committed command sequence advancement"
  if not d.is_empty() and not d.ultimate:plan.phase="reultimate";plan.recovery=true
  return
 var operation:String=str(choice.request.operation)
 for key in result.cost:plan.reserved_cost[key]=maxi(0,int(plan.reserved_cost.get(key,0))-int(result.cost[key]))
 plan.receipts.append({"operation":operation,"x1_seconds":now,"command_seq_after":int(g.profile.hyperspace.command_seq),"cost":result.cost.duplicate(true),"level":int(d.level),"ultimate":bool(d.ultimate),"cores_after":int(g.profile.hyperspace.ultimate_cores),"materials_after":g.profile.hyperspace.materials.duplicate(true)})
 if operation=="restore_ultimate":plan.phase="modernize"
 elif operation=="modernize":plan.phase="reultimate"
 else:plan.phase="recovered" if bool(plan.get("recovery",false)) else "complete";plan.completed_at=now
func forge_preserves_ultimate_reservation(g,cost:Dictionary)->bool:
 var plan:Dictionary=ultimate_upgrade_chain
 if plan.is_empty() or int(plan.get("round",-1))!=int(g.profile.hyperspace.round_id) or str(plan.get("phase","")) in ["complete","recovered"]:return true
 var s:Dictionary=g.profile.hyperspace
 if int(cost.get("ultimate_cores",0))>0 and int(s.ultimate_cores)-int(cost.ultimate_cores)<int(plan.core_reserve):return false
 var material:String=str(plan.material);var reserve:int=mini(int(s.materials.get(material,0)),int(plan.minimum))
 if bool(plan.get("record_prerequisite",false)):reserve=int(s.materials.get(material,0))
 return int(s.materials.get(material,0))-int(cost.get(material,0))>=reserve
func modernization_opportunities(g)->Array:
 var s:Dictionary=g.profile.hyperspace;var c:Dictionary=g.hyperspace.config;var opportunities:Array=[]
 for id in equipped(g):
  var d:Dictionary=s.inventory.drones[id]
  if d.ultimate or d.affixes.is_empty():continue
  var route:String=""
  for key in c.routes:
   if str(c.routes[key].weapon)==str(d.weapon):route=str(key)
  var target:int=manual_challenge_level(g,route)
  var recorded:int=best_record(g,route)
  if target>recorded and target>int(d.level):
   opportunities.append({"route":route,"material":str(c.routes[route].material),"available":int(s.materials.get(str(c.routes[route].material),0)),"minimum":0,"record_prerequisite":true,"required_route_level":target,"operation":"modernize","drone":str(id),"level_gain":target-int(d.level),"goal":"Post60 whole-equipment modernization: earn the actually eligible higher route record before a price exists; no assumed reward or cost"})
   continue
  var preview:Dictionary=g.hyperspace.preview_forge(g,forge_request(g,str(id),"modernize"))
  if str(preview.error) not in ["","insufficient_materials"]:continue
  var material:String=str(c.routes[route].material);var cost:int=int(preview.get("cost",{}).get(material,0))
  var available:int=int(s.materials.get(material,0))
  var reward:int=Rewards.material_amount(g.hyperspace.online_config(g),recorded)
  var missing:int=maxi(0,cost-available)
  opportunities.append({"route":route,"material":material,"available":available,"minimum":cost,"operation":"modernize","drone":str(id),"ready":str(preview.error).is_empty(),"expected_recorded_reward":reward,"needed_recorded_claims":ceili(float(missing)/maxi(1,reward)),"level_gain":recorded-int(d.level),"goal":"Post60 whole-equipment modernization: compare every real quote and reserve its actual material, with unchanged price/RNG"})
 return opportunities
func modernization_plan(g)->Dictionary:
 var all:Array=modernization_opportunities(g)
 if all.is_empty():return {}
 # Spend an already affordable real modernization before planning further paid work.
 var ready:Array=all.filter(func(o):return bool(o.get("ready",false)))
 if not ready.is_empty():
  ready.sort_custom(func(a,b):return int(a.minimum)<int(b.minimum) if int(a.minimum)!=int(b.minimum) else str(a.drone)<str(b.drone))
  return ready[0]
 # Avoid buying a lower-record modernization just before an eligible new record.
 var prerequisites:Array=all.filter(func(o):return bool(o.get("record_prerequisite",false)))
 if not prerequisites.is_empty():
  for o in prerequisites:o["affected_equipped"]=prerequisites.filter(func(v):return str(v.route)==str(o.route)).size()
  prerequisites.sort_custom(func(a,b):return int(a.affected_equipped)>int(b.affected_equipped) if int(a.affected_equipped)!=int(b.affected_equipped) else int(a.level_gain)>int(b.level_gain) if int(a.level_gain)!=int(b.level_gain) else str(a.drone)<str(b.drone))
  return prerequisites[0]
 # Collect the fewest known real reward receipts for one complete legal upgrade.
 all.sort_custom(func(a,b):return int(a.needed_recorded_claims)<int(b.needed_recorded_claims) if int(a.needed_recorded_claims)!=int(b.needed_recorded_claims) else int(a.level_gain)>int(b.level_gain) if int(a.level_gain)!=int(b.level_gain) else str(a.drone)<str(b.drone))
 return all[0]
func growth_supply(g)->Dictionary:
 var ultimate_supply:Dictionary=ultimate_upgrade_supply(g)
 if not ultimate_supply.is_empty():return ultimate_supply
 if g.profile.cleared.has(60):
  var modernization:Dictionary=modernization_plan(g)
  if not modernization.is_empty():return modernization
 var preference:Dictionary=affix_supply(g)
 if not preference.is_empty():return preference
 var s:Dictionary=g.profile.hyperspace;var c:Dictionary=g.hyperspace.config
 for id in equipped(g):
  var d:Dictionary=s.inventory.drones[id]
  if d.ultimate:continue
  var operations:Array=[]
  if d.affixes.size()<Bag.affix_limit(d,c):operations.append("add_affix")
  var hanging_unlocked:bool=c.hanging_modules.keys().any(func(key):return s.hanging_modules[key].unlocked and int(g.profile.highestLevel)>=int(c.hanging_modules[key].unlock_stage))
  if int(d.hanging_slots)<Bag.hanging_limit(d,c) and hanging_unlocked:operations.append("add_hanging_slot")
  operations.append("modernize")
  for operation in operations:
   var preview:Dictionary=g.hyperspace.preview_forge(g,forge_request(g,str(id),str(operation)))
   if str(preview.error)!="insufficient_materials":continue
   for material in preview.get("cost",{}):
    var required:int=int(preview.cost[material])
    if int(s.materials.get(material,0))>=required:continue
    for route in c.routes:
     if str(c.routes[route].material)==str(material):return {"route":str(route),"material":str(material),"available":int(s.materials.get(material,0)),"minimum":required,"operation":str(operation),"drone":str(id),"goal":"Visible affordable-in-principle normal forge action; no affix-tier prerequisite or probability change"}
 # A higher genuinely cleared main milestone can expose a modernize quote only after a real route victory.
 # Choosing that prerequisite challenge never inserts history or forecasts an RNG reward.
 for id in equipped(g):
  var drone:Dictionary=s.inventory.drones[id]
  if drone.ultimate:continue
  for route in c.routes:
   if str(c.routes[route].weapon)!=str(drone.weapon):continue
   var target:int=manual_challenge_level(g,str(route))
   if target>int(drone.level):return {"route":str(route),"material":str(c.routes[route].material),"available":int(s.materials.get(str(c.routes[route].material),0)),"minimum":0,"record_prerequisite":true,"required_route_level":target,"operation":"modernize","drone":str(id),"goal":"Actual modernization needs an earned higher route record before a legal price exists; no injected history/cost or tier requirement"}
 return {}
func manual_challenge_level(g,route:String,repeat_recorded:bool=false)->int:
 var cleared:=0
 for level in g.profile.cleared:cleared=maxi(cleared,int(level))
 var minimum:int=int(g.hyperspace.config.minimum_level)
 var ceiling:int=mini(int(g.profile.highestLevel),maxi(minimum,((cleared-1)/5)*5))
 if cleared>=60:ceiling=mini(60,int(g.profile.highestLevel))
 var recorded:int=best_record(g,route)
 var target:int=mini(maxi(minimum if recorded==0 else recorded+5,ceiling),ceiling)
 return target if target>recorded or repeat_recorded else 0
func best_record(g,route:String)->int:
 var best:=0
 for key in g.profile.hyperspace.history.get(route,{}):
  if g.hyperspace.eligible_level(g,route,int(key)):best=maxi(best,int(key))
 return best
func affix_paid_window(g,id:String,now:float)->bool:
 var key:String=str([g.profile.hyperspace.round_id,id])
 var window:Dictionary=affix_paid_windows.get(key,{"started":now,"attempts":0})
 if now-float(window.started)>=300.0:window={"started":now,"attempts":0}
 affix_paid_windows[key]=window
 return int(window.attempts)<32
func pick_supply_crew(g)->String:
 var current:String=reserved_growth_crew(g)
 if not current.is_empty():return current if Permission.crew_available(g,current) else ""
 var available:Array=[]
 for member in g.profile.crew:
  if not transfer_crew(str(member.crewId)) and Permission.crew_available(g,str(member.crewId)):available.append(member)
 available.sort_custom(func(a,b):return int(a.level)>int(b.level) if int(a.level)!=int(b.level) else (str(a.crewId)==reserved_crew if str(b.crewId)!=reserved_crew else false))
 if not available.is_empty():reserved_crew=str(available[0].crewId);return reserved_crew
 return ""
func paid_affix_supply_action(g,now:float,supply:Dictionary)->Dictionary:
 var s:Dictionary=g.profile.hyperspace
 if not manual_pending.is_empty():
  if s.auto.enabled:return {"domain":true,"kind":"space_auto_pause","reason":"Stop future recurrence for an already planned earned material attempt; current receipt is preserved"}
  return pending_manual_action(g,now)
 var route:String=str(supply.route);var recorded:int=best_record(g,route)
 var target:int=manual_challenge_level(g,route,not supply.get("record_prerequisite",false))
 var funding_crew:String=pick_supply_crew(g) if recorded>0 else ""
 # After60, an already won target and available crew can fund the same material
 # through the authored discounted auto ticket. Manual play earns new records.
 var recorded_auto:bool=g.profile.cleared.has(60) and not supply.get("record_prerequisite",false) and target>0 and recorded>=target and not funding_crew.is_empty()
 var needs_challenge:bool=(supply.get("record_prerequisite",false) or int(supply.available)<int(supply.get("minimum",1))) and not recorded_auto
 if target>0 and needs_challenge and float(s.energy)>=float(g.hyperspace.config.ticket) and manual_retry_allowed(g,route,target,now):
  manual_pending={"domain":true,"kind":"space_manual","route":route,"level":target,"round":int(s.round_id),"frontier":int(g.profile.highestLevel),"paid_affix_supply":supply.duplicate(true),"reason":"Paid forge-material source; actual earlier main milestone or next +5 challenge, not an injected space record; one safe main boundary and actual ticket"}
  if s.auto.enabled:return {"domain":true,"kind":"space_auto_pause","reason":"Stop future recurrence for earned material attempt; current receipt continues to actual completion/claim"}
  return pending_manual_action(g,now)
 if recorded>0:
  var crew:String=funding_crew
  if not crew.is_empty() and (not s.auto.enabled or str(s.auto.route)!=route or int(s.auto.level)!=recorded):return {"domain":true,"kind":"space_auto","route":route,"level":recorded,"crew":crew,"paid_affix_supply":supply.duplicate(true),"reason":"Best genuinely recorded eligible required-material source, actual reduced ticket and cap gate"}
 return {}
func salvage_candidates(g,white_only:bool)->Array:
 var bag:Dictionary=g.profile.hyperspace.inventory
 # Keep the best currently usable unequipped backup for every earned weapon type.
 var backups:Dictionary={}
 for id in bag.warehouse:
  if id in bag.equipped or bag.sealed.has(id):continue
  var d:Dictionary=bag.drones[id];var weapon:String=str(d.weapon)
  if not backups.has(weapon) or score(d)>score(bag.drones[backups[weapon]]) or (score(d)==score(bag.drones[backups[weapon]]) and str(id)<str(backups[weapon])):backups[weapon]=id
 var removable:Array=[]
 for id in bag.warehouse:
  var d:Dictionary=bag.drones[id]
  if Bag.protected(bag,id) or d.ultimate or id in backups.values() or not d.hangings.is_empty():continue
  if white_only and (d.legendary or str(d.origin_quality)!="white"):continue
  removable.append(id)
 removable.sort_custom(func(a,b):return score(bag.drones[a])<score(bag.drones[b]) if score(bag.drones[a])!=score(bag.drones[b]) else str(a)<str(b))
 return removable
func idle_salvage_choice(g,now:float,tour_started:float)->Dictionary:
 if not idle_salvage_enabled:return {}
 var round_id:int=int(g.profile.hyperspace.round_id)
 idle_salvage_success_times=idle_salvage_success_times.filter(func(at):return now-float(at)<IDLE_SALVAGE_WINDOW_SECONDS)
 idle_salvage_budget={"round":round_id,"used":idle_salvage_success_times.size(),"tour_started":tour_started,"window_seconds":IDLE_SALVAGE_WINDOW_SECONDS}
 if int(idle_salvage_budget.used)>=IDLE_SALVAGE_WINDOW_LIMIT:return {}
 for id in salvage_candidates(g,true):
  var choice:Dictionary=forge_choice(g,id,"dismantle")
  if choice.is_empty():continue
  choice.idle_salvage=true;choice.salvage_budget=idle_salvage_budget.duplicate(true)
  choice.reason="Earned idle white drone; protected fleet and one backup per weapon retained; at most three successful idle dismantles per rolling300 X1 seconds; existing 0.3-second native action"
  return choice
 return {}
func space_action(g,now:float,tour_started:float=-1.0)->Dictionary:
 if int(g.profile.highestLevel)<7:return {}
 var h=g.hyperspace;var s:Dictionary=g.profile.hyperspace;var bag:Dictionary=s.inventory
 if not s.active.is_empty():
  if s.active.status=="completed_pending" and Bag.has_space(bag,h.config):return {"domain":true,"kind":"space_claim","round":s.active.round_id,"run":s.active.run_id}
  if s.active.mode=="manual":return {}
 # Return only sealed drones whose real planet gate was regained in this run.
 for id in bag.sealed:
  if int(g.profile.highestLevel)>=int(bag.sealed[id]):return {"domain":true,"kind":"space_unseal","id":id}
 var chain_choice:Dictionary=ultimate_chain_action(g,now)
 if not chain_choice.is_empty():return chain_choice
 if ultimate_chain_in_transaction():return {}
 var chosen:Array=equipped(g)
 if chosen!=bag.equipped:return {"domain":true,"kind":"space_equip","ids":chosen}
 if chosen!=bag.favorites:return {"domain":true,"kind":"space_favorite","ids":chosen}
 if not chosen.is_empty() and (bag.presets.is_empty() or bag.presets[0].drone_ids!=chosen):return {"domain":true,"kind":"space_preset","ids":chosen}
 # Storage-pressure recovery remains available independently of idle tour budget.
 if not Bag.has_space(bag,h.config):
  for id in salvage_candidates(g,false):
   var dismantle:Dictionary=forge_choice(g,id,"dismantle")
   if not dismantle.is_empty():dismantle.storage_pressure=true;return dismantle
  return {}
 if idle_salvage_enabled:
  var salvage:Dictionary=idle_salvage_choice(g,now,tour_started)
  if not salvage.is_empty():return salvage
 var post60_modernize:Dictionary=modernization_plan(g) if g.profile.cleared.has(60) else {}
 if post60_modernize.get("ready",false):
  var modernization:Dictionary=forge_choice(g,str(post60_modernize.drone),"modernize")
  if not modernization.is_empty():return modernization
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
  # Reserve materials for the compared post60 upgrade; optional paid rolls wait.
  if not post60_modernize.is_empty():continue
  var paid_affix:bool=affix_target_tier>0 and int(bag.reforge_count)>0 and d.affixes.any(func(a):return not a.locked and int(a.tier)>affix_target_tier)
  if paid_affix and int(s.materials.antiproton)>0 and affix_paid_window(g,str(id),now):
   for op in (["enable_omen","promote_affix"] if not d.omen else ["promote_affix"]):
    var paid:Dictionary=forge_choice(g,id,str(op))
    if not paid.is_empty():paid.paid_affix=true;return paid
  if now-float(forge_at.get(id,-1000.0))<300.0:continue
  var operations:Array=[]
  if d.affixes.size()<Bag.affix_limit(d,h.config):operations.append("add_affix")
  # Optional paid spending preference; never a progression or acceptance gate.
  if paid_affix and affix_paid_window(g,str(id),now):
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
 var supply:Dictionary=growth_supply(g)
 if not supply.is_empty():
  var funding:Dictionary=paid_affix_supply_action(g,now,supply)
  if not funding.is_empty():return funding
  # An initiated material plan awaits real safe boundary/energy/receipt; no unrelated auto can overwrite it.
  return {} # A real unresolved supply need owns this choice; do not toggle back to unrelated auto.
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
  var target:int=manual_challenge_level(g,str(route))
  if target<=0:continue
  var key:String=str([s.round_id,route,target])
  if not manual_retry_allowed(g,str(route),target,now):continue
  if g.manual_hyperspace.production_accepted and float(s.energy)>=float(h.config.ticket):
   manual_pending={"domain":true,"kind":"space_manual","route":route,"level":target,"round":int(s.round_id),"frontier":int(g.profile.highestLevel),"reason":"Default natural exploration uses a real earlier main milestone and shared frontier failure/growth gate; never current hard frontier by fallback"}
   return pending_manual_action(g,now)
 var best_route:="";var best_level:=0
 for route in ordered:
  for level in s.history.get(route,{}):
   if int(level)<=int(g.profile.highestLevel) and int(level)>best_level:best_route=route;best_level=int(level)
 if best_level>0:
  var crew:String=pick_crew(g)
  if not crew.is_empty() and (not s.auto.enabled or s.auto.route!=best_route or int(s.auto.level)!=best_level):return {"domain":true,"kind":"space_auto","route":best_route,"level":best_level,"crew":crew}
 return {}
func planet_action(g,now:float=0.0)->Dictionary:
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
  if g.can_reforge_planet(str(id)):
   var key:String=str([int(g.profile.hyperspace.round_id),id])
   if not reforge_observed.has(key):reforge_observed[key]={"first_visible_eligible_x1":now,"frontier":int(g.profile.highestLevel),"eligibility_source":"Actual planet page production can_reforge_planet"}
   return {"domain":true,"kind":"planet_reforge","planet":str(id),"keep":keep(g),"eligibility":reforge_observed[key].duplicate(true)}
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
    if not transfer_crew(str(member.crewId)) and g.idle_planet_crew(str(member.crewId)) and g.crew.can_assign(g,str(member.crewId),"galaxy_explore",str(key)):return {"domain":true,"kind":"galaxy_crew","galaxy":str(key),"crew":str(member.crewId)}
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
  "space_manual_queue":
   var ready:Dictionary=queue_manual_action(g,now)
   if ready.is_empty() or str(ready.route)!=str(choice.route) or int(ready.level)!=int(choice.level) or g.profile.hyperspace.auto.enabled:return false
   var accepted:bool=g.request_hyperspace(str(choice.route),int(choice.level))
   if accepted:manual_pending["queued_for_hold60"]=true
   return accepted
  "space_manual":
   if pending_manual_action(g,now).is_empty():return false
   last_manual_boundary=main_boundary(g)
   if g.profile.hyperspace.auto.enabled:g.hyperspace.set_auto(g,false,"",0,"")
   last_attempt[str([g.profile.hyperspace.round_id,choice.route,choice.level])]=now
   last_frontier_attempt[manual_frontier_key(g)]=now
   var started:bool=g.start_hyperspace(choice.route,int(choice.level))
   if started and choice.has("paid_affix_supply"):manual_watch.paid_affix_supply=choice.paid_affix_supply.duplicate(true)
   return started
  "space_claim":return g.hyperspace.claim(g,int(choice.round),int(choice.run))
  "space_unseal":return g.hyperspace.claim_sealed(g,choice.id)
  "space_equip":return g.hyperspace.set_equipped(g,choice.ids)
  "space_favorite":return g.hyperspace.set_favorites(g,choice.ids)
  "space_preset":return g.hyperspace.set_preset(g,0,"Earned current fleet",choice.ids)
  "space_auto_pause":
   var previous:String=Permission.reserved_crew(g.profile.hyperspace)
   if not previous.is_empty():reserved_crew=previous
   return g.hyperspace.set_auto(g,false,"",0,"")
  "space_auto":return g.hyperspace.set_auto(g,true,choice.route,int(choice.level),choice.crew)
  "space_hangings":return g.hyperspace.attach_hangings(g,choice.id,choice.keys)
  "space_forge":
   if choice.get("ultimate_chain",false) and not ultimate_chain_step_valid(g,choice):
    ultimate_upgrade_chain.last_error="Chain prerequisites changed before the finite input dispatch"
    if ultimate_chain_in_transaction():ultimate_upgrade_chain.phase="reultimate";ultimate_upgrade_chain.recovery=true
    return false
   forge_at[str(choice.request.drone_id)]=now
   var previous_sequence:int=int(g.profile.hyperspace.command_seq)
   var result:Dictionary=g.hyperspace.forge(g,choice.request)
   if choice.get("ultimate_chain",false):ultimate_chain_result(g,choice,result,now,int(g.profile.hyperspace.command_seq)>previous_sequence)
   if str(result.error).is_empty() and choice.get("idle_salvage",false) and int(g.profile.hyperspace.command_seq)>previous_sequence:
    idle_salvage_success_times.append(now)
    idle_salvage_budget.used=idle_salvage_success_times.size()
   if str(result.error).is_empty() and choice.get("paid_affix",false):
    var key:String=str([g.profile.hyperspace.round_id,choice.request.drone_id])
    if affix_paid_windows.has(key):affix_paid_windows[key].attempts+=1
   return str(result.error).is_empty()
  "crew_equipment_mode":return g.crew.set_upgrade_mode(g,choice.crew,choice.mode,"equipment_upgrade")
  "crew_assign_equipment":return g.assign_crew(choice.crew,"equipment_upgrade","equipment")
  "crew_transfer_recall":
   if crew_transfer.is_empty() or not g.idle_planet_crew(str(crew_transfer.replacement)) or str(g.planet_progress(choice.planet).crewId)!=str(crew_transfer.veteran):return false
   if not g.cancel_planet_exploration(choice.planet):return false
   crew_transfer.phase="recalled";crew_transfer.lost_exploration_seconds=choice.lost_exploration_seconds;return true
  "crew_transfer_explore":
   if crew_transfer.is_empty() or g.crew.entry(g,str(crew_transfer.veteran)).assignmentType!="equipment_upgrade":return false
   if not g.start_planet_exploration(choice.planet,choice.crew):return false
   crew_transfer.completed_at=now;crew_transfer_history.append(crew_transfer.duplicate(true));last_crew_transfer=now;crew_transfer={};return true
  "planet_activate":return g.planet_buildings.activate(g,choice.planet,choice.building)
  "planet_builder":return g.planet_buildings.assign(g,choice.planet,choice.building,choice.crew)
  "planet_recall":return g.cancel_planet_exploration(choice.planet)
  "planet_explore":return g.start_planet_exploration(choice.planet,choice.crew)
  "planet_reforge":return g.reforge_planet(choice.planet,choice.keep)
  "crew_release":return g.assign_crew(choice.crew,"","")
  "galaxy_start":return g.galaxy.start(g,choice.galaxy)
  "galaxy_crew":return g.assign_crew(choice.crew,"galaxy_explore",choice.galaxy)
 return false
