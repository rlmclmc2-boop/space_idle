extends RefCounted
# Labelled finite configuration fixture. Original limits/RNG/fire/trigger rules remain intact.
const Bag=preload("res://scripts/drone_inventory.gd")
const Rewards=preload("res://scripts/drone_rewards.gd")
var counts={}
var frame_counts={}
var manifest={}
func on_event(kind,info):
 if kind not in ["fire","hit","beam_hit","beam_started","enhancement_chain","enhancement_secondary","hyperspace_dodge","hyperspace_black_hole"]:return
 counts[kind]=int(counts.get(kind,0))+1;frame_counts[kind]=int(frame_counts.get(kind,0))+1
 if kind=="fire" and str(info.get("shot",{}).get("combat_context",{}).get("source_id","")).begins_with("drone:"):
  counts.drone_fire=int(counts.get("drone_fire",0))+1;frame_counts.drone_fire=int(frame_counts.get("drone_fire",0))+1
func affix(rng,c,key):
 for attempt in 256:
  var a=Rewards.affix(rng,c,"",key)
  if a.tier==1:return a
 return {}
func configure(g,layer:int)->bool:
 if layer>0:
  g.profile.enhancementLevel=40
  g.invalidate_stat_cache()
  for setting in [["proficiency",2],["repeat",1],["repeat",3]]:
   if not g.set_enhancement_branch("weapons",setting[0],setting[1],"B"):return false
 if layer==2:
  var keys=["laser","laser","laser","missile","missile","missile","longLaser","longLaser"]
  for i in 8:g.profile.loadout.weapons[i].key=keys[i]
  var rng=RandomNumberGenerator.new();rng.seed=419
  var bag=Bag.fresh();var ids=[];var c=g.hyperspace.config
  for i in 5:
   var weapon=["laser","longLaser","laser","missile","missile"][i]
   var quality="legendary" if i<2 else "gold"
   var id="perf:layer2:%d"%i
   var desired=["scatter_pulse","prism_tower"][i] if i<2 else ""
   var d={}
   for attempt in 256:
    d=Rewards.create_drone(rng,c,id,quality,weapon,20,"1")
    if desired.is_empty() or d.legendary_effect.effect_id==desired:break
   if not desired.is_empty() and d.legendary_effect.effect_id!=desired:return false
   d.affixes=[]
   for key in ["chain_count","attack_speed","repeat_chance"]:
    var a=affix(rng,c,key)
    if a.is_empty():return false
    d.affixes.append(a)
   if not Bag.valid_drone(d,c):return false
   bag.drones[id]=d;bag.warehouse.append(id);ids.append(id)
  g.profile.hyperspace.inventory=bag;g.profile.hyperspace.unlocked_drones=true
  g.invalidate_stat_cache()
  if not g.hyperspace.set_equipped(g,ids) or not Bag.valid(g.profile.hyperspace.inventory,c):return false
 g.invalidate_stat_cache()
 manifest={"layer":layer,"scope":"synthetic held-health battle fixture, no natural progression claim","ordinary":g.weapon_entries().duplicate(true),"enhancement_effective_level":g.enhancement_effective_level(),"branches":g.profile.enhancementBranches.duplicate(true),"equipped":g.profile.hyperspace.inventory.equipped.duplicate(),"drones":g.profile.hyperspace.inventory.drones.duplicate(true),"totals":g.hyperspace_totals().duplicate(true),"combat_sources":g.combat_weapon_entries().duplicate(true),"alive_enemies":g.enemies.size(),"rng":str(g.rng.state)}
 g.event.connect(on_event)
 return true
func sample(g,scene):
 var chain=0;var links=0;var beams=0
 for shot in g.projectiles:
  if shot.get("chain_hop",false):chain+=1
  if shot.get("key","")=="longLaser":
   beams+=1
   for link in shot.get("attack_instance",{}).get("chain",{}).get("links",[]):
    if not link.broken:links+=1
 var visuals=scene.missile_events.size()+scene.pulse_events.size()+scene.rail_events.size()+scene.particles.size()+scene.projectile_visuals.size()
 return [chain,links,beams,visuals,scene.get_tree().get_node_count(),frame_counts.duplicate()]
func finish(g):
 g.event.disconnect(on_event)
 return {"config":manifest,"counts":counts.duplicate(),"counter_scope":"RAM event counters; live load scan included in full postdraw cadence, no perframe prints; no function profiler"}
